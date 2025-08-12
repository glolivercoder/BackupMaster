import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class GmailOAuthService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Configurações OAuth2 do Gmail
  static const String _clientId = 'YOUR_GMAIL_CLIENT_ID';
  static const String _clientSecret = 'YOUR_GMAIL_CLIENT_SECRET';
  static const String _redirectUri = 'http://localhost:8080/callback';
  static const String _scope = 'https://www.googleapis.com/auth/gmail.send';
  
  // URLs do Google OAuth2
  static const String _authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _gmailApiUrl = 'https://gmail.googleapis.com/gmail/v1';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _userEmail;

  // Getters
  bool get isAuthenticated => _accessToken != null && !_isTokenExpired();
  String? get accessToken => _accessToken;
  String? get userEmail => _userEmail;

  /// Verifica se o token está expirado
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Carrega credenciais do arquivo JSON
  Future<Map<String, dynamic>?> loadCredentialsFromJson(String jsonPath) async {
    try {
      _logger.i('📄 Carregando credenciais do arquivo JSON: $jsonPath');
      
      final file = File(jsonPath);
      if (!await file.exists()) {
        _logger.e('❌ Arquivo JSON não encontrado: $jsonPath');
        return null;
      }
      
      final jsonContent = await file.readAsString();
      final credentials = json.decode(jsonContent);
      
      // Verificar se é um arquivo de credenciais válido
      if (credentials['installed'] != null) {
        final installed = credentials['installed'];
        _logger.i('✅ Credenciais carregadas do arquivo JSON');
        return {
          'client_id': installed['client_id'],
          'client_secret': installed['client_secret'],
          'auth_uri': installed['auth_uri'],
          'token_uri': installed['token_uri'],
        };
      } else if (credentials['web'] != null) {
        final web = credentials['web'];
        _logger.i('✅ Credenciais web carregadas do arquivo JSON');
        return {
          'client_id': web['client_id'],
          'client_secret': web['client_secret'],
          'auth_uri': web['auth_uri'],
          'token_uri': web['token_uri'],
        };
      } else {
        _logger.e('❌ Formato de arquivo JSON inválido');
        return null;
      }
    } catch (e) {
      _logger.e('❌ Erro ao carregar credenciais do JSON: $e');
      return null;
    }
  }

  /// Inicia o fluxo de autenticação OAuth2 do Gmail
  Future<bool> authenticate({String? jsonPath, String? clientId, String? clientSecret}) async {
    try {
      _logger.i('🔐 Iniciando autenticação OAuth2 do Gmail...');

      String finalClientId = clientId ?? _clientId;
      String finalClientSecret = clientSecret ?? _clientSecret;

      // Se fornecido arquivo JSON, carregar credenciais dele
      if (jsonPath != null) {
        final credentials = await loadCredentialsFromJson(jsonPath);
        if (credentials != null) {
          finalClientId = credentials['client_id'];
          finalClientSecret = credentials['client_secret'];
        }
      }

      // Verificar se as credenciais estão configuradas
      if (finalClientId == 'YOUR_GMAIL_CLIENT_ID' || finalClientSecret == 'YOUR_GMAIL_CLIENT_SECRET') {
        _logger.e('❌ Credenciais OAuth2 do Gmail não configuradas');
        throw Exception('Credenciais OAuth2 do Gmail não configuradas. Configure CLIENT_ID e CLIENT_SECRET ou forneça arquivo JSON.');
      }

      // Gerar state para segurança
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      // Construir URL de autorização
      final authUri = Uri.parse(_authUrl).replace(queryParameters: {
        'client_id': finalClientId,
        'redirect_uri': _redirectUri,
        'scope': _scope,
        'response_type': 'code',
        'access_type': 'offline',
        'prompt': 'consent',
        'state': state,
      });

      _logger.d('🌐 URL de autorização Gmail: $authUri');

      // Iniciar servidor local para capturar callback
      final server = await HttpServer.bind('localhost', 8080);
      _logger.d('🖥️ Servidor local iniciado em http://localhost:8080');

      // Abrir navegador
      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
        _logger.i('🌐 Navegador aberto para autorização Gmail');
      } else {
        throw Exception('Não foi possível abrir o navegador');
      }

      // Aguardar callback
      String? authCode;
      await for (HttpRequest request in server) {
        final uri = request.uri;
        _logger.d('📥 Callback recebido: ${uri.path}?${uri.query}');

        if (uri.path == '/callback') {
          final code = uri.queryParameters['code'];
          final receivedState = uri.queryParameters['state'];
          final error = uri.queryParameters['error'];

          // Responder ao navegador
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <head>
                <title>BackupMaster - Gmail OAuth2</title>
                <style>
                  body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #121212; color: white; }
                  .success { color: #4CAF50; }
                  .error { color: #F44336; }
                </style>
              </head>
              <body>
                <h1>📧 BackupMaster - Gmail</h1>
                ${error != null 
                  ? '<p class="error">❌ Autorização cancelada: $error</p>' 
                  : '<p class="success">✅ Autorização Gmail concluída!</p>'}
                <p>Você pode fechar esta janela e retornar ao BackupMaster.</p>
              </body>
              </html>
            ''');
          await request.response.close();

          if (error != null) {
            _logger.w('⚠️ Autorização Gmail cancelada: $error');
            authCode = null;
          } else if (receivedState != state) {
            _logger.e('❌ State inválido - possível ataque CSRF');
            authCode = null;
          } else {
            authCode = code;
            _logger.i('✅ Código de autorização Gmail recebido');
          }
          break;
        }
      }

      await server.close();

      if (authCode == null) {
        _logger.w('⚠️ Autorização Gmail não concluída');
        return false;
      }

      // Trocar código por tokens
      final tokenResponse = await _exchangeCodeForTokens(authCode, finalClientId, finalClientSecret);
      if (!tokenResponse) {
        return false;
      }

      // Obter informações do usuário
      await _getUserInfo();

      _logger.i('✅ Autenticação OAuth2 do Gmail concluída com sucesso');
      return true;

    } catch (e) {
      _logger.e('❌ Erro na autenticação OAuth2 do Gmail: $e');
      return false;
    }
  }

  /// Troca o código de autorização por tokens de acesso
  Future<bool> _exchangeCodeForTokens(String authCode, String clientId, String clientSecret) async {
    try {
      _logger.d('🔄 Trocando código por tokens Gmail...');

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': authCode,
          'grant_type': 'authorization_code',
          'redirect_uri': _redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        _logger.i('✅ Tokens Gmail obtidos com sucesso');
        _logger.d('🔑 Access token: ${_accessToken?.substring(0, 20)}...');
        _logger.d('⏰ Expira em: $_tokenExpiry');
        
        return true;
      } else {
        _logger.e('❌ Erro ao obter tokens Gmail: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro ao trocar código por tokens Gmail: $e');
      return false;
    }
  }

  /// Obtém informações do usuário autenticado
  Future<void> _getUserInfo() async {
    try {
      if (_accessToken == null) return;

      _logger.d('👤 Obtendo informações do usuário Gmail...');

      final response = await http.get(
        Uri.parse('$_gmailApiUrl/users/me/profile'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userEmail = data['emailAddress'];
        _logger.i('✅ Email do usuário obtido: $_userEmail');
      } else {
        _logger.w('⚠️ Erro ao obter informações do usuário Gmail: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('❌ Erro ao obter informações do usuário Gmail: $e');
    }
  }

  /// Envia email usando Gmail API
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = true,
  }) async {
    try {
      if (!isAuthenticated) {
        _logger.w('⚠️ Não autenticado - tentando renovar token...');
        if (!await refreshAccessToken()) {
          throw Exception('Não foi possível renovar o token de acesso');
        }
      }

      _logger.i('📧 Enviando email via Gmail API...');
      _logger.d('📧 Para: $to');
      _logger.d('📧 Assunto: $subject');

      // Construir mensagem RFC 2822
      final message = _buildEmailMessage(
        from: _userEmail ?? 'me',
        to: to,
        subject: subject,
        body: body,
        isHtml: isHtml,
      );

      // Codificar em base64url
      final encodedMessage = base64Url.encode(utf8.encode(message)).replaceAll('=', '');

      // Enviar via Gmail API
      final response = await http.post(
        Uri.parse('$_gmailApiUrl/users/me/messages/send'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'raw': encodedMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('✅ Email enviado com sucesso via Gmail API');
        _logger.d('📧 Message ID: ${data['id']}');
        return true;
      } else {
        _logger.e('❌ Erro ao enviar email: ${response.statusCode} - ${response.body}');
        return false;
      }

    } catch (e) {
      _logger.e('❌ Erro ao enviar email via Gmail API: $e');
      return false;
    }
  }

  /// Constrói mensagem de email no formato RFC 2822
  String _buildEmailMessage({
    required String from,
    required String to,
    required String subject,
    required String body,
    bool isHtml = true,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('From: $from');
    buffer.writeln('To: $to');
    buffer.writeln('Subject: $subject');
    buffer.writeln('MIME-Version: 1.0');
    
    if (isHtml) {
      buffer.writeln('Content-Type: text/html; charset=utf-8');
    } else {
      buffer.writeln('Content-Type: text/plain; charset=utf-8');
    }
    
    buffer.writeln('Content-Transfer-Encoding: 7bit');
    buffer.writeln();
    buffer.write(body);
    
    return buffer.toString();
  }

  /// Renova o token de acesso usando o refresh token
  Future<bool> refreshAccessToken() async {
    try {
      if (_refreshToken == null) {
        _logger.w('⚠️ Refresh token não disponível');
        return false;
      }

      _logger.d('🔄 Renovando access token Gmail...');

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _refreshToken!,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        _logger.i('✅ Access token Gmail renovado com sucesso');
        return true;
      } else {
        _logger.e('❌ Erro ao renovar token Gmail: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro ao renovar access token Gmail: $e');
      return false;
    }
  }

  /// Testa a conexão enviando um email de teste
  Future<bool> testConnection(String testEmail) async {
    try {
      _logger.i('🧪 Testando conexão Gmail OAuth2...');
      
      final success = await sendEmail(
        to: testEmail,
        subject: 'Teste de Conexão - BackupMaster Gmail OAuth2',
        body: '''
        <html>
        <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <h2 style="color: #4CAF50; text-align: center;">✅ Teste de Conexão Gmail OAuth2</h2>
            <p>Parabéns! A autenticação OAuth2 do Gmail está funcionando perfeitamente.</p>
            <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
              <h3 style="color: #333; margin-top: 0;">📊 Informações do Teste:</h3>
              <ul style="color: #666;">
                <li><strong>Data/Hora:</strong> ${DateTime.now().toString()}</li>
                <li><strong>Método:</strong> Gmail API OAuth2</li>
                <li><strong>Status:</strong> ✅ Sucesso</li>
                <li><strong>Aplicação:</strong> BackupMaster v1.0</li>
              </ul>
            </div>
            <p style="color: #666; font-size: 14px; text-align: center; margin-top: 30px;">
              Este email foi enviado automaticamente pelo BackupMaster para testar a configuração OAuth2 do Gmail.
            </p>
          </div>
        </body>
        </html>
        ''',
        isHtml: true,
      );
      
      if (success) {
        _logger.i('✅ Teste de conexão Gmail OAuth2 bem-sucedido');
      } else {
        _logger.e('❌ Falha no teste de conexão Gmail OAuth2');
      }
      
      return success;
    } catch (e) {
      _logger.e('❌ Erro no teste de conexão Gmail OAuth2: $e');
      return false;
    }
  }

  /// Limpa os tokens e informações de autenticação
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _userEmail = null;
    _logger.i('🚪 Logout Gmail realizado');
  }
}