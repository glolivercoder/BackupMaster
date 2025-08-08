import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';

part 'database.g.dart';

// Tabela de Backups
class Backups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get originalPath => text()();
  TextColumn get zipPath => text().nullable()();
  TextColumn get teraboxUrl => text().nullable()();
  TextColumn get passwordHash => text()();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('creating'))();
  TextColumn get checksum => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabela de Logs de Email
class EmailLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get backupId => text().nullable()();
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get recipient => text()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();
}

// Tabela de Logs de Senhas (para testes e auditoria)
class PasswordLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get backupId => text()();
  TextColumn get passwordGenerated => text()(); // Senha original (apenas para testes)
  TextColumn get passwordHash => text()(); // Hash da senha
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get testResult => text().nullable()(); // Resultado dos testes
  TextColumn get validationStatus => text().withDefault(const Constant('pending'))();
}

// Enum para Status do Backup
enum BackupStatus {
  creating('Criando'),
  uploading('Enviando'),
  completed('Concluído'),
  failed('Falhou'),
  deleted('Deletado');

  const BackupStatus(this.displayName);
  final String displayName;
}

@DriftDatabase(tables: [Backups, EmailLogs, PasswordLogs])
class AppDatabase extends _$AppDatabase {
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

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        _logger.i('🗄️ Criando banco de dados...');
        await m.createAll();
        _logger.i('✅ Banco de dados criado com sucesso!');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        _logger.i('🔄 Atualizando banco de dados da versão $from para $to...');
        // Futuras migrações aqui
      },
    );
  }

  // Métodos para Backups
  Future<List<Backup>> getAllBackups() async {
    _logger.d('📋 Buscando todos os backups...');
    final backupList = await select(backups).get();
    _logger.d('📋 Encontrados ${backupList.length} backups');
    return backupList;
  }

  Future<Backup?> getBackupById(String id) async {
    _logger.d('🔍 Buscando backup com ID: $id');
    final backup = await (select(backups)..where((b) => b.id.equals(id))).getSingleOrNull();
    if (backup != null) {
      _logger.d('✅ Backup encontrado: ${backup.name}');
    } else {
      _logger.w('⚠️ Backup não encontrado com ID: $id');
    }
    return backup;
  }

  Future<int> insertBackup(BackupsCompanion backup) async {
    _logger.i('💾 Inserindo novo backup: ${backup.name.value}');
    final result = await into(backups).insert(backup);
    _logger.i('✅ Backup inserido com sucesso!');
    return result;
  }

  Future<bool> updateBackupStatus(String id, String status) async {
    _logger.i('🔄 Atualizando status do backup $id para: $status');
    final result = await (update(backups)..where((b) => b.id.equals(id)))
        .write(BackupsCompanion(status: Value(status)));
    final success = result > 0;
    if (success) {
      _logger.i('✅ Status atualizado com sucesso!');
    } else {
      _logger.e('❌ Falha ao atualizar status do backup');
    }
    return success;
  }

  Future<List<Backup>> searchBackups(String query) async {
    _logger.d('🔍 Buscando backups com query: "$query"');
    final results = await (select(backups)
          ..where((b) => b.name.contains(query) | b.originalPath.contains(query)))
        .get();
    _logger.d('🔍 Encontrados ${results.length} resultados para "$query"');
    return results;
  }

  // Métodos para Logs de Senha (Sistema de Testes)
  Future<int> insertPasswordLog(PasswordLogsCompanion log) async {
    _logger.i('🔐 Registrando log de senha para backup: ${log.backupId.value}');
    final result = await into(passwordLogs).insert(log);
    _logger.i('✅ Log de senha registrado com ID: $result');
    return result;
  }

  Future<PasswordLog?> getPasswordLogByBackupId(String backupId) async {
    _logger.d('🔍 Buscando log de senha para backup: $backupId');
    final log = await (select(passwordLogs)..where((p) => p.backupId.equals(backupId)))
        .getSingleOrNull();
    if (log != null) {
      _logger.d('✅ Log de senha encontrado');
    } else {
      _logger.w('⚠️ Log de senha não encontrado para backup: $backupId');
    }
    return log;
  }

  Future<List<PasswordLog>> getAllPasswordLogs() async {
    _logger.d('📋 Buscando todos os logs de senha...');
    final logs = await select(passwordLogs).get();
    _logger.d('📋 Encontrados ${logs.length} logs de senha');
    return logs;
  }

  Future<bool> updatePasswordValidation(String backupId, String testResult, String status) async {
    _logger.i('🧪 Atualizando validação de senha para backup: $backupId');
    final result = await (update(passwordLogs)..where((p) => p.backupId.equals(backupId)))
        .write(PasswordLogsCompanion(
          testResult: Value(testResult),
          validationStatus: Value(status),
        ));
    final success = result > 0;
    if (success) {
      _logger.i('✅ Validação de senha atualizada!');
    } else {
      _logger.e('❌ Falha ao atualizar validação de senha');
    }
    return success;
  }

  // Métodos para Email Logs
  Future<int> insertEmailLog(EmailLogsCompanion log) async {
    _logger.i('📧 Registrando log de email...');
    final result = await into(emailLogs).insert(log);
    _logger.i('✅ Log de email registrado com ID: $result');
    return result;
  }

  Future<List<EmailLog>> getEmailLogsByBackupId(String backupId) async {
    _logger.d('📧 Buscando logs de email para backup: $backupId');
    final logs = await (select(emailLogs)..where((e) => e.backupId.equals(backupId))).get();
    _logger.d('📧 Encontrados ${logs.length} logs de email');
    return logs;
  }

  // Métodos adicionais para integração com Terabox e Gmail
  Future<bool> updateBackup(Backup backup) async {
    _logger.i('🔄 Atualizando backup: ${backup.id}');
    final result = await update(backups).replace(backup);
    final success = result;
    if (success) {
      _logger.i('✅ Backup atualizado com sucesso!');
    } else {
      _logger.e('❌ Falha ao atualizar backup');
    }
    return success;
  }

  Future<List<Backup>> getBackupsSince(DateTime date) async {
    _logger.d('📋 Buscando backups desde: $date');
    final backupList = await (select(backups)..where((b) => b.createdAt.isBiggerOrEqualValue(date))).get();
    _logger.d('📋 Encontrados ${backupList.length} backups desde $date');
    return backupList;
  }

  Future<List<Backup>> getBackupsByStatus(String status) async {
    _logger.d('📋 Buscando backups com status: $status');
    final backupList = await (select(backups)..where((b) => b.status.equals(status))).get();
    _logger.d('📋 Encontrados ${backupList.length} backups com status $status');
    return backupList;
  }

  Future<List<Backup>> getRecentBackups({int limit = 10}) async {
    _logger.d('📋 Buscando os $limit backups mais recentes...');
    final backupList = await (select(backups)
          ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])
          ..limit(limit))
        .get();
    _logger.d('📋 Encontrados ${backupList.length} backups recentes');
    return backupList;
  }

  // Método para backup do banco de dados
  Future<String> createDatabaseBackup() async {
    _logger.i('💾 Criando backup do banco de dados...');
    try {
      final dbFile = File(await _getDatabasePath());
      final backupDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath = p.join(backupDir.path, 'db_backup_$timestamp.db');
      
      await dbFile.copy(backupPath);
      _logger.i('✅ Backup do banco criado em: $backupPath');
      return backupPath;
    } catch (e) {
      _logger.e('❌ Erro ao criar backup do banco: $e');
      rethrow;
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'backup_system.db'));
    
    AppDatabase._logger.i('🗄️ Conectando ao banco de dados: ${file.path}');
    
    return NativeDatabase.createInBackground(file);
  });
}

Future<String> _getDatabasePath() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return p.join(dbFolder.path, 'backup_system.db');
}