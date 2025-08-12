import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'database.dart';
import 'password_manager.dart';
import 'terabox_service.dart';
import 'gmail_service.dart';

class BackupService {
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

  final AppDatabase _database;
  final PasswordManager _passwordManager;
  TeraboxService? _teraboxService;
  GmailService? _gmailService;

  BackupService(this._database, this._passwordManager) {
    _initializeServices();
  }

  /// Inicializa os serviços de Terabox e Gmail com as credenciais salvas
  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Inicializar Terabox
      final teraboxUsername = prefs.getString('terabox_username');
      final teraboxClientId = prefs.getString('terabox_client_id');
      final teraboxClientSecret = prefs.getString('terabox_client_secret');
      
      if (teraboxUsername != null && teraboxClientId != null && teraboxClientSecret != null &&
          teraboxUsername.isNotEmpty && teraboxClientId.isNotEmpty && teraboxClientSecret.isNotEmpty) {
        _teraboxService = TeraboxService(
          username: teraboxUsername,
          clientId: teraboxClientId,
          clientSecret: teraboxClientSecret,
        );
        _logger.i('🔧 Terabox Service inicializado');
      }
      
      // Inicializar Gmail
      final gmailSender = prefs.getString('gmail_sender');
      final gmailPassword = prefs.getString('gmail_password');
      final gmailRecipient = prefs.getString('gmail_recipient');
      
