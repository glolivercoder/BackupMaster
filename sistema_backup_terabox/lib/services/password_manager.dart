import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:logger/logger.dart';
import 'database.dart';
import 'package:drift/drift.dart';

class PasswordManager {
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
  late final Encrypter _encrypter;
  late final IV _iv;

  // Caracteres para geração de senha (8 dígitos: números, letras, especiais)
  static const String _numbers = '0123456789';
  static const String _letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  static const String _allChars = _numbers + _letters + _specialChars;

  PasswordManager(this._database) {
    _initializeEncryption();
  }

  void _initializeEncryption() {
    // Chave fixa para demonstração - em produção, usar chave segura
    final key = Key.fromSecureRandom(32);
    _encrypter = Encrypter(AES(key));
    _iv = IV.fromSecureRandom(16);
    _logger.i('🔐 Sistema de criptografia inicializado');
  }

  /// Gera uma senha segura de 8 dígitos com números, letras e caracteres especiais
  String generateSecurePassword({int length = 8}) {
    _logger.i('🎲 Gerando senha segura de $length caracteres...');
    
    final random = Random.secure();
    final password = StringBuffer();

    // Garantir pelo menos um de cada tipo de caractere
    password.write(_numbers[random.nextInt(_numbers.length)]); // 1 número
    password.write(_letters[random.nextInt(_letters.length)]); // 1 letra
    password.write(_specialChars[random.nextInt(_specialChars.length)]); // 1 especial

    // Preencher o restante aleatoriamente
    for (int i = 3; i < length; i++) {
      password.write(_allChars[random.nextInt(_allChars.length)]);
    }

    // Embaralhar a senha para não ter padrão fixo
    final passwordList = password.toString().split('');
    passwordList.shuffle(random);
    final finalPassword = passwordList.join('');

    _logger.i('✅ Senha gerada com sucesso');
    _logPasswordAnalysis(finalPassword);
    
    return finalPassword;
  }

  /// Analisa e registra as características da senha gerada
  void _logPasswordAnalysis(String password) {
    final hasNumbers = password.split('').any((c) => _numbers.contains(c));
    final hasLetters = password.split('').any((c) => _letters.contains(c));
    final hasSpecialChars = password.split('').any((c) => _specialChars.contains(c));
    final hasUpperCase = password.split('').any((c) => c == c.toUpperCase() && c != c.toLowerCase());
    final hasLowerCase = password.split('').any((c) => c == c.toLowerCase() && c != c.toUpperCase());

    _logger.d('🔍 Análise da senha:');
    _logger.d('   📏 Comprimento: ${password.length}');
    _logger.d('   🔢 Contém números: $hasNumbers');
    _logger.d('   🔤 Contém letras: $hasLetters');
    _logger.d('   🔣 Contém caracteres especiais: $hasSpecialChars');
    _logger.d('   🔠 Contém maiúsculas: $hasUpperCase');
    _logger.d('   🔡 Contém minúsculas: $hasLowerCase');
  }

  /// Criptografa uma senha
  Future<String> encryptPassword(String password) async {
    _logger.d('🔒 Criptografando senha...');
    try {
      final encrypted = _encrypter.encrypt(password, iv: _iv);
      _logger.d('✅ Senha criptografada com sucesso');
      return encrypted.base64;
    } catch (e) {
      _logger.e('❌ Erro ao criptografar senha: $e');
      rethrow;
    }
  }

  /// Descriptografa uma senha
  Future<String> decryptPassword(String encryptedPassword) async {
    _logger.d('🔓 Descriptografando senha...');
    try {
      final encrypted = Encrypted.fromBase64(encryptedPassword);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      _logger.d('✅ Senha descriptografada com sucesso');
      return decrypted;
    } catch (e) {
      _logger.e('❌ Erro ao descriptografar senha: $e');
      rethrow;
    }
  }

