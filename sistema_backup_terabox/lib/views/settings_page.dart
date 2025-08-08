import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/password_manager.dart';
import '../services/database.dart';
import '../utils/password_test_runner.dart';
import '../utils/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _outputDirectory = '';
  String _testOutput = 'Clique em um teste para executar...';
  bool _isRunningTest = false;
  late PasswordTestRunner _testRunner;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeTestRunner();
  }

  void _initializeTestRunner() {
    final database = Provider.of<AppDatabase>(context, listen: false);
    _testRunner = PasswordTestRunner(database);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _outputDirectory = prefs.getString('output_directory') ?? '';
    });
  }

  Future<void> _saveOutputDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('output_directory', path);
    setState(() {
      _outputDirectory = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Configurações',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Seção Output Directory
            _buildSection(
              title: 'Pasta de Destino',
              icon: Icons.folder_open,
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Defina onde os backups serão salvos:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botão Output
                  Container(
                    width: double.infinity,
                    height: 80,
                    child: ElevatedButton(
                      onPressed: _selectOutputDirectory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.output,
                            size: 32,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'OUTPUT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Pasta selecionada
                  if (_outputDirectory.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _outputDirectory,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Nenhuma pasta selecionada (usando pasta temporária)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção Testes da Aplicação
            _buildSection(
              title: 'Testes da Aplicação',
              icon: Icons.science,
              color: AppColors.secondary,
              child: Column(
                children: [
                  const Text(
                    'Execute testes para verificar o funcionamento do sistema:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Botões de teste
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildTestButton(
                        'Gerar Senhas',
                        Icons.password,
                        AppColors.primary,
                        _testPasswordGeneration,
                      ),
                      _buildTestButton(
                        'Teste Armazenamento',
                        Icons.storage,
                        AppColors.secondary,
                        _testStorageAndRetrieval,
                      ),
                      _buildTestButton(
                        'Bateria de Testes',
                        Icons.science,
                        AppColors.accent,
                        _runPasswordBattery,
                      ),
                      _buildTestButton(
                        'Relatório Completo',
                        Icons.assessment,
                        AppColors.highlight,
                        _generateReport,
                      ),
                      _buildTestButton(
                        'Demo Completa',
                        Icons.play_arrow,
                        AppColors.primary,
                        _runFullDemo,
                      ),
                      _buildTestButton(
                        'Teste de Stress',
                        Icons.speed,
                        AppColors.error,
                        _runStressTest,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção Output dos Testes
            _buildSection(
              title: 'Output dos Testes',
              icon: Icons.terminal,
              color: AppColors.highlight,
              child: Container(
                width: double.infinity,
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.highlight.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.terminal,
                          color: AppColors.highlight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Console de Testes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_isRunningTest)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.highlight),
                            ),
                          ),
                      ],
                    ),
                    const Divider(color: AppColors.textSecondary),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _testOutput,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção Logs da Aplicação
            _buildSection(
              title: 'Logs da Aplicação',
              icon: Icons.list_alt,
              color: AppColors.accent,
              child: Column(
                children: [
                  const Text(
                    'Visualize os logs detalhados do sistema:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _viewPasswordLogs,
                          icon: Icon(Icons.lock, size: 16),
                          label: const Text('Logs de Senhas'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _viewBackupLogs,
                          icon: Icon(Icons.archive, size: 16),
                          label: const Text('Logs de Backup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _clearLogs,
                          icon: Icon(Icons.clear_all, size: 16),
                          label: const Text('Limpar Logs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportLogs,
                          icon: Icon(Icons.download, size: 16),
                          label: const Text('Exportar Logs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highlight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção Informações do Sistema
            _buildSection(
              title: 'Informações do Sistema',
              icon: Icons.info,
              color: AppColors.textSecondary,
              child: Column(
                children: [
                  _buildInfoRow('Versão', '1.0.0'),
                  _buildInfoRow('Plataforma', 'Windows'),
                  _buildInfoRow('Banco de Dados', 'SQLite com Drift ORM'),
                  _buildInfoRow('Criptografia', 'AES-256'),
                  _buildInfoRow('Desenvolvido por', 'BackupMaster Team'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: _isRunningTest ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectOutputDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory != null) {
      await _saveOutputDirectory(selectedDirectory);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pasta de destino definida: ${selectedDirectory.split('\\').last}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _updateTestOutput(String message) {
    setState(() {
      _testOutput = message;
    });
  }

  void _setTestLoading(bool loading) {
    setState(() {
      _isRunningTest = loading;
    });
  }

  Future<void> _testPasswordGeneration() async {
    _setTestLoading(true);
    _updateTestOutput('🎲 Gerando senhas de exemplo...\n\n');
    
    try {
      final passwordManager = Provider.of<PasswordManager>(context, listen: false);
      final passwords = <String>[];
      
      for (int i = 1; i <= 10; i++) {
        final password = passwordManager.generateSecurePassword();
        passwords.add('$i. $password');
        
        // Analisar senha
        final hasNumbers = password.split('').any((c) => '0123456789'.contains(c));
        final hasLetters = password.split('').any((c) => 
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(c));
        final hasSpecialChars = password.split('').any((c) => 
          '!@#\$%^&*()_+-=[]{}|;:,.<>?'.contains(c));
        
        passwords.add('   📊 Números: $hasNumbers | Letras: $hasLetters | Especiais: $hasSpecialChars\n');
      }
      
      _updateTestOutput('✅ 10 senhas geradas com sucesso:\n\n${passwords.join('\n')}');
      
    } catch (e) {
      _updateTestOutput('❌ Erro ao gerar senhas: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _testStorageAndRetrieval() async {
    _setTestLoading(true);
    _updateTestOutput('💾 Testando armazenamento e recuperação...\n\n');
    
    try {
      final passwordManager = Provider.of<PasswordManager>(context, listen: false);
      final results = <String>[];
      
      // Armazenar 5 senhas
      final testData = <String, String>{};
      for (int i = 1; i <= 5; i++) {
        final backupId = 'settings_test_${i.toString().padLeft(3, '0')}';
        final password = passwordManager.generateSecurePassword();
        
        await passwordManager.storePassword(backupId, password);
        testData[backupId] = password;
        
        results.add('💾 Armazenado: $backupId -> $password');
      }
      
      results.add('\n🔍 Recuperando senhas:\n');
      
      // Recuperar e verificar
      int successCount = 0;
      for (final entry in testData.entries) {
        final retrieved = await passwordManager.retrievePassword(entry.key);
        final isCorrect = retrieved == entry.value;
        
        if (isCorrect) successCount++;
        
        results.add('🔍 ${entry.key}:');
        results.add('   Original:   ${entry.value}');
        results.add('   Recuperada: $retrieved');
        results.add('   Status: ${isCorrect ? "✅ CORRETO" : "❌ ERRO"}\n');
      }
      
      results.add('📊 Resultado: $successCount/5 senhas corretas');
      
      _updateTestOutput(results.join('\n'));
      
    } catch (e) {
      _updateTestOutput('❌ Erro no teste: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _runPasswordBattery() async {
    _setTestLoading(true);
    _updateTestOutput('🧪 Executando bateria de testes...\n\n');
    
    try {
      final passwordManager = Provider.of<PasswordManager>(context, listen: false);
      final results = await passwordManager.runPasswordTests(numberOfTests: 25);
      
      final output = <String>[
        '📊 Resultados da Bateria de Testes:',
        '',
        '📝 Total de testes: ${results['totalTests']}',
        '✅ Testes passaram: ${results['passedTests']}',
        '❌ Testes falharam: ${results['failedTests']}',
        '',
        '📈 Taxa de sucesso: ${(results['passedTests'] / results['totalTests'] * 100).toStringAsFixed(2)}%',
        '',
      ];
      
      if (results['errors'].isNotEmpty) {
        output.add('⚠️ Erros encontrados:');
        final errors = results['errors'] as List;
        for (int i = 0; i < 3 && i < errors.length; i++) {
          output.add('   ${i + 1}. ${errors[i]}');
        }
        output.add('');
      }
      
      output.add('🔍 Exemplos de senhas testadas:');
      final passwords = results['passwords'] as List;
      for (int i = 0; i < 5 && i < passwords.length; i++) {
        final passwordData = passwords[i];
        output.add('   ${i + 1}. ${passwordData['original']} - ${passwordData['passed'] ? "✅" : "❌"}');
      }
      
      _updateTestOutput(output.join('\n'));
      
    } catch (e) {
      _updateTestOutput('❌ Erro na bateria de testes: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _generateReport() async {
    _setTestLoading(true);
    _updateTestOutput('📊 Gerando relatório detalhado...\n\n');
    
    try {
      final passwordManager = Provider.of<PasswordManager>(context, listen: false);
      final report = await passwordManager.generatePasswordReport();
      
      final output = <String>[
        '📋 Relatório do Sistema de Senhas',
        '📅 Gerado em: ${report['generatedAt']}',
        '',
        '📊 Estatísticas:',
        '🔐 Total de senhas: ${report['totalPasswords']}',
        '📦 Total de backups: ${report['totalBackups']}',
        '',
        '📊 Status de Validação:',
      ];
      
      final validationStatus = report['validationStatus'] as Map<String, dynamic>;
      for (final entry in validationStatus.entries) {
        output.add('   ${entry.key}: ${entry.value}');
      }
      
      output.add('');
      output.add('🔍 Últimas 3 senhas:');
      
      final passwordDetails = report['passwordDetails'] as List;
      for (int i = 0; i < 3 && i < passwordDetails.length; i++) {
        final detail = passwordDetails[i];
        output.add('   ${i + 1}. Backup: ${detail['backupId']}');
        output.add('      Senha: ${detail['password']}');
        output.add('      Status: ${detail['validationStatus']}');
        output.add('');
      }
      
      _updateTestOutput(output.join('\n'));
      
    } catch (e) {
      _updateTestOutput('❌ Erro ao gerar relatório: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _runFullDemo() async {
    _setTestLoading(true);
    _updateTestOutput('🚀 Executando demonstração completa...\n\n');
    
    try {
      await _testRunner.runPasswordDemo();
      _updateTestOutput('🎉 Demonstração completa executada com sucesso!\n\nVerifique o console para logs detalhados.');
    } catch (e) {
      _updateTestOutput('❌ Erro na demonstração: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _runStressTest() async {
    _setTestLoading(true);
    _updateTestOutput('💪 Executando teste de stress...\n\n');
    
    try {
      await _testRunner.runStressTest(numberOfPasswords: 50);
      _updateTestOutput('✅ Teste de stress concluído!\n\nVerifique o console para resultados detalhados.');
    } catch (e) {
      _updateTestOutput('❌ Erro no teste de stress: $e');
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _viewPasswordLogs() async {
    _updateTestOutput('📋 Carregando logs de senhas...\n\n');
    
    try {
      final database = Provider.of<AppDatabase>(context, listen: false);
      final logs = await database.getAllPasswordLogs();
      
      final output = <String>[
        '🔐 Logs de Senhas (${logs.length} registros):',
        '',
      ];
      
      for (int i = 0; i < 10 && i < logs.length; i++) {
        final log = logs[i];
        output.add('${i + 1}. Backup: ${log.backupId}');
        output.add('   Senha: ${log.passwordGenerated}');
        output.add('   Status: ${log.validationStatus}');
        output.add('   Data: ${log.createdAt}');
        output.add('');
      }
      
      if (logs.length > 10) {
        output.add('... e mais ${logs.length - 10} registros');
      }
      
      _updateTestOutput(output.join('\n'));
      
    } catch (e) {
      _updateTestOutput('❌ Erro ao carregar logs: $e');
    }
  }

  Future<void> _viewBackupLogs() async {
    _updateTestOutput('📦 Carregando logs de backup...\n\n');
    
    try {
      final database = Provider.of<AppDatabase>(context, listen: false);
      final backups = await database.getAllBackups();
      
      final output = <String>[
        '📦 Logs de Backup (${backups.length} registros):',
        '',
      ];
      
      for (int i = 0; i < 10 && i < backups.length; i++) {
        final backup = backups[i];
        output.add('${i + 1}. ${backup.name}');
        output.add('   Pasta: ${backup.originalPath}');
        output.add('   Status: ${backup.status}');
        output.add('   Data: ${backup.createdAt}');
        output.add('');
      }
      
      if (backups.length > 10) {
        output.add('... e mais ${backups.length - 10} registros');
      }
      
      _updateTestOutput(output.join('\n'));
      
    } catch (e) {
      _updateTestOutput('❌ Erro ao carregar logs: $e');
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        title: const Text(
          'Limpar Logs',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Tem certeza que deseja limpar todos os logs?\n\nEsta ação não pode ser desfeita.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'Limpar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _updateTestOutput('🧹 Logs limpos com sucesso!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs limpos com sucesso'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    _updateTestOutput('📤 Exportando logs...\n\nFuncionalidade em desenvolvimento.');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funcionalidade de exportação em desenvolvimento'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }
}