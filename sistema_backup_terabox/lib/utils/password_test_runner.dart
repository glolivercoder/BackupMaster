import 'package:logger/logger.dart';
import '../services/database.dart';
import '../services/password_manager.dart';

/// Classe utilitária para executar testes de senha em ambiente de produção
class PasswordTestRunner {
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

  PasswordTestRunner(this._database) : _passwordManager = PasswordManager(_database);

  /// Executa uma demonstração completa do sistema de senhas
  Future<void> runPasswordDemo() async {
    _logger.i('🚀 Iniciando demonstração do sistema de senhas...');
    
    try {
      // 1. Demonstrar geração de senhas
      await _demonstratePasswordGeneration();
      
      // 2. Demonstrar armazenamento e recuperação
      await _demonstrateStorageAndRetrieval();
      
      // 3. Executar bateria de testes
      await _runPasswordBattery();
      
      // 4. Gerar relatório
      await _generateReport();
      
      // 5. Demonstrar verificação de integridade
      await _demonstrateIntegrityCheck();
      
      _logger.i('🎉 Demonstração concluída com sucesso!');
      
    } catch (e) {
      _logger.e('❌ Erro durante demonstração: $e');
      rethrow;
    }
  }

  /// Demonstra a geração de senhas com diferentes características
  Future<void> _demonstratePasswordGeneration() async {
    _logger.i('📝 === DEMONSTRAÇÃO DE GERAÇÃO DE SENHAS ===');
    
    _logger.i('🎲 Gerando 10 senhas de exemplo:');
    for (int i = 1; i <= 10; i++) {
      final password = _passwordManager.generateSecurePassword();
      _logger.i('   $i. $password');
      
      // Analisar características da senha
      _analyzePassword(password, i);
    }
  }

