import 'dart:convert';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:logger/logger.dart';
import 'package:drift/drift.dart';
import '../services/database.dart';
import '../services/password_manager.dart';

class GmailService {
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

  String? _senderEmail;
  String? _senderPassword;
  String? _recipientEmail;
  late SmtpServer _smtpServer;

  GmailService({
    String? senderEmail,
    String? senderPassword,
    String? recipientEmail,
  }) {
    _senderEmail = senderEmail;
    _senderPassword = senderPassword;
    _recipientEmail = recipientEmail;
    _initializeSmtpServer();
  }

  /// Inicializa o servidor SMTP do Gmail
  void _initializeSmtpServer() {
    _smtpServer = gmail(_senderEmail ?? '', _senderPassword ?? '');
  }

  /// Configura as credenciais do Gmail
  void setCredentials({
    required String senderEmail,
    required String senderPassword,
    required String recipientEmail,
  }) {
    _senderEmail = senderEmail;
    _senderPassword = senderPassword;
    _recipientEmail = recipientEmail;
    _initializeSmtpServer();
    _logger.i('📧 Credenciais do Gmail configuradas');
    _logger.i('   Remetente: $_senderEmail');
    _logger.i('   Destinatário: $_recipientEmail');
  }

  /// Verifica se as credenciais estão configuradas
  bool get isConfigured => 
      _senderEmail != null && 
      _senderPassword != null && 
      _recipientEmail != null;

  /// Testa a conexão com o Gmail
  Future<bool> testConnection() async {
    if (!isConfigured) {
      throw Exception('Credenciais do Gmail não configuradas');
    }

    _logger.i('🔍 Testando conexão com Gmail...');
    
    try {
      // Criar mensagem de teste
      final message = Message()
        ..from = Address(_senderEmail!, 'BackupMaster')
        ..recipients.add(_recipientEmail!)
        ..subject = 'Teste de Conexão - BackupMaster'
        ..html = _generateTestEmailHtml();

      // Tentar enviar
      final sendReport = await send(message, _smtpServer);
      
      _logger.i('✅ Teste de conexão Gmail bem-sucedido');
      return true;
      
    } catch (e) {
      _logger.e('❌ Erro no teste de conexão Gmail: $e');
      return false;
    }
  }

  /// Envia relatório de backup por email
  Future<bool> sendBackupReport({
    required List<Backup> backups,
    required AppDatabase database,
    required PasswordManager passwordManager,
    String? customMessage,
  }) async {
    if (!isConfigured) {
      throw Exception('Credenciais do Gmail não configuradas');
    }

    _logger.i('📧 Enviando relatório de backup por email...');
    
    try {
      // Gerar HTML do relatório
      final htmlContent = await _generateBackupReportHtml(
        backups: backups,
        database: database,
        passwordManager: passwordManager,
        customMessage: customMessage,
      );

      // Criar mensagem
      final message = Message()
        ..from = Address(_senderEmail!, 'BackupMaster')
        ..recipients.add(_recipientEmail!)
        ..subject = 'Relatório de Backup - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'
        ..html = htmlContent;

      // Enviar email
      final sendReport = await send(message, _smtpServer);
      
      _logger.i('✅ Relatório de backup enviado com sucesso');
      
      // Registrar log de email
      await database.insertEmailLog(EmailLogsCompanion.insert(
        recipient: _recipientEmail!,
        status: 'sent',
      ));
      
      return true;
      
    } catch (e) {
      _logger.e('❌ Erro ao enviar relatório: $e');
      
      // Registrar log de erro
      try {
        await database.insertEmailLog(EmailLogsCompanion.insert(
          recipient: _recipientEmail!,
          status: 'error',
          errorMessage: Value(e.toString()),
        ));
      } catch (dbError) {
        _logger.e('❌ Erro ao registrar log de email: $dbError');
      }
      
      return false;
    }
  }

