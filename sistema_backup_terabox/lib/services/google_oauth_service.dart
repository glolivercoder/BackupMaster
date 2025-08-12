import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class GoogleOAuthService {
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

  // Configurações OAuth2 do Google
  static const String _clientId = 'YOUR_GOOGLE_CLIENT_ID';
  static const String _clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';
  static const String _redirectUri = 'http://localhost:8080/callback';
  static const String _scope = 'https://www.googleapis.com/auth/drive.file';
  
  // URLs do Google OAuth2
  static const String _authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _userInfoUrl = 'https://www.googleapis.com/oauth2/v2/userinfo';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _userInfo;

  // Getters
  bool get isAuthenticated => _accessToken != null && !_isTokenExpired();
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userInfo => _userInfo;

  /// Verifica se o token está expirado
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }

  /// Inicia o fluxo de autenticação OAuth2 do Google
  Future<bool> authenticate() async {
    try {
      _logger.i('🔐 Iniciando autenticação OAuth2 do Google...');

      // Verificar se as credenciais estão configuradas
      if (_clientId == 'YOUR_GOOGLE_CLIENT_ID' || _clientSecret == 'YOUR_GOOGLE_CLIENT_SECRET') {
        _logger.e('❌ Credenciais OAuth2 do Google não configuradas');
        throw Exception('Credenciais OAuth2 do Google não configuradas. Configure CLIENT_ID e CLIENT_SECRET.');
      }

      // Gerar state para segurança
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      // Construir URL de autorização
      final authUri = Uri.parse(_authUrl).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': _scope,
        'response_type': 'code',
        'access_type': 'offline',
        'prompt': 'consent',
        'state': state,
      });

      _logger.d('🌐 URL de autorização: $authUri');

      // Iniciar servidor local para capturar callback
      final server = await HttpServer.bind('localhost', 8080);
      _logger.d('🖥️ Servidor local iniciado em http://localhost:8080');

      // Abrir navegador
      if (await canLaunchUrl(authUri)) {
        await launchUrl(authUri, mode: LaunchMode.externalApplication);
        _logger.i('🌐 Navegador aberto para autorização');
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
                <title>BackupMaster - Autenticação</title>
                <style>
                  body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #121212; color: white; }
                  .success { color: #4CAF50; }
                  .error { color: #F44336; }
                </style>
              </head>
              <body>
                <h1>BackupMaster</h1>
                ${error != null 
                  ? '<p class="error">❌ Autorização cancelada: $error</p>' 
                  : '<p class="success">✅ Autorização concluída com sucesso!</p>'}
                <p>Você pode fechar esta janela e retornar ao BackupMaster.</p>
              </body>
              </html>
            ''');
          await request.response.close();

          if (error != null) {
            _logger.w('⚠️ Autorização cancelada: $error');
            authCode = null;
          } else if (receivedState != state) {
            _logger.e('❌ State inválido - possível ataque CSRF');
            authCode = null;
          } else {
            authCode = code;
            _logger.i('✅ Código de autorização recebido');
          }
          break;
        }
      }

      await server.close();

      if (authCode == null) {
        _logger.w('⚠️ Autorização não concluída');
        return false;
      }

      // Trocar código por tokens
      final tokenResponse = await _exchangeCodeForTokens(authCode);
      if (!tokenResponse) {
        return false;
      }

      // Obter informações do usuário
      await _getUserInfo();

      _logger.i('✅ Autenticação OAuth2 do Google concluída com sucesso');
      return true;

    } catch (e) {
      _logger.e('❌ Erro na autenticação OAuth2 do Google: $e');
      return false;
    }
  }

  /// Troca o código de autorização por tokens de acesso
  Future<bool> _exchangeCodeForTokens(String authCode) async {
    try {
      _logger.d('🔄 Trocando código por tokens...');

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
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

        _logger.i('✅ Tokens obtidos com sucesso');
        _logger.d('🔑 Access token: ${_accessToken?.substring(0, 20)}...');
        _logger.d('⏰ Expira em: $_tokenExpiry');
        
        return true;
      } else {
        _logger.e('❌ Erro ao obter tokens: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro ao trocar código por tokens: $e');
      return false;
    }
  }

  /// Obtém informações do usuário autenticado
  Future<void> _getUserInfo() async {
    try {
      if (_accessToken == null) return;

      _logger.d('👤 Obtendo informações do usuário...');

      final response = await http.get(
        Uri.parse(_userInfoUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        _userInfo = json.decode(response.body);
        _logger.i('✅ Informações do usuário obtidas: ${_userInfo?['email']}');
      } else {
        _logger.w('⚠️ Erro ao obter informações do usuário: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('❌ Erro ao obter informações do usuário: $e');
    }
  }

  /// Renova o token de acesso usando o refresh token
  Future<bool> refreshAccessToken() async {
    try {
      if (_refreshToken == null) {
        _logger.w('⚠️ Refresh token não disponível');
        return false;
      }

      _logger.d('🔄 Renovando access token...');

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

        _logger.i('✅ Access token renovado com sucesso');
        return true;
      } else {
        _logger.e('❌ Erro ao renovar token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro ao renovar access token: $e');
      return false;
    }
  }

  /// Faz upload de um arquivo para o Google Drive
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      if (!isAuthenticated) {
        _logger.w('⚠️ Não autenticado - tentando renovar token...');
        if (!await refreshAccessToken()) {
          throw Exception('Não foi possível renovar o token de acesso');
        }
      }

      _logger.i('📤 Fazendo upload do arquivo: $fileName');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado: $filePath');
      }

      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;

      _logger.d('📊 Tamanho do arquivo: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Metadata do arquivo
      final metadata = {
        'name': fileName,
        'parents': ['appDataFolder'], // Pasta específica do app
      };

      // Upload multipart
      final boundary = 'boundary_${DateTime.now().millisecondsSinceEpoch}';
      final delimiter = '\r\n--$boundary\r\n';
      final closeDelimiter = '\r\n--$boundary--';

      var body = delimiter;
      body += 'Content-Type: application/json\r\n\r\n';
      body += json.encode(metadata);
      body += delimiter;
      body += 'Content-Type: application/octet-stream\r\n\r\n';

      final bodyBytes = utf8.encode(body);
      final endBytes = utf8.encode(closeDelimiter);
      
      final totalBytes = <int>[];
      totalBytes.addAll(bodyBytes);
      totalBytes.addAll(fileBytes);
      totalBytes.addAll(endBytes);

      final response = await http.post(
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'multipart/related; boundary="$boundary"',
          'Content-Length': totalBytes.length.toString(),
        },
        body: totalBytes,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fileId = data['id'];
        
        _logger.i('✅ Upload concluído com sucesso');
        _logger.d('🆔 File ID: $fileId');
        
        return fileId;
      } else {
        _logger.e('❌ Erro no upload: ${response.statusCode} - ${response.body}');
        throw Exception('Erro no upload: ${response.statusCode}');
      }

    } catch (e) {
      _logger.e('❌ Erro ao fazer upload: $e');
      rethrow;
    }
  }

  /// Obtém informações de quota do Google Drive
  Future<DriveQuotaInfo> getQuotaInfo() async {
    try {
      if (!isAuthenticated) {
        if (!await refreshAccessToken()) {
          throw Exception('Não foi possível renovar o token de acesso');
        }
      }

      _logger.d('📊 Obtendo informações de quota...');

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/about?fields=storageQuota'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quota = data['storageQuota'];
        
        return DriveQuotaInfo(
          total: int.tryParse(quota['limit'] ?? '0') ?? 0,
          used: int.tryParse(quota['usage'] ?? '0') ?? 0,
        );
      } else {
        throw Exception('Erro ao obter quota: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('❌ Erro ao obter quota: $e');
      rethrow;
    }
  }

  /// Limpa os tokens e informações de autenticação
  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _userInfo = null;
    _logger.i('🚪 Logout realizado');
  }
}

/// Classe para informações de quota do Google Drive
class DriveQuotaInfo {
  final int total;
  final int used;

  DriveQuotaInfo({required this.total, required this.used});

  int get free => total - used;
  double get usagePercentage => total > 0 ? (used / total) * 100 : 0;

  String get formattedTotal => _formatBytes(total);
  String get formattedUsed => _formatBytes(used);
  String get formattedFree => _formatBytes(free);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}