  /// Analisa as características de uma senha
  void _analyzePassword(String password, int index) {
    final hasNumbers = password.split('').any((c) => '0123456789'.contains(c));
    final hasLetters = password.split('').any((c) => 
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(c));
    final hasSpecialChars = password.split('').any((c) => 
      '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c));
    final hasUpperCase = password.split('').any((c) => 
      c == c.toUpperCase() && c != c.toLowerCase());
    final hasLowerCase = password.split('').any((c) => 
      c == c.toLowerCase() && c != c.toUpperCase());

    _logger.d('      📊 Análise da senha $index:');
    _logger.d('         📏 Comprimento: ${password.length}');
    _logger.d('         🔢 Números: $hasNumbers');
    _logger.d('         🔤 Letras: $hasLetters');
    _logger.d('         🔣 Especiais: $hasSpecialChars');
    _logger.d('         🔠 Maiúsculas: $hasUpperCase');
    _logger.d('         🔡 Minúsculas: $hasLowerCase');
  }

  /// Demonstra armazenamento e recuperação de senhas
  Future<void> _demonstrateStorageAndRetrieval() async {
    _logger.i('💾 === DEMONSTRAÇÃO DE ARMAZENAMENTO E RECUPERAÇÃO ===');
    
    final testCases = <String, String>{};
    
    // Armazenar 5 senhas de teste
    for (int i = 1; i <= 5; i++) {
      final backupId = 'demo_backup_${i.toString().padLeft(3, '0')}';
      final password = _passwordManager.generateSecurePassword();
      
      _logger.i('💾 Armazenando senha para backup $backupId: $password');
      await _passwordManager.storePassword(backupId, password);
      testCases[backupId] = password;
      
      // Aguardar um pouco para ver os logs
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    _logger.i('🔍 Recuperando senhas armazenadas:');
    
    // Recuperar e verificar todas as senhas
    for (final entry in testCases.entries) {
      final retrievedPassword = await _passwordManager.retrievePassword(entry.key);
      final isCorrect = retrievedPassword == entry.value;
      
      _logger.i('🔍 Backup ${entry.key}:');
      _logger.i('   Original:   ${entry.value}');
      _logger.i('   Recuperada: $retrievedPassword');
      _logger.i('   Status: ${isCorrect ? "✅ CORRETO" : "❌ ERRO"}');
      
      if (!isCorrect) {
        _logger.e('❌ ALERTA: Senha recuperada não confere com a original!');
      }
    }
  }

  /// Executa bateria de testes automatizados
  Future<void> _runPasswordBattery() async {
    _logger.i('🧪 === EXECUTANDO BATERIA DE TESTES ===');
    
    final results = await _passwordManager.runPasswordTests(numberOfTests: 50);
    
    _logger.i('📊 Resultados da bateria de testes:');
    _logger.i('   📝 Total de testes: ${results['totalTests']}');
    _logger.i('   ✅ Testes passaram: ${results['passedTests']}');
    _logger.i('   ❌ Testes falharam: ${results['failedTests']}');
    
    final successRate = (results['passedTests'] / results['totalTests'] * 100);
    _logger.i('   📈 Taxa de sucesso: ${successRate.toStringAsFixed(2)}%');
    
    if (results['errors'].isNotEmpty) {
      _logger.w('⚠️ Erros encontrados:');
      for (final error in results['errors']) {
        _logger.w('   - $error');
      }
    }
    
    // Mostrar algumas senhas de exemplo dos testes
    _logger.i('🔍 Exemplos de senhas testadas:');
    final passwords = results['passwords'] as List;
    for (int i = 0; i < 5 && i < passwords.length; i++) {
      final passwordData = passwords[i];
      _logger.i('   ${i + 1}. ${passwordData['original']} - ${passwordData['passed'] ? "✅" : "❌"}');
    }
  }

  /// Gera relatório detalhado do sistema
  Future<void> _generateReport() async {
    _logger.i('📊 === GERANDO RELATÓRIO DETALHADO ===');
    
    final report = await _passwordManager.generatePasswordReport();
    
    _logger.i('📋 Relatório do Sistema de Senhas:');
    _logger.i('   📅 Gerado em: ${report['generatedAt']}');
    _logger.i('   🔐 Total de senhas: ${report['totalPasswords']}');
    _logger.i('   📦 Total de backups: ${report['totalBackups']}');
    
    _logger.i('📊 Status de Validação:');
    final validationStatus = report['validationStatus'] as Map<String, dynamic>;
    for (final entry in validationStatus.entries) {
      _logger.i('   ${entry.key}: ${entry.value}');
    }
    
    // Mostrar detalhes de algumas senhas
    final passwordDetails = report['passwordDetails'] as List;
    if (passwordDetails.isNotEmpty) {
      _logger.i('🔍 Detalhes das últimas 5 senhas:');
      for (int i = 0; i < 5 && i < passwordDetails.length; i++) {
        final detail = passwordDetails[i];
        _logger.i('   ${i + 1}. Backup: ${detail['backupId']}');
        _logger.i('      Senha: ${detail['password']}');
        _logger.i('      Status: ${detail['validationStatus']}');
        _logger.i('      Criada: ${detail['createdAt']}');
      }
    }
  }

  /// Demonstra verificação de integridade
  Future<void> _demonstrateIntegrityCheck() async {
    _logger.i('🔍 === DEMONSTRAÇÃO DE VERIFICAÇÃO DE INTEGRIDADE ===');
    
    // Criar um backup de teste
    const backupId = 'integrity_test_backup';
    final password = _passwordManager.generateSecurePassword();
    
    _logger.i('🔐 Criando backup de teste com senha: $password');
    await _passwordManager.storePassword(backupId, password);
    
    // Aguardar os testes de integridade
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Verificar o log de senha
    final passwordLog = await _database.getPasswordLogByBackupId(backupId);
    
    if (passwordLog != null) {
      _logger.i('📋 Resultado da verificação de integridade:');
      _logger.i('   🆔 Backup ID: ${passwordLog.backupId}');
      _logger.i('   🔐 Senha: ${passwordLog.passwordGenerated}');
      _logger.i('   📊 Status: ${passwordLog.validationStatus}');
      _logger.i('   📝 Resultado dos testes:');
      
      if (passwordLog.testResult != null) {
        final testLines = passwordLog.testResult!.split('\n');
        for (final line in testLines) {
          if (line.trim().isNotEmpty) {
            _logger.i('      $line');
          }
        }
      }
    }
    
    // Testar recuperação
    _logger.i('🔍 Testando recuperação da senha...');
    final retrievedPassword = await _passwordManager.retrievePassword(backupId);
    final isIntact = retrievedPassword == password;
    
    _logger.i('   Original:   $password');
    _logger.i('   Recuperada: $retrievedPassword');
    _logger.i('   Integridade: ${isIntact ? "✅ ÍNTEGRA" : "❌ COMPROMETIDA"}');
  }

  /// Executa teste de stress do sistema
  Future<void> runStressTest({int numberOfPasswords = 1000}) async {
    _logger.i('💪 === EXECUTANDO TESTE DE STRESS ===');
    _logger.i('🎯 Objetivo: Criar e verificar $numberOfPasswords senhas');
    
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    int successCount = 0;
    
    for (int i = 1; i <= numberOfPasswords; i++) {
      try {
        final backupId = 'stress_test_${i.toString().padLeft(6, '0')}';
        final password = _passwordManager.generateSecurePassword();
        
        await _passwordManager.storePassword(backupId, password);
        final retrieved = await _passwordManager.retrievePassword(backupId);
        
        if (password == retrieved) {
          successCount++;
        } else {
          errors.add('Senha $i: original=$password, recuperada=$retrieved');
        }
        
        if (i % 100 == 0) {
          _logger.i('📈 Progresso: $i/$numberOfPasswords (${(i/numberOfPasswords*100).toStringAsFixed(1)}%)');
        }
        
      } catch (e) {
        errors.add('Erro na senha $i: $e');
      }
    }
    
    stopwatch.stop();
    
    _logger.i('📊 === RESULTADOS DO TESTE DE STRESS ===');
    _logger.i('   ⏱️ Tempo total: ${stopwatch.elapsedMilliseconds}ms');
    _logger.i('   ⚡ Tempo médio por senha: ${(stopwatch.elapsedMilliseconds/numberOfPasswords).toStringAsFixed(2)}ms');
    _logger.i('   ✅ Sucessos: $successCount/$numberOfPasswords');
    _logger.i('   ❌ Erros: ${errors.length}');
    _logger.i('   📈 Taxa de sucesso: ${(successCount/numberOfPasswords*100).toStringAsFixed(2)}%');
    
    if (errors.isNotEmpty) {
      _logger.w('⚠️ Primeiros 10 erros:');
      for (int i = 0; i < 10 && i < errors.length; i++) {
        _logger.w('   ${i + 1}. ${errors[i]}');
      }
    }
  }
}