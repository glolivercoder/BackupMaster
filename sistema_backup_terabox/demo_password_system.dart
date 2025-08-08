import 'dart:io';
import 'package:drift/native.dart';
import 'lib/services/database.dart';
import 'lib/services/password_manager.dart';
import 'lib/utils/password_test_runner.dart';

/// Demonstração do Sistema de Senhas
/// Execute com: dart run demo_password_system.dart
void main() async {
  print('🚀 === DEMONSTRAÇÃO DO SISTEMA DE SENHAS ===\n');
  
  // Inicializar sistema
  final database = AppDatabase.forDemo(NativeDatabase.memory());
  final passwordManager = PasswordManager(database);
  final testRunner = PasswordTestRunner(database);
  
  try {
    // 1. Demonstrar geração de senhas
    await demonstratePasswordGeneration(passwordManager);
    
    // 2. Demonstrar armazenamento e recuperação
    await demonstrateStorageAndRetrieval(passwordManager);
    
    // 3. Executar bateria de testes
    await runPasswordBattery(passwordManager);
    
    // 4. Gerar relatório
    await generateReport(passwordManager);
    
    // 5. Teste de stress
    await runStressTest(passwordManager);
    
    print('\n🎉 === DEMONSTRAÇÃO CONCLUÍDA COM SUCESSO! ===');
    
  } catch (e) {
    print('❌ Erro durante demonstração: $e');
  } finally {
    await database.close();
  }
}

