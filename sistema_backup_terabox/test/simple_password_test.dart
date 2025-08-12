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

  group('Testes Básicos de Senha', () {
    test('Deve gerar senha com 8 caracteres', () {
      logger.i('🧪 Testando comprimento da senha...');
      
      final password = passwordManager.generateSecurePassword();
      
      expect(password.length, equals(8));
      logger.i('✅ Senha gerada com 8 caracteres: $password');
    });

    test('Deve conter números, letras e caracteres especiais', () {
      logger.i('🧪 Testando composição da senha...');
      
      final password = passwordManager.generateSecurePassword();
      
      final hasNumber = password.split('').any((c) => '0123456789'.contains(c));
      final hasLetter = password.split('').any((c) => 
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(c));
      final hasSpecial = password.split('').any((c) => 
        '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c));
      
      expect(hasNumber, isTrue, reason: 'Senha deve conter pelo menos um número');
      expect(hasLetter, isTrue, reason: 'Senha deve conter pelo menos uma letra');
      expect(hasSpecial, isTrue, reason: 'Senha deve conter pelo menos um caractere especial');
      
      logger.i('✅ Senha válida: $password');
      logger.i('   📊 Números: $hasNumber, Letras: $hasLetter, Especiais: $hasSpecial');
    });

    test('Deve gerar senhas diferentes', () {
      logger.i('🧪 Testando unicidade das senhas...');
      
      final passwords = <String>{};
      for (int i = 0; i < 20; i++) {
        passwords.add(passwordManager.generateSecurePassword());
      }
      
      expect(passwords.length, equals(20));
      logger.i('✅ Geradas 20 senhas únicas');
      
      // Mostrar algumas senhas de exemplo
      final passwordList = passwords.toList();
      for (int i = 0; i < 5; i++) {
        logger.i('   ${i + 1}. ${passwordList[i]}');
      }
    });

    test('Deve criptografar e descriptografar', () async {
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

    test('Deve armazenar e recuperar senha', () async {
      logger.i('🧪 Testando armazenamento e recuperação...');
      
      const backupId = 'test_backup_001';
      final originalPassword = passwordManager.generateSecurePassword();
      
      logger.i('💾 Armazenando senha: $originalPassword');
      await passwordManager.storePassword(backupId, originalPassword);
      
      logger.i('🔍 Recuperando senha...');
      final retrievedPassword = await passwordManager.retrievePassword(backupId);
      
      expect(retrievedPassword, equals(originalPassword));
      logger.i('✅ Senha recuperada corretamente: $retrievedPassword');
    });
  });

  group('Testes de Integridade', () {
    test('Deve manter integridade em múltiplas operações', () async {
      logger.i('🧪 Testando integridade em múltiplas operações...');
      
      final testData = <String, String>{};
      
      // Armazenar 5 senhas
      for (int i = 0; i < 5; i++) {
        final backupId = 'integrity_test_${i.toString().padLeft(3, '0')}';
        final password = passwordManager.generateSecurePassword();
        
        await passwordManager.storePassword(backupId, password);
        testData[backupId] = password;
        
        logger.d('💾 Armazenada: $backupId -> $password');
      }
      
      // Verificar todas as senhas
      for (final entry in testData.entries) {
        final retrievedPassword = await passwordManager.retrievePassword(entry.key);
        expect(retrievedPassword, equals(entry.value));
        logger.d('✅ Verificada: ${entry.key} -> ${entry.value}');
      }
      
      logger.i('✅ Integridade mantida em 5 operações');
    });

    test('Deve executar bateria de testes', () async {
      logger.i('🧪 Executando bateria de testes...');
      
      final results = await passwordManager.runPasswordTests(numberOfTests: 10);
      
      expect(results['totalTests'], equals(10));
      expect(results['passedTests'], greaterThan(8)); // Pelo menos 80% de sucesso
      
      logger.i('📊 Resultados da bateria:');
      logger.i('   Total: ${results['totalTests']}');
      logger.i('   Passou: ${results['passedTests']}');
      logger.i('   Falhou: ${results['failedTests']}');
      
      final successRate = (results['passedTests'] / results['totalTests'] * 100);
      logger.i('   Taxa de sucesso: ${successRate.toStringAsFixed(1)}%');
      
      expect(successRate, greaterThanOrEqualTo(80.0));
      logger.i('✅ Bateria de testes executada com sucesso');
    });
  });
}

// Extensão para criar banco de teste
// Classe de banco de dados para testes
class TestAppDatabase extends AppDatabase {
  TestAppDatabase() : super._testConstructor(NativeDatabase.memory());
}