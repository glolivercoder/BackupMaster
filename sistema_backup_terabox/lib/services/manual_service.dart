import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class ManualService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Abre o manual de autenticação no navegador padrão
  static Future<void> openAuthenticationManual() async {
    try {
      _logger.i('📚 Abrindo Manual de Autenticação...');
      
      // Obter o caminho do arquivo HTML
      final currentDir = Directory.current.path;
      final manualPath = path.join(currentDir, 'manual_autenticacao.html');
      final manualFile = File(manualPath);
      
      if (!await manualFile.exists()) {
        _logger.e('❌ Arquivo do manual não encontrado: $manualPath');
        throw Exception('Arquivo do manual não encontrado');
      }
      
      // Converter para URI file://
      final uri = Uri.file(manualFile.absolute.path);
      
      _logger.d('🔗 URI do manual: $uri');
      
      // Tentar abrir no navegador
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('✅ Manual aberto com sucesso no navegador');
      } else {
        _logger.e('❌ Não foi possível abrir o manual no navegador');
        throw Exception('Não foi possível abrir o manual no navegador');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir manual: $e');
      rethrow;
    }
  }

  /// Verifica se o arquivo do manual existe
  static Future<bool> isManualAvailable() async {
    try {
      final currentDir = Directory.current.path;
      final manualPath = path.join(currentDir, 'manual_autenticacao.html');
      final manualFile = File(manualPath);
      
      final exists = await manualFile.exists();
      _logger.d('📋 Manual disponível: $exists');
      return exists;
      
    } catch (e) {
      _logger.e('❌ Erro ao verificar manual: $e');
      return false;
    }
  }

  /// Obtém informações sobre o manual
  static Future<Map<String, dynamic>> getManualInfo() async {
    try {
      final currentDir = Directory.current.path;
      final manualPath = path.join(currentDir, 'manual_autenticacao.html');
      final manualFile = File(manualPath);
      
      if (!await manualFile.exists()) {
        return {
          'exists': false,
          'path': manualPath,
          'size': 0,
          'lastModified': null,
        };
      }
      
      final stat = await manualFile.stat();
      
      return {
        'exists': true,
        'path': manualFile.absolute.path,
        'size': stat.size,
        'lastModified': stat.modified,
      };
      
    } catch (e) {
      _logger.e('❌ Erro ao obter informações do manual: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  /// Abre uma URL específica no navegador
  static Future<void> openUrl(String url) async {
    try {
      _logger.i('🌐 Abrindo URL: $url');
      
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _logger.i('✅ URL aberta com sucesso');
      } else {
        _logger.e('❌ Não foi possível abrir a URL: $url');
        throw Exception('Não foi possível abrir a URL');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir URL: $e');
      rethrow;
    }
  }

  /// URLs úteis para o manual
  static const Map<String, String> usefulUrls = {
    'baidu_developer': 'https://developer.baidu.com/',
    'terabox': 'https://www.terabox.com/',
    'google_security': 'https://myaccount.google.com/security',
    'gmail_app_passwords': 'https://support.google.com/accounts/answer/185833',
    'baidu_passport': 'https://passport.baidu.com/',
  };

  /// Abre uma URL útil específica
  static Future<void> openUsefulUrl(String key) async {
    if (usefulUrls.containsKey(key)) {
      await openUrl(usefulUrls[key]!);
    } else {
      throw Exception('URL não encontrada: $key');
    }
  }
}