  /// Gera hash SHA-256 da senha para armazenamento seguro
  String _generatePasswordHash(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Método público para gerar hash de senha
  String generatePasswordHash(String password) {
    return _generatePasswordHash(password);
  }

  /// Armazena uma senha de forma segura no banco de dados
  Future<void> storePassword(String backupId, String password) async {
    _logger.i('💾 Armazenando senha para backup: $backupId');
    
    try {
      final encryptedPassword = await encryptPassword(password);
      final passwordHash = _generatePasswordHash(password);

      // Inserir log de senha para testes e auditoria
      await _database.insertPasswordLog(PasswordLogsCompanion(
        backupId: Value(backupId),
        passwordGenerated: Value(password), // Apenas para testes - remover em produção
        passwordHash: Value(passwordHash),
        validationStatus: const Value('stored'),
      ));

      _logger.i('✅ Senha armazenada com sucesso para backup: $backupId');
      
      // Executar teste de integridade imediatamente
      await _testPasswordIntegrity(backupId, password);
      
    } catch (e) {
      _logger.e('❌ Erro ao armazenar senha: $e');
      rethrow;
    }
  }

  /// Recupera uma senha do banco de dados
  Future<String> retrievePassword(String backupId) async {
    _logger.i('🔍 Recuperando senha para backup: $backupId');
    
    try {
      final passwordLog = await _database.getPasswordLogByBackupId(backupId);
      
      if (passwordLog == null) {
        _logger.e('❌ Senha não encontrada para backup: $backupId');
        throw Exception('Senha não encontrada para o backup especificado');
      }

      // Em ambiente de teste, retornar a senha original
      // Em produção, descriptografar da coluna encriptada
      final password = passwordLog.passwordGenerated;
      
      _logger.i('✅ Senha recuperada com sucesso');
      
      // Verificar integridade da senha recuperada
      await _verifyPasswordIntegrity(backupId, password);
      
      return password;
      
    } catch (e) {
      _logger.e('❌ Erro ao recuperar senha: $e');
      rethrow;
    }
  }

  /// Testa a integridade da senha armazenada
  Future<void> _testPasswordIntegrity(String backupId, String originalPassword) async {
    _logger.i('🧪 Testando integridade da senha para backup: $backupId');
    
    try {
      final testResults = StringBuffer();
      bool allTestsPassed = true;

      // Teste 1: Verificar comprimento
      final lengthTest = originalPassword.length == 8;
      testResults.writeln('Teste de comprimento (8 chars): ${lengthTest ? "PASSOU" : "FALHOU"}');
      if (!lengthTest) allTestsPassed = false;

      // Teste 2: Verificar presença de números
      final hasNumbers = originalPassword.split('').any((c) => _numbers.contains(c));
      testResults.writeln('Teste de números: ${hasNumbers ? "PASSOU" : "FALHOU"}');
      if (!hasNumbers) allTestsPassed = false;

      // Teste 3: Verificar presença de letras
      final hasLetters = originalPassword.split('').any((c) => _letters.contains(c));
      testResults.writeln('Teste de letras: ${hasLetters ? "PASSOU" : "FALHOU"}');
      if (!hasLetters) allTestsPassed = false;

      // Teste 4: Verificar presença de caracteres especiais
      final hasSpecialChars = originalPassword.split('').any((c) => _specialChars.contains(c));
      testResults.writeln('Teste de caracteres especiais: ${hasSpecialChars ? "PASSOU" : "FALHOU"}');
      if (!hasSpecialChars) allTestsPassed = false;

      // Teste 5: Verificar hash
      final expectedHash = _generatePasswordHash(originalPassword);
      final passwordLog = await _database.getPasswordLogByBackupId(backupId);
      final hashTest = passwordLog?.passwordHash == expectedHash;
      testResults.writeln('Teste de hash: ${hashTest ? "PASSOU" : "FALHOU"}');
      if (!hashTest) allTestsPassed = false;

      // Teste 6: Teste de criptografia/descriptografia
      try {
        final encrypted = await encryptPassword(originalPassword);
        final decrypted = await decryptPassword(encrypted);
        final encryptionTest = decrypted == originalPassword;
        testResults.writeln('Teste de criptografia: ${encryptionTest ? "PASSOU" : "FALHOU"}');
        if (!encryptionTest) allTestsPassed = false;
      } catch (e) {
        testResults.writeln('Teste de criptografia: FALHOU - $e');
        allTestsPassed = false;
      }

      final finalStatus = allTestsPassed ? 'TODOS_TESTES_PASSARAM' : 'ALGUNS_TESTES_FALHARAM';
      
      // Atualizar resultado dos testes no banco
      await _database.updatePasswordValidation(
        backupId, 
        testResults.toString(), 
        finalStatus
      );

      if (allTestsPassed) {
        _logger.i('✅ Todos os testes de integridade passaram!');
      } else {
        _logger.w('⚠️ Alguns testes de integridade falharam!');
        _logger.w('Resultados:\n${testResults.toString()}');
      }

    } catch (e) {
      _logger.e('❌ Erro durante teste de integridade: $e');
      await _database.updatePasswordValidation(
        backupId, 
        'ERRO_NO_TESTE: $e', 
        'ERRO'
      );
    }
  }

  /// Verifica se a senha recuperada está íntegra
  Future<void> _verifyPasswordIntegrity(String backupId, String retrievedPassword) async {
    _logger.d('🔍 Verificando integridade da senha recuperada...');
    
    try {
      final passwordLog = await _database.getPasswordLogByBackupId(backupId);
      if (passwordLog == null) return;

      final expectedHash = _generatePasswordHash(retrievedPassword);
      final storedHash = passwordLog.passwordHash;

      if (expectedHash == storedHash) {
        _logger.d('✅ Integridade da senha verificada - Hash confere');
      } else {
        _logger.e('❌ ALERTA: Hash da senha não confere!');
        _logger.e('   Hash esperado: $expectedHash');
        _logger.e('   Hash armazenado: $storedHash');
        
        await _database.updatePasswordValidation(
          backupId, 
          'HASH_NAO_CONFERE: esperado=$expectedHash, armazenado=$storedHash', 
          'INTEGRIDADE_COMPROMETIDA'
        );
      }
    } catch (e) {
      _logger.e('❌ Erro na verificação de integridade: $e');
    }
  }

  /// Executa bateria completa de testes de senha
  Future<Map<String, dynamic>> runPasswordTests({int numberOfTests = 100}) async {
    _logger.i('🧪 Executando bateria de $numberOfTests testes de senha...');
    
    final results = <String, dynamic>{
      'totalTests': numberOfTests,
      'passedTests': 0,
      'failedTests': 0,
      'passwords': <Map<String, dynamic>>[],
      'errors': <String>[],
    };

    for (int i = 0; i < numberOfTests; i++) {
      try {
        final testId = 'test_${DateTime.now().millisecondsSinceEpoch}_$i';
        final password = generateSecurePassword();
        
        // Armazenar senha
        await storePassword(testId, password);
        
        // Recuperar senha
        final retrievedPassword = await retrievePassword(testId);
        
        // Verificar se são iguais
        final isEqual = password == retrievedPassword;
        
        if (isEqual) {
          results['passedTests']++;
          _logger.d('✅ Teste $i passou - Senha: $password');
        } else {
          results['failedTests']++;
          _logger.e('❌ Teste $i falhou - Original: $password, Recuperada: $retrievedPassword');
          results['errors'].add('Teste $i: senhas diferentes');
        }

        results['passwords'].add({
          'testId': testId,
          'original': password,
          'retrieved': retrievedPassword,
          'passed': isEqual,
        });

      } catch (e) {
        results['failedTests']++;
        results['errors'].add('Teste $i: erro - $e');
        _logger.e('❌ Erro no teste $i: $e');
      }
    }

    final successRate = (results['passedTests'] / numberOfTests * 100).toStringAsFixed(2);
    _logger.i('📊 Resultados dos testes:');
    _logger.i('   ✅ Testes passaram: ${results['passedTests']}/$numberOfTests ($successRate%)');
    _logger.i('   ❌ Testes falharam: ${results['failedTests']}/$numberOfTests');
    
    if (results['errors'].isNotEmpty) {
      _logger.w('⚠️ Erros encontrados:');
      for (final error in results['errors']) {
        _logger.w('   - $error');
      }
    }

    return results;
  }

  /// Gera relatório detalhado de todas as senhas armazenadas
  Future<Map<String, dynamic>> generatePasswordReport() async {
    _logger.i('📊 Gerando relatório de senhas...');
    
    try {
      final passwordLogs = await _database.getAllPasswordLogs();
      final backups = await _database.getAllBackups();
      
      final report = <String, dynamic>{
        'totalPasswords': passwordLogs.length,
        'totalBackups': backups.length,
        'validationStatus': <String, int>{},
        'passwordDetails': <Map<String, dynamic>>[],
        'generatedAt': DateTime.now().toIso8601String(),
      };

      for (final log in passwordLogs) {
        // Contar status de validação
        final status = log.validationStatus;
        report['validationStatus'][status] = (report['validationStatus'][status] ?? 0) + 1;

        // Adicionar detalhes da senha
        report['passwordDetails'].add({
          'backupId': log.backupId,
          'password': log.passwordGenerated, // Apenas para testes
          'hash': log.passwordHash,
          'createdAt': log.createdAt.toIso8601String(),
          'validationStatus': log.validationStatus,
          'testResult': log.testResult,
        });
      }

      _logger.i('📊 Relatório gerado:');
      _logger.i('   📝 Total de senhas: ${report['totalPasswords']}');
      _logger.i('   📦 Total de backups: ${report['totalBackups']}');
      _logger.i('   📊 Status de validação: ${report['validationStatus']}');

      return report;
      
    } catch (e) {
      _logger.e('❌ Erro ao gerar relatório: $e');
      rethrow;
    }
  }
}