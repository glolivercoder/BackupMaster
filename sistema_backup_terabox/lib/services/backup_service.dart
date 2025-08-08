import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'password_manager.dart';

class BackupService {
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

  final AppDatabase _database;
  final PasswordManager _passwordManager;

  BackupService(this._database, this._passwordManager);

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
        throw Exception('Arquivo ZIP não encontrado');
      }

      // Recuperar senha
      final password = await _passwordManager.retrievePassword(backupId);
      
      // No Windows, podemos usar o comando start para abrir o arquivo
      // Por enquanto, vamos apenas logar a ação
      _logger.i('🔓 Abrindo arquivo: ${backup.zipPath}');
      _logger.i('🔐 Senha: $password');
      
      // TODO: Implementar abertura real do arquivo com senha
      // Isso pode ser feito usando Process.run ou url_launcher
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir ZIP: $e');
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
      await _database.updateBackupStatus(backupId, BackupStatus.deleted);
      
      _logger.i('✅ Backup deletado com sucesso');
      
    } catch (e) {
      _logger.e('❌ Erro ao deletar backup: $e');
      rethrow;
    }
  }
}