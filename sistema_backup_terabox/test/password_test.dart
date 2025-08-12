import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_backup_terabox/services/database.dart';
import 'package:sistema_backup_terabox/services/password_manager.dart';
import 'package:drift/native.dart';
import 'package:logger/logger.dart';

void main() {
  late TestAppDatabase database;
  late PasswordManager passwordManager;
  late Logger logger;

  setUpAll(() {
    logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  });

  setUp(() async {
    // Criar banco de dados em memória para testes
    database = TestAppDatabase();
    passwordManager = PasswordManager(database);
    
    logger.i('🧪 Configurando ambiente de teste...');
  });

  tearDown(() async {
    await database.close();
    logger.i('🧹 Limpando ambiente de teste...');
  });

  group('Testes de Geração de Senha', () {
    test('Deve gerar senha com 8 caracteres', () {
      logger.i('🧪 Testando comprimento da senha...');
      
      final password = passwordManager.generateSecurePassword();
      
      expect(password.length, equals(8));
      logger.i('✅ Senha gerada com 8 caracteres: $password');
    });

    test('Deve conter pelo menos um número', () {
      logger.i('🧪 Testando presença de números...');
      
      final password = passwordManager.generateSecurePassword();
      final hasNumber = password.split('').any((c) => '0123456789'.contains(c));
      
      expect(hasNumber, isTrue);
      logger.i('✅ Senha contém número: $password');
    });

    test('Deve conter pelo menos uma letra', () {
      logger.i('🧪 Testando presença de letras...');
      
      final password = passwordManager.generateSecurePassword();
      final hasLetter = password.split('').any((c) => 
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(c));
      
      expect(hasLetter, isTrue);
      logger.i('✅ Senha contém letra: $password');
    });

    test('Deve conter pelo menos um caractere especial', () {
      logger.i('🧪 Testando presença de caracteres especiais...');
      
      final password = passwordManager.generateSecurePassword();
      final hasSpecial = password.split('').any((c) => 
        '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c));
      
      expect(hasSpecial, isTrue);
      logger.i('✅ Senha contém caractere especial: $password');
    });

    test('Deve gerar senhas diferentes a cada chamada', () {
      logger.i('🧪 Testando unicidade das senhas...');
      
      final passwords = <String>{};
      for (int i = 0; i < 100; i++) {
        passwords.add(passwordManager.generateSecurePassword());
      }
      
      expect(passwords.length, equals(100));
      logger.i('✅ Geradas 100 senhas únicas');
    });
  });

  group('Testes de Armazenamento e Recuperação', () {
    test('Deve armazenar e recuperar senha corretamente', () async {
      logger.i('🧪 Testando armazenamento e recuperação...');
      
      const backupId = 'test_backup_001';
      final originalPassword = passwordManager.generateSecurePassword();
      
      // Armazenar senha
      await passwordManager.storePassword(backupId, originalPassword);
      logger.i('💾 Senha armazenada: $originalPassword');
      
      // Recuperar senha
      final retrievedPassword = await passwordManager.retrievePassword(backupId);
      logger.i('🔍 Senha recuperada: $retrievedPassword');
      
      expect(retrievedPassword, equals(originalPassword));
      logger.i('✅ Senha armazenada e recuperada corretamente');
    });

    test('Deve manter integridade após múltiplas operações', () async {
      logger.i('🧪 Testando integridade em múltiplas operações...');
      
      final testData = <String, String>{};
      
      // Armazenar múltiplas senhas
      for (int i = 0; i < 10; i++) {
        final backupId = 'test_backup_${i.toString().padLeft(3, '0')}';
        final password = passwordManager.generateSecurePassword();
        
        await passwordManager.storePassword(backupId, password);
        testData[backupId] = password;
        
        logger.d('💾 Armazenada senha $i: $password');
      }
      
      // Verificar todas as senhas
      for (final entry in testData.entries) {
        final retrievedPassword = await passwordManager.retrievePassword(entry.key);
        expect(retrievedPassword, equals(entry.value));
        logger.d('✅ Verificada senha ${entry.key}: ${entry.value}');
      }
      
      logger.i('✅ Integridade mantida em 10 operações');
    });

    test('Deve falhar ao recuperar senha inexistente', () async {
      logger.i('🧪 Testando recuperação de senha inexistente...');
      
      expect(
        () async => await passwordManager.retrievePassword('backup_inexistente'),
        throwsException,
      );
      
      logger.i('✅ Exceção lançada corretamente para senha inexistente');
    });
  });

  group('Testes de Criptografia', () {
    test('Deve criptografar e descriptografar corretamente', () async {
      logger.i('🧪 Testando criptografia...');
      
      final originalPassword = passwordManager.generateSecurePassword();
      logger.i('🔐 Senha original: $originalPassword');
      
      final encrypted = await passwordManager.encryptPassword(originalPassword);
      logger.i('🔒 Senha criptografada: $encrypted');
      
      final decrypted = await passwordManager.decryptPassword(encrypted);
      logger.i('🔓 Senha descriptografada: $decrypted');
      
      expect(decrypted, equals(originalPassword));
      expect(encrypted, isNot(equals(originalPassword)));
      
      logger.i('✅ Criptografia funcionando corretamente');
    });

    test('Senhas criptografadas devem ser diferentes', () async {
      logger.i('🧪 Testando unicidade da criptografia...');
      
      final password1 = passwordManager.generateSecurePassword();
      final password2 = passwordManager.generateSecurePassword();
      
      final encrypted1 = await passwordManager.encryptPassword(password1);
      final encrypted2 = await passwordManager.encryptPassword(password2);
      
      expect(encrypted1, isNot(equals(encrypted2)));
      logger.i('✅ Senhas criptografadas são únicas');
    });
  });

  group('Testes de Bateria Completa', () {
    test('Deve executar bateria de testes com sucesso', () async {
      logger.i('🧪 Executando bateria completa de testes...');
      
      final results = await passwordManager.runPasswordTests(numberOfTests: 50);
      
      expect(results['totalTests'], equals(50));
      expect(results['passedTests'], greaterThan(45)); // Pelo menos 90% de sucesso
      expect(results['failedTests'], lessThan(5));
      
      logger.i('📊 Resultados da bateria:');
      logger.i('   Total: ${results['totalTests']}');
      logger.i('   Passou: ${results['passedTests']}');
      logger.i('   Falhou: ${results['failedTests']}');
      
      final successRate = (results['passedTests'] / results['totalTests'] * 100);
      expect(successRate, greaterThanOrEqualTo(90.0));
      
      logger.i('✅ Bateria de testes executada com ${successRate.toStringAsFixed(1)}% de sucesso');
    });

    test('Deve gerar relatório detalhado', () async {
      logger.i('🧪 Testando geração de relatório...');
      
      // Criar algumas senhas de teste
      for (int i = 0; i < 5; i++) {
        final backupId = 'report_test_$i';
        final password = passwordManager.generateSecurePassword();
        await passwordManager.storePassword(backupId, password);
      }
      
      final report = await passwordManager.generatePasswordReport();
      
      expect(report['totalPasswords'], greaterThanOrEqualTo(5));
      expect(report['passwordDetails'], isA<List>());
      expect(report['validationStatus'], isA<Map>());
      expect(report['generatedAt'], isNotNull);
      
      logger.i('📊 Relatório gerado:');
      logger.i('   Total de senhas: ${report['totalPasswords']}');
      logger.i('   Status de validação: ${report['validationStatus']}');
      
      logger.i('✅ Relatório gerado com sucesso');
    });
  });

  group('Testes de Logs e Auditoria', () {
    test('Deve registrar logs de senha corretamente', () async {
      logger.i('🧪 Testando logs de auditoria...');
      
      const backupId = 'audit_test_001';
      final password = passwordManager.generateSecurePassword();
      
      await passwordManager.storePassword(backupId, password);
      
      final passwordLog = await database.getPasswordLogByBackupId(backupId);
      
      expect(passwordLog, isNotNull);
      expect(passwordLog!.backupId, equals(backupId));
      expect(passwordLog.passwordGenerated, equals(password));
      expect(passwordLog.validationStatus, isNotEmpty);
      
      logger.i('✅ Log de auditoria registrado corretamente');
    });

    test('Deve atualizar status de validação', () async {
      logger.i('🧪 Testando atualização de status...');
      
      const backupId = 'validation_test_001';
      final password = passwordManager.generateSecurePassword();
      
      await passwordManager.storePassword(backupId, password);
      
      // Aguardar um pouco para os testes assíncronos
      await Future.delayed(const Duration(milliseconds: 100));
      
      final passwordLog = await database.getPasswordLogByBackupId(backupId);
      
      expect(passwordLog, isNotNull);
      expect(passwordLog!.testResult, isNotNull);
      expect(passwordLog.validationStatus, isIn(['TODOS_TESTES_PASSARAM', 'ALGUNS_TESTES_FALHARAM', 'stored']));
      
      logger.i('✅ Status de validação atualizado: ${passwordLog.validationStatus}');
    });
  });

  group('Testes de Performance', () {
    test('Deve gerar senhas rapidamente', () async {
      logger.i('🧪 Testando performance de geração...');
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 1000; i++) {
        passwordManager.generateSecurePassword();
      }
      
      stopwatch.stop();
      final timePerPassword = stopwatch.elapsedMicroseconds / 1000;
      
      expect(timePerPassword, lessThan(1000)); // Menos de 1ms por senha
      
      logger.i('⚡ Geradas 1000 senhas em ${stopwatch.elapsedMilliseconds}ms');
      logger.i('⚡ Tempo médio por senha: ${timePerPassword.toStringAsFixed(2)}μs');
    });

    test('Deve armazenar e recuperar senhas rapidamente', () async {
      logger.i('🧪 Testando performance de armazenamento...');
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        final backupId = 'perf_test_$i';
        final password = passwordManager.generateSecurePassword();
        
        await passwordManager.storePassword(backupId, password);
        await passwordManager.retrievePassword(backupId);
      }
      
      stopwatch.stop();
      final timePerOperation = stopwatch.elapsedMilliseconds / 100;
      
      expect(timePerOperation, lessThan(100)); // Menos de 100ms por operação completa
      
      logger.i('⚡ 100 operações completas em ${stopwatch.elapsedMilliseconds}ms');
      logger.i('⚡ Tempo médio por operação: ${timePerOperation.toStringAsFixed(2)}ms');
    });
  });
}

// Classe de banco de dados para testes
class TestAppDatabase extends AppDatabase {
  TestAppDatabase() : super._testConstructor(NativeDatabase.memory());
  
  TestAppDatabase._testConstructor(super.executor) : super._testConstructor();
}