  /// Envia notificação de novo backup
  Future<bool> sendNewBackupNotification({
    required Backup backup,
    required String password,
    required String teraboxUrl,
  }) async {
    if (!isConfigured) {
      throw Exception('Credenciais do Gmail não configuradas');
    }

    _logger.i('📧 Enviando notificação de novo backup...');
    
    try {
      final htmlContent = _generateNewBackupNotificationHtml(
        backup: backup,
        password: password,
        teraboxUrl: teraboxUrl,
      );

      final message = Message()
        ..from = Address(_senderEmail!, 'BackupMaster')
        ..recipients.add(_recipientEmail!)
        ..subject = 'Novo Backup Criado: ${backup.name}'
        ..html = htmlContent;

      final sendReport = await send(message, _smtpServer);
      
      _logger.i('✅ Notificação de backup enviada com sucesso');
      return true;
      
    } catch (e) {
      _logger.e('❌ Erro ao enviar notificação: $e');
      return false;
    }
  }

  /// Gera HTML para email de teste
  String _generateTestEmailHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Teste de Conexão - BackupMaster</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 24px; font-weight: bold; color: #4CAF50; }
        .content { line-height: 1.6; color: #333; }
        .success { background-color: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">📦 BackupMaster</div>
            <h2>Teste de Conexão Gmail</h2>
        </div>
        
        <div class="content">
            <div class="success">
                ✅ <strong>Conexão bem-sucedida!</strong><br>
                O sistema de email está funcionando corretamente.
            </div>
            
            <p>Este é um email de teste para verificar se a configuração do Gmail está funcionando.</p>
            
            <p><strong>Informações do teste:</strong></p>
            <ul>
                <li>Data/Hora: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}</li>
                <li>Remetente: $_senderEmail</li>
                <li>Destinatário: $_recipientEmail</li>
            </ul>
            
            <p>Se você recebeu este email, significa que o BackupMaster está configurado corretamente para enviar relatórios de backup.</p>
        </div>
        
        <div class="footer">
            BackupMaster v1.0 - Sistema de Backup Automatizado
        </div>
    </div>
</body>
</html>
''';
  }

  /// Gera HTML para relatório de backup
  Future<String> _generateBackupReportHtml({
    required List<Backup> backups,
    required AppDatabase database,
    required PasswordManager passwordManager,
    String? customMessage,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    // Estatísticas
    final totalBackups = backups.length;
    final completedBackups = backups.where((b) => b.status == 'completed').length;
    final failedBackups = backups.where((b) => b.status == 'failed').length;
    final totalSize = backups.fold<int>(0, (sum, b) => sum + (b.fileSize ?? 0));
    
    // Gerar lista de backups com senhas
    final backupListHtml = StringBuffer();
    
    for (int i = 0; i < backups.length; i++) {
      final backup = backups[i];
      String password = 'N/A';
      
      try {
        password = await passwordManager.retrievePassword(backup.id);
      } catch (e) {
        _logger.w('⚠️ Erro ao recuperar senha para ${backup.id}: $e');
      }
      
      final statusColor = backup.status == 'completed' ? '#28a745' : 
                         backup.status == 'failed' ? '#dc3545' : '#ffc107';
      
      backupListHtml.writeln('''
        <tr style="border-bottom: 1px solid #eee;">
          <td style="padding: 12px; border-right: 1px solid #eee;">${i + 1}</td>
          <td style="padding: 12px; border-right: 1px solid #eee; font-weight: bold;">${backup.name}</td>
          <td style="padding: 12px; border-right: 1px solid #eee; font-family: monospace; background-color: #f8f9fa; color: #e83e8c; font-weight: bold;">$password</td>
          <td style="padding: 12px; border-right: 1px solid #eee;">${backup.createdAt.day}/${backup.createdAt.month}/${backup.createdAt.year}</td>
          <td style="padding: 12px; border-right: 1px solid #eee;">${_formatFileSize(backup.fileSize ?? 0)}</td>
          <td style="padding: 12px; color: $statusColor; font-weight: bold;">${backup.status.toUpperCase()}</td>
        </tr>
      ''');
    }
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Relatório de Backup - BackupMaster</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 28px; font-weight: bold; color: #4CAF50; margin-bottom: 10px; }
        .subtitle { color: #666; font-size: 16px; }
        .stats { display: flex; justify-content: space-around; margin: 30px 0; }
        .stat-card { text-align: center; padding: 20px; background-color: #f8f9fa; border-radius: 8px; min-width: 120px; }
        .stat-number { font-size: 24px; font-weight: bold; color: #4CAF50; }
        .stat-label { color: #666; font-size: 14px; margin-top: 5px; }
        .table-container { margin: 30px 0; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; border: 1px solid #ddd; }
        th { background-color: #4CAF50; color: white; padding: 15px; text-align: left; }
        td { padding: 12px; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; border-top: 1px solid #eee; padding-top: 20px; }
        .custom-message { background-color: #e3f2fd; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2196F3; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">📦 BackupMaster</div>
            <div class="subtitle">Relatório de Backup - $dateStr às $timeStr</div>
        </div>
        
        ${customMessage != null ? '<div class="custom-message"><strong>Mensagem:</strong> $customMessage</div>' : ''}
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number">$totalBackups</div>
                <div class="stat-label">Total de Backups</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$completedBackups</div>
                <div class="stat-label">Concluídos</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$failedBackups</div>
                <div class="stat-label">Falharam</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">${_formatFileSize(totalSize)}</div>
                <div class="stat-label">Tamanho Total</div>
            </div>
        </div>
        
        <div class="table-container">
            <h3 style="color: #333; margin-bottom: 15px;">📋 Lista de Backups com Senhas</h3>
            <table>
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Nome do Backup</th>
                        <th>🔐 Senha</th>
                        <th>Data</th>
                        <th>Tamanho</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    $backupListHtml
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p><strong>⚠️ IMPORTANTE:</strong> Guarde as senhas em local seguro. Elas são necessárias para extrair os arquivos ZIP.</p>
            <p>BackupMaster v1.0 - Relatório gerado automaticamente em $dateStr às $timeStr</p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Gera HTML para notificação de novo backup
  String _generateNewBackupNotificationHtml({
    required Backup backup,
    required String password,
    required String teraboxUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Novo Backup Criado - BackupMaster</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 24px; font-weight: bold; color: #4CAF50; }
        .content { line-height: 1.6; color: #333; }
        .backup-info { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .password-box { background-color: #fff3cd; border: 2px solid #ffc107; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center; }
        .password { font-family: monospace; font-size: 18px; font-weight: bold; color: #e83e8c; }
        .download-btn { display: inline-block; background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 10px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">📦 BackupMaster</div>
            <h2>🎉 Novo Backup Criado!</h2>
        </div>
        
        <div class="content">
            <p>Um novo backup foi criado com sucesso e enviado para o Terabox.</p>
            
            <div class="backup-info">
                <h3>📋 Informações do Backup:</h3>
                <ul>
                    <li><strong>Nome:</strong> ${backup.name}</li>
                    <li><strong>Pasta Original:</strong> ${backup.originalPath}</li>
                    <li><strong>Data/Hora:</strong> ${backup.createdAt.day}/${backup.createdAt.month}/${backup.createdAt.year} ${backup.createdAt.hour}:${backup.createdAt.minute.toString().padLeft(2, '0')}</li>
                    <li><strong>Tamanho:</strong> ${_formatFileSize(backup.fileSize ?? 0)}</li>
                    <li><strong>Status:</strong> ${backup.status.toUpperCase()}</li>
                </ul>
            </div>
            
            <div class="password-box">
                <h3>🔐 Senha do Arquivo ZIP:</h3>
                <div class="password">$password</div>
                <p style="margin-top: 10px; font-size: 14px; color: #856404;">
                    <strong>⚠️ IMPORTANTE:</strong> Guarde esta senha em local seguro!<br>
                    Ela é necessária para extrair o arquivo ZIP.
                </p>
            </div>
            
            <div style="text-align: center;">
                <a href="$teraboxUrl" class="download-btn">📥 Baixar do Terabox</a>
            </div>
            
            <p><strong>📤 Upload para Terabox:</strong> O arquivo foi enviado com sucesso para sua conta do Terabox e está disponível para download.</p>
            
            <p><strong>🔒 Segurança:</strong> O arquivo ZIP está protegido por senha para garantir a segurança dos seus dados.</p>
        </div>
        
        <div class="footer">
            BackupMaster v1.0 - Notificação automática de backup
        </div>
    </div>
</body>
</html>
''';
  }

  /// Formata tamanho de arquivo para exibição
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Limpa as credenciais
  void logout() {
    _senderEmail = null;
    _senderPassword = null;
    _recipientEmail = null;
    _logger.i('🚪 Logout do Gmail realizado');
  }
}