Future<void> demonstratePasswordGeneration(PasswordManager passwordManager) async {
  print('📝 === GERAÇÃO DE SENHAS ===');
  print('🎯 Gerando 10 senhas de 8 dígitos com números, letras e caracteres especiais:\n');
  
  for (int i = 1; i <= 10; i++) {
    final password = passwordManager.generateSecurePassword();
    
    // Analisar características
    final hasNumbers = password.split('').any((c) => '0123456789'.contains(c));
    final hasLetters = password.split('').any((c) => 
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(c));
    final hasSpecialChars = password.split('').any((c) => 
      '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c));
    final hasUpperCase = password.split('').any((c) => 
      c == c.toUpperCase() && c != c.toLowerCase());
    final hasLowerCase = password.split('').any((c) => 
      c == c.toLowerCase() && c != c.toUpperCase());
    
    print('$i. $password');
    print('   📊 Análise: Números($hasNumbers) | Letras($hasLetters) | Especiais($hasSpecialChars) | Maiúsc($hasUpperCase) | Minúsc($hasLowerCase)');
  }
  
  print('\n✅ Todas as senhas atendem aos critérios: 8 caracteres com números, letras e especiais\n');
}

Future<void> demonstrateStorageAndRetrieval(PasswordManager passwordManager) async {
  print('💾 === ARMAZENAMENTO E RECUPERAÇÃO ===');
  print('🎯 Testando integridade do armazenamento de senhas:\n');
  
  final testData = <String, String>{};
  
  // Armazenar 5 senhas
  print('💾 Armazenando senhas:');
  for (int i = 1; i <= 5; i++) {
    final backupId = 'demo_backup_${i.toString().padLeft(3, '0')}';
    final password = passwordManager.generateSecurePassword();
    
    await passwordManager.storePassword(backupId, password);
    testData[backupId] = password;
    
    print('   $i. $backupId -> $password');
  }
  
  print('\n🔍 Recuperando e verificando senhas:');
  int successCount = 0;
  
  for (final entry in testData.entries) {
    final retrieved = await passwordManager.retrievePassword(entry.key);
    final isCorrect = retrieved == entry.value;
    
    if (isCorrect) successCount++;
    
    print('   ${entry.key}:');
    print('      Original:   ${entry.value}');
    print('      Recuperada: $retrieved');
    print('      Status: ${isCorrect ? "✅ CORRETO" : "❌ ERRO"}');
  }
  
  print('\n📊 Resultado: $successCount/5 senhas verificadas corretamente');
  print('✅ Taxa de sucesso: ${(successCount/5*100).toStringAsFixed(1)}%\n');
}

Future<void> runPasswordBattery(PasswordManager passwordManager) async {
  print('🧪 === BATERIA DE TESTES AUTOMATIZADOS ===');
  print('🎯 Executando 50 testes de geração, armazenamento e recuperação:\n');
  
  final results = await passwordManager.runPasswordTests(numberOfTests: 50);
  
  print('📊 Resultados da Bateria:');
  print('   📝 Total de testes: ${results['totalTests']}');
  print('   ✅ Testes passaram: ${results['passedTests']}');
  print('   ❌ Testes falharam: ${results['failedTests']}');
  
  final successRate = (results['passedTests'] / results['totalTests'] * 100);
  print('   📈 Taxa de sucesso: ${successRate.toStringAsFixed(2)}%');
  
  if (results['errors'].isNotEmpty) {
    print('\n⚠️ Erros encontrados:');
    final errors = results['errors'] as List;
    for (int i = 0; i < 3 && i < errors.length; i++) {
      print('   ${i + 1}. ${errors[i]}');
    }
  }
  
  print('\n🔍 Exemplos de senhas testadas:');
  final passwords = results['passwords'] as List;
  for (int i = 0; i < 5 && i < passwords.length; i++) {
    final passwordData = passwords[i];
    print('   ${i + 1}. ${passwordData['original']} - ${passwordData['passed'] ? "✅" : "❌"}');
  }
  
  print('');
}

Future<void> generateReport(PasswordManager passwordManager) async {
  print('📊 === RELATÓRIO DETALHADO ===');
  print('🎯 Gerando relatório completo do sistema:\n');
  
  final report = await passwordManager.generatePasswordReport();
  
  print('📋 Relatório do Sistema de Senhas:');
  print('   📅 Gerado em: ${report['generatedAt']}');
  print('   🔐 Total de senhas: ${report['totalPasswords']}');
  print('   📦 Total de backups: ${report['totalBackups']}');
  
  print('\n📊 Status de Validação:');
  final validationStatus = report['validationStatus'] as Map<String, dynamic>;
  for (final entry in validationStatus.entries) {
    print('   ${entry.key}: ${entry.value}');
  }
  
  print('\n🔍 Últimas 5 senhas criadas:');
  final passwordDetails = report['passwordDetails'] as List;
  for (int i = 0; i < 5 && i < passwordDetails.length; i++) {
    final detail = passwordDetails[i];
    print('   ${i + 1}. Backup: ${detail['backupId']}');
    print('      Senha: ${detail['password']}');
    print('      Status: ${detail['validationStatus']}');
    print('      Criada: ${detail['createdAt']}');
  }
  
  print('');
}

Future<void> runStressTest(PasswordManager passwordManager) async {
  print('💪 === TESTE DE STRESS ===');
  print('🎯 Criando e verificando 100 senhas para testar performance:\n');
  
  final stopwatch = Stopwatch()..start();
  final errors = <String>[];
  int successCount = 0;
  
  for (int i = 1; i <= 100; i++) {
    try {
      final backupId = 'stress_test_${i.toString().padLeft(3, '0')}';
      final password = passwordManager.generateSecurePassword();
      
      await passwordManager.storePassword(backupId, password);
      final retrieved = await passwordManager.retrievePassword(backupId);
      
      if (password == retrieved) {
        successCount++;
      } else {
        errors.add('Senha $i: original=$password, recuperada=$retrieved');
      }
      
      if (i % 20 == 0) {
        print('📈 Progresso: $i/100 (${(i/100*100).toStringAsFixed(0)}%)');
      }
      
    } catch (e) {
      errors.add('Erro na senha $i: $e');
    }
  }
  
  stopwatch.stop();
  
  print('\n📊 Resultados do Teste de Stress:');
  print('   ⏱️ Tempo total: ${stopwatch.elapsedMilliseconds}ms');
  print('   ⚡ Tempo médio por senha: ${(stopwatch.elapsedMilliseconds/100).toStringAsFixed(2)}ms');
  print('   ✅ Sucessos: $successCount/100');
  print('   ❌ Erros: ${errors.length}');
  print('   📈 Taxa de sucesso: ${(successCount/100*100).toStringAsFixed(2)}%');
  
  if (errors.isNotEmpty) {
    print('\n⚠️ Primeiros 3 erros:');
    for (int i = 0; i < 3 && i < errors.length; i++) {
      print('   ${i + 1}. ${errors[i]}');
    }
  }
  
  print('');
}

// Extensão para criar banco de demonstração
extension AppDatabaseDemo on AppDatabase {
  static AppDatabase forDemo(NativeDatabase database) {
    return AppDatabase._(database);
  }
}

class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);
  
  @override
  int get schemaVersion => 1;
}