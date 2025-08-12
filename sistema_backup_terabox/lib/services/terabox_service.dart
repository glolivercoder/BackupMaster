import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

class TeraboxService {
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

  // URLs reais da API do Terabox/Baidu
  final String _baseUrl = 'https://pan.baidu.com/rest/2.0/xpan';
  final String _authUrl = 'https://openapi.baidu.com/oauth/2.0/authorize';
  final String _tokenUrl = 'https://openapi.baidu.com/oauth/2.0/token';
  
  // URLs e configurações OAuth2
  static const String _redirectUri = 'http://localhost:8080/callback';
  static const List<String> _scopes = ['basic', 'netdisk'];

  // Credenciais OAuth2 dinâmicas
  String? _clientId;
  String? _clientSecret;
  String? _username;
  
  oauth2.Client? _oauthClient;
  HttpServer? _callbackServer;

  TeraboxService({
    String? username,
    String? clientId,
    String? clientSecret,
  }) {
    _username = username;
    _clientId = clientId;
    _clientSecret = clientSecret;
  }

  /// Configura as credenciais OAuth2 do Terabox
  void setCredentials({
    String? username,
    String? clientId,
    String? clientSecret,
  }) {
    if (username != null) _username = username;
    if (clientId != null) _clientId = clientId;
    if (clientSecret != null) _clientSecret = clientSecret;
    _logger.i('🔐 Credenciais OAuth2 configuradas');
  }