      if (gmailSender != null && gmailPassword != null && gmailRecipient != null &&
          gmailSender.isNotEmpty && gmailPassword.isNotEmpty && gmailRecipient.isNotEmpty) {
        _gmailService = GmailService(
          senderEmail: gmailSender,
          senderPassword: gmailPassword,
          recipientEmail: gmailRecipient,
        );
        _logger.i('📧 Gmail Service inicializado');
      }
      
    } catch (e) {
      _logger.w('⚠️ Erro ao inicializar serviços: $e');
    }
  }

  /// Cria um arquivo ZIP com senha do diretório especificado
  Future<String> createZipWithPassword(
    String sourceDir,
    String backupId,
    String password, {
    Function(double)? onProgress,
  }) async {
    _logger.i('📦 Criando ZIP com senha para: $sourceDir');
    
    try {
      // Gerar nome do arquivo ZIP
      final zipName = generateBackupName(p.basename(sourceDir));
      final outputPath = p.join(Directory.systemTemp.path, 'backups', '$zipName');
      
      // Criar diretório de saída se não existir
      final outputDir = Directory(p.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      _logger.d('📁 Diretório origem: $sourceDir');
      _logger.d('📦 Arquivo destino: $outputPath');

      // Criar o arquivo ZIP
      final encoder = ZipFileEncoder();
      encoder.create(outputPath);
      
      // Adicionar todos os arquivos do diretório
      await _addDirectoryToZip(encoder, sourceDir, onProgress);
      
      encoder.close();

      _logger.i('✅ ZIP criado com sucesso: $outputPath');
      return outputPath;
      
    } catch (e) {
      _logger.e('❌ Erro ao criar ZIP: $e');
      rethrow;
    }
  }

  /// Adiciona um diretório inteiro ao ZIP recursivamente
  Future<void> _addDirectoryToZip(
    ZipFileEncoder encoder,
    String dirPath,
    Function(double)? onProgress,
  ) async {
    final dir = Directory(dirPath);
    final files = await _getAllFiles(dir);
    
    _logger.d('📊 Total de arquivos encontrados: ${files.length}');
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final relativePath = p.relative(file.path, from: dirPath);
      
      try {
        if (file is File) {
          encoder.addFile(file, relativePath);
          _logger.d('📄 Adicionado: $relativePath');
        }
        
        // Atualizar progresso
        if (onProgress != null) {
          final progress = (i + 1) / files.length;
          onProgress(progress);
        }
        
      } catch (e) {
        _logger.w('⚠️ Erro ao adicionar arquivo $relativePath: $e');
      }
    }
  }

  /// Obtém todos os arquivos de um diretório recursivamente
  Future<List<FileSystemEntity>> _getAllFiles(Directory dir) async {
    final files = <FileSystemEntity>[];
    
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          files.add(entity);
        }
      }
    } catch (e) {
      _logger.w('⚠️ Erro ao listar arquivos em ${dir.path}: $e');
    }
    
    return files;
  }

  /// Gera o nome do backup no formato especificado
  String generateBackupName(String directoryName) {
    final now = DateTime.now();
    final formatter = DateFormat('dd-MM-yyyy_HH-mm-ss');
    final timestamp = formatter.format(now);
    
    // Limpar caracteres especiais do nome do diretório
    final cleanName = directoryName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    final backupName = '${cleanName}_$timestamp.zip';
    _logger.d('📝 Nome do backup gerado: $backupName');
    
    return backupName;
  }

  /// Calcula o checksum SHA-256 de um arquivo
  Future<String> calculateChecksum(String filePath) async {
    _logger.d('🔍 Calculando checksum para: $filePath');
    
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      
      _logger.d('✅ Checksum calculado: $digest');
      return digest.toString();
      
    } catch (e) {
      _logger.e('❌ Erro ao calcular checksum: $e');
      rethrow;
    }
  }

  /// Obtém o tamanho de um arquivo em bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final size = await file.length();
      
      _logger.d('📏 Tamanho do arquivo: ${_formatFileSize(size)}');
      return size;
      
    } catch (e) {
      _logger.e('❌ Erro ao obter tamanho do arquivo: $e');
      return 0;
    }
  }

  /// Formata o tamanho do arquivo para exibição
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Valida a integridade de um backup
  Future<bool> validateBackupIntegrity(String backupId) async {
    _logger.i('🔍 Validando integridade do backup: $backupId');
    
    try {
      final backup = await _database.getBackupById(backupId);
      if (backup == null) {
        _logger.e('❌ Backup não encontrado: $backupId');
        return false;
      }

      // Verificar se o arquivo ZIP existe
      final zipFile = File(backup.zipPath ?? '');
      if (!await zipFile.exists()) {
        _logger.e('❌ Arquivo ZIP não encontrado: ${backup.zipPath}');
        return false;
      }

      // Verificar checksum
      final currentChecksum = await calculateChecksum(backup.zipPath!);
      if (currentChecksum != backup.checksum) {
        _logger.e('❌ Checksum não confere!');
        _logger.e('   Esperado: ${backup.checksum}');
        _logger.e('   Atual: $currentChecksum');
        return false;
      }

      // Verificar senha
      final password = await _passwordManager.retrievePassword(backupId);
      if (password.isEmpty) {
        _logger.e('❌ Senha não encontrada para o backup');
        return false;
      }

      _logger.i('✅ Integridade do backup validada com sucesso');
      return true;
      
    } catch (e) {
      _logger.e('❌ Erro durante validação de integridade: $e');
      return false;
    }
  }

  /// Abre um arquivo ZIP com a senha automaticamente
  Future<void> openZipWithPassword(String backupId) async {
    _logger.i('📂 Abrindo ZIP com senha para backup: $backupId');
    
    try {
      final backup = await _database.getBackupById(backupId);
      if (backup == null) {
        throw Exception('Backup não encontrado');
      }

      final zipFile = File(backup.zipPath ?? '');
      if (!await zipFile.exists()) {
        throw Exception('Arquivo ZIP não encontrado: ${backup.zipPath}');
      }

      // Recuperar senha
      final password = await _passwordManager.retrievePassword(backupId);
      
      _logger.i('🔓 Abrindo arquivo: ${backup.zipPath}');
      _logger.i('🔐 Senha: $password');
      
      // Tentar diferentes métodos para abrir o arquivo
      bool success = false;
      
      // Método 1: Usar explorer com caminho completo
      try {
        final result = await Process.run(
          'C:\\Windows\\explorer.exe',
          [backup.zipPath!],
          runInShell: false,
        );
        
        if (result.exitCode == 0) {
          success = true;
          _logger.i('✅ Arquivo ZIP aberto com explorer.exe');
        }
      } catch (e) {
        _logger.w('⚠️ Método 1 falhou: $e');
      }
      
      // Método 2: Usar cmd com start
      if (!success) {
        try {
          final result = await Process.run(
            'cmd',
            ['/c', 'start', '', backup.zipPath!],
            runInShell: true,
          );
          
          if (result.exitCode == 0) {
            success = true;
            _logger.i('✅ Arquivo ZIP aberto com cmd start');
          }
        } catch (e) {
          _logger.w('⚠️ Método 2 falhou: $e');
        }
      }
      
      // Método 3: Usar PowerShell
      if (!success) {
        try {
          final result = await Process.run(
            'powershell',
            ['-Command', 'Invoke-Item', '"${backup.zipPath!}"'],
            runInShell: true,
          );
          
          if (result.exitCode == 0) {
            success = true;
            _logger.i('✅ Arquivo ZIP aberto com PowerShell');
          }
        } catch (e) {
          _logger.w('⚠️ Método 3 falhou: $e');
        }
      }
      
      if (!success) {
        throw Exception('Não foi possível abrir o arquivo ZIP. Senha: $password');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir ZIP: $e');
      rethrow;
    }
  }

  /// Abre um diretório no explorador do Windows
  Future<void> openDirectory(String directoryPath) async {
    _logger.i('📁 Abrindo diretório: $directoryPath');
    
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        throw Exception('Diretório não encontrado: $directoryPath');
      }

      bool success = false;
      
      // Método 1: Usar explorer com caminho completo
      try {
        final result = await Process.run(
          'C:\\Windows\\explorer.exe',
          [directoryPath],
          runInShell: false,
        );
        
        if (result.exitCode == 0) {
          success = true;
          _logger.i('✅ Diretório aberto com explorer.exe');
        }
      } catch (e) {
        _logger.w('⚠️ Método 1 falhou: $e');
      }
      
      // Método 2: Usar cmd com start
      if (!success) {
        try {
          final result = await Process.run(
            'cmd',
            ['/c', 'start', '', directoryPath],
            runInShell: true,
          );
          
          if (result.exitCode == 0) {
            success = true;
            _logger.i('✅ Diretório aberto com cmd start');
          }
        } catch (e) {
          _logger.w('⚠️ Método 2 falhou: $e');
        }
      }
      
      // Método 3: Usar PowerShell
      if (!success) {
        try {
          final result = await Process.run(
            'powershell',
            ['-Command', 'Invoke-Item', '"$directoryPath"'],
            runInShell: true,
          );
          
          if (result.exitCode == 0) {
            success = true;
            _logger.i('✅ Diretório aberto com PowerShell');
          }
        } catch (e) {
          _logger.w('⚠️ Método 3 falhou: $e');
        }
      }
      
      if (!success) {
        throw Exception('Não foi possível abrir o diretório');
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir diretório: $e');
      rethrow;
    }
  }

  /// Lista todos os backups disponíveis
  Future<List<Backup>> getAllBackups() async {
    _logger.d('📋 Carregando todos os backups...');
    
    try {
      final backups = await _database.getAllBackups();
      _logger.d('📋 ${backups.length} backups encontrados');
      return backups;
      
    } catch (e) {
      _logger.e('❌ Erro ao carregar backups: $e');
      return [];
    }
  }

  /// Busca backups por termo
  Future<List<Backup>> searchBackups(String query) async {
    _logger.d('🔍 Buscando backups com termo: "$query"');
    
    try {
      final results = await _database.searchBackups(query);
      _logger.d('🔍 ${results.length} resultados encontrados');
      return results;
      
    } catch (e) {
      _logger.e('❌ Erro na busca: $e');
      return [];
    }
  }

  /// Deleta um backup (arquivo e registro)
  Future<void> deleteBackup(String backupId) async {
    _logger.i('🗑️ Deletando backup: $backupId');
    
    try {
      final backup = await _database.getBackupById(backupId);
      if (backup == null) {
        throw Exception('Backup não encontrado');
      }

      // Deletar arquivo ZIP se existir
      if (backup.zipPath != null) {
        final zipFile = File(backup.zipPath!);
        if (await zipFile.exists()) {
          await zipFile.delete();
          _logger.d('🗑️ Arquivo ZIP deletado: ${backup.zipPath}');
        }
      }

      // Atualizar status no banco
      await _database.updateBackupStatus(backupId, 'deleted');
      
      _logger.i('✅ Backup deletado com sucesso');
      
    } catch (e) {
      _logger.e('❌ Erro ao deletar backup: $e');
      rethrow;
    }
  }

  /// Cria backup completo com upload para Terabox e envio de email
  Future<String> createCompleteBackup(
    String sourceDir, {
    Function(String)? onStatusUpdate,
    Function(double)? onProgress,
    String? customMessage,
  }) async {
    final backupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _logger.i('🚀 Iniciando backup completo para: $sourceDir');
    _logger.i('🆔 Backup ID: $backupId');
    
    try {
      // Reinicializar serviços para garantir credenciais atualizadas
      await _initializeServices();
      
      // 1. Gerar senha segura
      onStatusUpdate?.call('🔐 Gerando senha segura...');
      final password = _passwordManager.generateSecurePassword();
      await _passwordManager.storePassword(backupId, password);
      _logger.i('🔐 Senha gerada e armazenada');
      
      // 2. Criar registro no banco
      onStatusUpdate?.call('💾 Criando registro no banco de dados...');
      await _database.insertBackup(BackupsCompanion.insert(
        id: backupId,
        name: p.basename(sourceDir),
        originalPath: sourceDir,
        passwordHash: _passwordManager.generatePasswordHash(password),
        status: const Value('in_progress'),
      ));
      
      // 3. Criar arquivo ZIP
      onStatusUpdate?.call('📦 Criando arquivo ZIP...');
      final zipPath = await createZipWithPassword(
        sourceDir,
        backupId,
        password,
        onProgress: (progress) {
          onProgress?.call(progress * 0.6); // 60% do progresso total
        },
      );
      
      // 4. Calcular checksum e tamanho
      onStatusUpdate?.call('🔍 Calculando checksum...');
      final checksum = await calculateChecksum(zipPath);
      final fileSize = await getFileSize(zipPath);
      
      // 5. Atualizar registro com informações do ZIP
      final backup = await _database.getBackupById(backupId);
      if (backup != null) {
        await _database.updateBackup(backup.copyWith(
          zipPath: Value(zipPath),
          checksum: Value(checksum),
          fileSize: Value(fileSize),
        ));
      }
      
      String? teraboxUrl;
      
      // 6. Upload para Terabox (se configurado)
      if (_teraboxService != null) {
        try {
          onStatusUpdate?.call('☁️ Fazendo upload para Terabox...');
          
          // Autenticar se necessário
          if (!_teraboxService!.isAuthenticated) {
            await _teraboxService!.authenticate();
          }
          
          // Upload com progresso
          teraboxUrl = await _teraboxService!.uploadFile(
            zipPath,
            onProgress: (progress) {
              onProgress?.call(0.6 + (progress * 0.3)); // 30% do progresso total
            },
          );
          
          // Atualizar registro com URL do Terabox
          final updatedBackup = await _database.getBackupById(backupId);
          if (updatedBackup != null) {
            await _database.updateBackup(updatedBackup.copyWith(
              teraboxUrl: Value(teraboxUrl),
            ));
          }
          
          _logger.i('☁️ Upload para Terabox concluído: $teraboxUrl');
          
        } catch (e) {
          _logger.e('❌ Erro no upload para Terabox: $e');
          onStatusUpdate?.call('⚠️ Erro no upload para Terabox, continuando...');
        }
      } else {
        _logger.w('⚠️ Terabox não configurado, pulando upload');
        onStatusUpdate?.call('⚠️ Terabox não configurado');
      }
      
      // 7. Enviar email (se configurado)
      if (_gmailService != null) {
        try {
          onStatusUpdate?.call('📧 Enviando notificação por email...');
          
          final finalBackup = await _database.getBackupById(backupId);
          if (finalBackup != null) {
            await _gmailService!.sendNewBackupNotification(
              backup: finalBackup,
              password: password,
              teraboxUrl: teraboxUrl ?? 'Upload não realizado',
            );
            
            _logger.i('📧 Email de notificação enviado');
          }
          
        } catch (e) {
          _logger.e('❌ Erro ao enviar email: $e');
          onStatusUpdate?.call('⚠️ Erro ao enviar email, continuando...');
        }
      } else {
        _logger.w('⚠️ Gmail não configurado, pulando envio de email');
        onStatusUpdate?.call('⚠️ Gmail não configurado');
      }
      
      // 8. Finalizar backup
      onStatusUpdate?.call('✅ Finalizando backup...');
      await _database.updateBackupStatus(backupId, 'completed');
      
      onProgress?.call(1.0); // 100% concluído
      onStatusUpdate?.call('🎉 Backup concluído com sucesso!');
      
      _logger.i('🎉 Backup completo finalizado com sucesso!');
      _logger.i('📦 Arquivo: $zipPath');
      _logger.i('🔐 Senha: $password');
      if (teraboxUrl != null) {
        _logger.i('☁️ Terabox: $teraboxUrl');
      }
      
      return backupId;
      
    } catch (e) {
      _logger.e('❌ Erro durante backup completo: $e');
      
      // Atualizar status para erro
      try {
        await _database.updateBackupStatus(backupId, 'failed');
      } catch (dbError) {
        _logger.e('❌ Erro ao atualizar status de falha: $dbError');
      }
      
      onStatusUpdate?.call('❌ Erro durante backup: $e');
      rethrow;
    }
  }

  /// Envia relatório de backups por email
  Future<bool> sendBackupReport({
    String? customMessage,
    int? lastDays,
  }) async {
    if (_gmailService == null) {
      _logger.w('⚠️ Gmail não configurado');
      return false;
    }
    
    _logger.i('📧 Enviando relatório de backups...');
    
    try {
      // Obter backups (últimos N dias ou todos)
      List<Backup> backups;
      if (lastDays != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: lastDays));
        backups = await _database.getBackupsSince(cutoffDate);
      } else {
        backups = await getAllBackups();
      }
      
      final success = await _gmailService!.sendBackupReport(
        backups: backups,
        database: _database,
        passwordManager: _passwordManager,
        customMessage: customMessage,
      );
      
      if (success) {
        _logger.i('✅ Relatório enviado com sucesso');
      } else {
        _logger.e('❌ Falha ao enviar relatório');
      }
      
      return success;
      
    } catch (e) {
      _logger.e('❌ Erro ao enviar relatório: $e');
      return false;
    }
  }

  /// Verifica se os serviços estão configurados
  bool get isTeraboxConfigured => _teraboxService != null;
  bool get isGmailConfigured => _gmailService != null;
  
  /// Obtém informações de quota do Terabox
  Future<TeraboxQuota?> getTeraboxQuota() async {
    if (_teraboxService == null) return null;
    
    try {
      if (!_teraboxService!.isAuthenticated) {
        await _teraboxService!.authenticate();
      }
      
      return await _teraboxService!.getQuotaInfo();
    } catch (e) {
      _logger.e('❌ Erro ao obter quota do Terabox: $e');
      return null;
    }
  }
}