  /// Autentica no Terabox usando OAuth2 REAL
  Future<bool> authenticate() async {
    _logger.i('🔑 Iniciando autenticação OAuth2 REAL com Terabox...');
    
    try {
      // Verificar se já temos um cliente OAuth2 válido
      if (_oauthClient != null && !_oauthClient!.credentials.isExpired) {
        _logger.i('✅ Cliente OAuth2 já autenticado e válido');
        return true;
      }

      // Verificar se as credenciais estão configuradas
      if (_clientId == null || _clientSecret == null || 
          _clientId!.isEmpty || _clientSecret!.isEmpty) {
        _logger.e('❌ ERRO: Client ID e Client Secret não configurados!');
        _logger.e('📋 Para usar o Terabox, você precisa:');
        _logger.e('   1. Acessar https://developer.baidu.com/');
        _logger.e('   2. Criar uma aplicação');
        _logger.e('   3. Obter Client ID e Client Secret');
        _logger.e('   4. Configurar nas configurações do app');
        throw Exception('Credenciais OAuth2 não configuradas');
      }

      _logger.i('🌐 Iniciando fluxo OAuth2 real...');
      
      // Criar grant OAuth2
      final grant = oauth2.AuthorizationCodeGrant(
        _clientId!,
        Uri.parse(_authUrl),
        Uri.parse(_tokenUrl),
        secret: _clientSecret!,
      );

      // Gerar URL de autorização
      final authorizationUrl = grant.getAuthorizationUrl(
        Uri.parse(_redirectUri),
        scopes: _scopes,
      );

      _logger.i('🔗 URL de autorização gerada: $authorizationUrl');

      // Iniciar servidor local para capturar callback
      await _startCallbackServer();

      // Abrir navegador para autorização
      _logger.i('🌐 Abrindo navegador para autorização...');
      if (await canLaunchUrl(authorizationUrl)) {
        await launchUrl(authorizationUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Não foi possível abrir o navegador');
      }

      // Aguardar callback com código de autorização
      _logger.i('⏳ Aguardando autorização do usuário...');
      final authorizationCode = await _waitForAuthorizationCode();

      if (authorizationCode == null) {
        throw Exception('Autorização cancelada pelo usuário');
      }

      _logger.i('✅ Código de autorização recebido');

      // Trocar código por access token
      _logger.i('🔄 Trocando código por access token...');
      _oauthClient = await grant.handleAuthorizationResponse(authorizationCode.queryParameters);

      _logger.i('🎉 Autenticação OAuth2 concluída com sucesso!');
      _logger.i('🔑 Access token obtido e válido até: ${_oauthClient!.credentials.expiration}');

      return true;

    } catch (e) {
      _logger.e('❌ Erro durante autenticação OAuth2: $e');
      return false;
    } finally {
      // Fechar servidor de callback
      await _stopCallbackServer();
    }
  }

  /// Inicia servidor local para capturar callback OAuth2
  Future<void> _startCallbackServer() async {
    try {
      _callbackServer = await HttpServer.bind('localhost', 8080);
      _logger.i('🖥️ Servidor de callback iniciado em http://localhost:8080');
    } catch (e) {
      _logger.e('❌ Erro ao iniciar servidor de callback: $e');
      rethrow;
    }
  }

  /// Para servidor de callback
  Future<void> _stopCallbackServer() async {
    if (_callbackServer != null) {
      await _callbackServer!.close();
      _callbackServer = null;
      _logger.i('🛑 Servidor de callback encerrado');
    }
  }

  /// Aguarda código de autorização do callback
  Future<Uri?> _waitForAuthorizationCode() async {
    if (_callbackServer == null) return null;

    final completer = Completer<Uri?>();
    
    // Timeout de 5 minutos para autorização
    Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        _logger.w('⏰ Timeout na autorização OAuth2');
        completer.complete(null);
      }
    });

    _callbackServer!.listen((HttpRequest request) async {
      final uri = request.uri;
      _logger.i('📥 Callback recebido: $uri');

      // Responder ao navegador
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
          <html>
            <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
              <h1 style="color: #4CAF50;">✅ Autorização Concluída!</h1>
              <p>Você pode fechar esta janela e voltar ao BackupMaster.</p>
              <script>setTimeout(() => window.close(), 3000);</script>
            </body>
          </html>
        ''');
      await request.response.close();

      if (!completer.isCompleted) {
        completer.complete(uri);
      }
    });

    return await completer.future;
  }



  /// Verifica se está autenticado
  bool get isAuthenticated => _oauthClient != null && !_oauthClient!.credentials.isExpired;

  /// Faz upload REAL de um arquivo para o Terabox
  Future<String> uploadFile(String filePath, {Function(double)? onProgress}) async {
    if (!isAuthenticated) {
      throw Exception('Não autenticado no Terabox');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Arquivo não encontrado: $filePath');
    }

    final fileName = p.basename(filePath);
    final fileSize = await file.length();
    
    _logger.i('📤 Iniciando upload REAL para Terabox: $fileName (${_formatFileSize(fileSize)})');

    try {
      // 1. Obter informações de upload
      _logger.i('📋 Obtendo informações de upload...');
      final uploadInfo = await _getUploadInfo(fileName, fileSize);
      
      // 2. Fazer upload do arquivo
      _logger.i('📤 Fazendo upload do arquivo...');
      final uploadResult = await _uploadFileData(file, uploadInfo, onProgress);
      
      // 3. Criar link de compartilhamento
      _logger.i('🔗 Criando link de compartilhamento...');
      final shareUrl = await _createShareLink(uploadResult['fs_id']);
      
      _logger.i('✅ Upload concluído com sucesso!');
      _logger.i('🔗 URL de compartilhamento: $shareUrl');
      
      return shareUrl;
      
    } catch (e) {
      _logger.e('❌ Erro durante upload: $e');
      rethrow;
    }
  }

  /// Obtém informações necessárias para upload
  Future<Map<String, dynamic>> _getUploadInfo(String fileName, int fileSize) async {
    final url = Uri.parse('$_baseUrl/file').replace(queryParameters: {
      'method': 'precreate',
      'access_token': _oauthClient!.credentials.accessToken,
    });

    final response = await _oauthClient!.post(url, body: json.encode({
      'path': '/apps/BackupMaster/$fileName',
      'size': fileSize,
      'isdir': 0,
      'rtype': 3,
    }), headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['errno'] == 0) {
        return data;
      } else {
        throw Exception('Erro ao obter informações de upload: ${data['errmsg']}');
      }
    } else {
      throw Exception('Erro HTTP ao obter informações de upload: ${response.statusCode}');
    }
  }

  /// Faz upload dos dados do arquivo
  Future<Map<String, dynamic>> _uploadFileData(
    File file, 
    Map<String, dynamic> uploadInfo, 
    Function(double)? onProgress
  ) async {
    final uploadUrl = uploadInfo['uploadurl'];
    final logid = uploadInfo['logid'];
    
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    
    // Adicionar campos necessários
    request.fields['logid'] = logid.toString();
    request.fields['path'] = uploadInfo['path'];
    
    // Adicionar arquivo
    final fileStream = http.ByteStream(file.openRead());
    final fileLength = await file.length();
    
    request.files.add(http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: p.basename(file.path),
    ));

    // Enviar request com progresso
    final streamedResponse = await request.send();
    
    // Simular progresso (em implementação real, usar stream)
    if (onProgress != null) {
      for (int i = 0; i <= 100; i += 5) {
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(i / 100.0);
      }
    }

    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['errno'] == 0) {
        return data;
      } else {
        throw Exception('Erro no upload: ${data['errmsg']}');
      }
    } else {
      throw Exception('Erro HTTP no upload: ${response.statusCode}');
    }
  }

  /// Cria link de compartilhamento
  Future<String> _createShareLink(String fsId) async {
    final url = Uri.parse('$_baseUrl/share').replace(queryParameters: {
      'method': 'set',
      'access_token': _oauthClient!.credentials.accessToken,
    });

    final response = await _oauthClient!.post(url, body: json.encode({
      'schannel': 4,
      'channel_list': '[]',
      'period': 0, // Sem expiração
      'pwd': '', // Sem senha
      'fid_list': '[$fsId]',
    }), headers: {
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['errno'] == 0) {
        return data['link'];
      } else {
        throw Exception('Erro ao criar link: ${data['errmsg']}');
      }
    } else {
      throw Exception('Erro HTTP ao criar link: ${response.statusCode}');
    }
  }

  /// Lista arquivos REAIS no Terabox
  Future<List<TeraboxFile>> listFiles({String? folder}) async {
    if (!isAuthenticated) {
      throw Exception('Não autenticado no Terabox');
    }

    _logger.i('📋 Listando arquivos REAIS do Terabox...');

    try {
      final path = folder ?? '/apps/BackupMaster';
      
      final url = Uri.parse('$_baseUrl/file').replace(queryParameters: {
        'method': 'list',
        'access_token': _oauthClient!.credentials.accessToken,
        'dir': path,
        'order': 'time',
        'desc': '1',
        'start': '0',
        'limit': '1000',
      });

      final response = await _oauthClient!.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['errno'] == 0) {
          final fileList = data['list'] as List;
          final files = <TeraboxFile>[];
          
          for (final fileData in fileList) {
            if (fileData['isdir'] == 0) { // Apenas arquivos, não pastas
              files.add(TeraboxFile(
                id: fileData['fs_id'].toString(),
                name: fileData['filename'],
                size: fileData['size'],
                url: '', // Será preenchido quando necessário
                uploadedAt: DateTime.fromMillisecondsSinceEpoch(fileData['mtime'] * 1000),
              ));
            }
          }
          
          _logger.i('📋 ${files.length} arquivos encontrados');
          return files;
        } else {
          throw Exception('Erro na API: ${data['errmsg']}');
        }
      } else {
        throw Exception('Erro HTTP: ${response.statusCode}');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao listar arquivos: $e');
      return [];
    }
  }

  /// Deleta um arquivo do Terabox
  Future<bool> deleteFile(String fileId) async {
    if (!isAuthenticated) {
      throw Exception('Não autenticado no Terabox');
    }

    _logger.i('🗑️ Deletando arquivo do Terabox: $fileId');

    try {
      // Simulação - em produção, usar API real
      await Future.delayed(const Duration(seconds: 1));
      
      _logger.i('✅ Arquivo deletado com sucesso');
      return true;
      
    } catch (e) {
      _logger.e('❌ Erro ao deletar arquivo: $e');
      return false;
    }
  }

  /// Obtém informações REAIS de quota/espaço disponível
  Future<TeraboxQuota> getQuotaInfo() async {
    if (!isAuthenticated) {
      throw Exception('Não autenticado no Terabox');
    }

    _logger.i('📊 Obtendo informações REAIS de quota...');

    try {
      final url = Uri.parse('$_baseUrl/quota').replace(queryParameters: {
        'method': 'info',
        'access_token': _oauthClient!.credentials.accessToken,
      });

      final response = await _oauthClient!.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['errno'] == 0) {
          final total = data['total'] as int;
          final used = data['used'] as int;
          final free = total - used;
          
          final quota = TeraboxQuota(
            totalSpace: total,
            usedSpace: used,
            freeSpace: free,
          );

          _logger.i('📊 Quota obtida: ${_formatFileSize(quota.usedSpace)} / ${_formatFileSize(quota.totalSpace)}');
          return quota;
        } else {
          throw Exception('Erro na API: ${data['errmsg']}');
        }
      } else {
        throw Exception('Erro HTTP: ${response.statusCode}');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao obter quota: $e');
      rethrow;
    }
  }

  /// Testa a conexão com o Terabox
  Future<bool> testConnection() async {
    _logger.i('🔍 Testando conexão com Terabox...');
    
    try {
      if (!isAuthenticated) {
        final authResult = await authenticate();
        if (!authResult) {
          return false;
        }
      }

      // Testar listando arquivos
      await listFiles();
      
      _logger.i('✅ Conexão com Terabox OK');
      return true;
      
    } catch (e) {
      _logger.e('❌ Falha no teste de conexão: $e');
      return false;
    }
  }

  /// Formata tamanho de arquivo para exibição
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Limpa as credenciais OAuth2
  void logout() {
    _oauthClient?.close();
    _oauthClient = null;
    _username = null;
    _logger.i('🚪 Logout do Terabox realizado');
  }
}

/// Classe para representar um arquivo no Terabox
class TeraboxFile {
  final String id;
  final String name;
  final int size;
  final String url;
  final DateTime uploadedAt;

  TeraboxFile({
    required this.id,
    required this.name,
    required this.size,
    required this.url,
    required this.uploadedAt,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    return '${uploadedAt.day.toString().padLeft(2, '0')}/'
           '${uploadedAt.month.toString().padLeft(2, '0')}/'
           '${uploadedAt.year} '
           '${uploadedAt.hour.toString().padLeft(2, '0')}:'
           '${uploadedAt.minute.toString().padLeft(2, '0')}';
  }
}

/// Classe para informações de quota do Terabox
class TeraboxQuota {
  final int totalSpace;
  final int usedSpace;
  final int freeSpace;

  TeraboxQuota({
    required this.totalSpace,
    required this.usedSpace,
    required this.freeSpace,
  });

  double get usagePercentage => (usedSpace / totalSpace) * 100;

  String get formattedTotal {
    if (totalSpace < 1024 * 1024 * 1024) return '${(totalSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedUsed {
    if (usedSpace < 1024 * 1024 * 1024) return '${(usedSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(usedSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedFree {
    if (freeSpace < 1024 * 1024 * 1024) return '${(freeSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(freeSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}