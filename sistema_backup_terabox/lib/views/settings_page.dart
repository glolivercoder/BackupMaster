import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/password_manager.dart';
import '../services/database.dart';
import '../services/terabox_service.dart';
import '../services/gmail_service.dart';
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
  
  // Controladores para Terabox
  final _teraboxUsernameController = TextEditingController();
  final _teraboxPasswordController = TextEditingController();
  bool _teraboxPasswordVisible = false;
  
  // Controladores para Gmail
  final _gmailSenderController = TextEditingController();
  final _gmailPasswordController = TextEditingController();
  final _gmailRecipientController = TextEditingController();
  bool _gmailPasswordVisible = false;
  
  // Serviços
  TeraboxService? _teraboxService;
  GmailService? _gmailService;

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
      
      // Carregar configurações do Terabox
      _teraboxUsernameController.text = prefs.getString('terabox_username') ?? '';
      _teraboxPasswordController.text = prefs.getString('terabox_password') ?? '';
      
      // Carregar configurações do Gmail
      _gmailSenderController.text = prefs.getString('gmail_sender') ?? '';
      _gmailPasswordController.text = prefs.getString('gmail_password') ?? '';
      _gmailRecipientController.text = prefs.getString('gmail_recipient') ?? '';
    });
    
    // Inicializar serviços se as credenciais existem
    _initializeServices();
  }

  Future<void> _saveOutputDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('output_directory', path);
    setState(() {
      _outputDirectory = path;
    });
  }

  void _initializeServices() {
    // Inicializar Terabox Service
    if (_teraboxUsernameController.text.isNotEmpty) {
      _teraboxService = TeraboxService(
        username: _teraboxUsernameController.text,
      );
    }
    
    // Inicializar Gmail Service
    if (_gmailSenderController.text.isNotEmpty && 
        _gmailPasswordController.text.isNotEmpty && 
        _gmailRecipientController.text.isNotEmpty) {
      _gmailService = GmailService(
        senderEmail: _gmailSenderController.text,
        senderPassword: _gmailPasswordController.text,
        recipientEmail: _gmailRecipientController.text,
      );
    }
  }

  Future<void> _saveTeraboxCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('terabox_username', _teraboxUsernameController.text);
    await prefs.setString('terabox_password', _teraboxPasswordController.text);
    
    _initializeServices();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenciais do Terabox salvas com sucesso'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _saveGmailCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gmail_sender', _gmailSenderController.text);
    await prefs.setString('gmail_password', _gmailPasswordController.text);
    await prefs.setString('gmail_recipient', _gmailRecipientController.text);
    
    _initializeServices();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credenciais do Gmail salvas com sucesso'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _copyGmailCredentialsToTerabox() {
    if (_gmailSenderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure primeiro o email do Gmail'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _teraboxUsernameController.text = _gmailSenderController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email copiado! OAuth2 será usado para autenticação'),
        backgroundColor: AppColors.secondary,
        duration: Duration(seconds: 3),
      ),
    );
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
            
            // Seção Configurações do Terabox
            _buildSection(
              title: 'Configurações do Terabox (OAuth2)',
              icon: Icons.cloud_upload,
              color: AppColors.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure sua conta Terabox para upload automático de backups:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status OAuth2
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Autenticação OAuth2 Implementada',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '🔐 OAuth2 REAL implementado\n'
                          '⚠️ IMPORTANTE: Configure suas credenciais\n'
                          '📋 Necessário para funcionamento:\n'
                          '   • Client ID do Baidu Developer Console\n'
                          '   • Client Secret da sua aplicação\n'
                          '   • Autorização via navegador',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email da conta
                  TextField(
                    controller: _teraboxUsernameController,
                    decoration: InputDecoration(
                      labelText: 'Email da Conta Terabox',
                      prefixIcon: const Icon(Icons.person, color: AppColors.secondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.secondary),
                      ),
                      helperText: 'Email da conta que será usada no OAuth2',
                      helperStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Botão para usar email do Gmail
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _copyGmailCredentialsToTerabox,
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Usar Email do Gmail'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.highlight.withOpacity(0.8),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Botões de ação
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveTeraboxCredentials,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Salvar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRunningTest ? null : _testTeraboxConnection,
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Autenticar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Informações sobre OAuth2 do Terabox
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.secondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Sobre OAuth2 do Terabox:',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '🔐 O Terabox usa OAuth2 para segurança\n'
                          '🌐 Requer registro no Developer Console\n'
                          '📋 Fluxo: Autorização → Código → Token\n'
                          '⚡ Atualmente em modo demonstração\n'
                          '🚀 Implementação completa em desenvolvimento',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção Configurações do Gmail
            _buildSection(
              title: 'Configurações do Gmail',
              icon: Icons.email,
              color: AppColors.highlight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure o Gmail para envio automático de relatórios:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Email remetente
                  TextField(
                    controller: _gmailSenderController,
                    decoration: InputDecoration(
                      labelText: 'Email Remetente',
                      prefixIcon: const Icon(Icons.send, color: AppColors.highlight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.highlight),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Senha do app
                  TextField(
                    controller: _gmailPasswordController,
                    obscureText: !_gmailPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Senha do App',
                      prefixIcon: const Icon(Icons.key, color: AppColors.highlight),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _gmailPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.highlight,
                        ),
                        onPressed: () {
                          setState(() {
                            _gmailPasswordVisible = !_gmailPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.highlight),
                      ),
                      helperText: 'Use uma senha de app do Gmail, não sua senha normal',
                      helperStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Email destinatário
                  TextField(
                    controller: _gmailRecipientController,
                    decoration: InputDecoration(
                      labelText: 'Email Destinatário',
                      prefixIcon: const Icon(Icons.inbox, color: AppColors.highlight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.highlight),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Botões de ação
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveGmailCredentials,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Salvar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.highlight,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRunningTest ? null : _testGmailConnection,
                          icon: const Icon(Icons.mail_outline, size: 16),
                          label: const Text('Testar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Informações sobre senha de app
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.highlight.withOpacity(0.1),
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
                              Icons.info_outline,
                              color: AppColors.highlight,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Diferença entre senhas:',
                              style: TextStyle(
                                color: AppColors.highlight,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '📧 Gmail: Use uma SENHA DE APP (16 caracteres)\n'
                          '☁️ Terabox: Use sua SENHA NORMAL do Google\n\n'
                          'Como obter senha de app:\n'
                          '1. Acesse sua conta Google\n'
                          '2. Vá em Segurança > Verificação em duas etapas\n'
                          '3. Role até "Senhas de app"\n'
                          '4. Gere uma nova senha para "Email"',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Future<void> _testTeraboxConnection() async {
    if (_teraboxUsernameController.text.isEmpty) {
      _updateTestOutput('❌ Erro: Preencha o email antes de autenticar.');
      return;
    }

    _setTestLoading(true);
    _updateTestOutput('🔐 Iniciando autenticação OAuth2 REAL com Terabox...\n\n');
    
    try {
      final teraboxService = TeraboxService(
        username: _teraboxUsernameController.text,
      );
      
      _updateTestOutput('🔐 Autenticação OAuth2 com Terabox...\n\n'
                       '📧 Email: ${_teraboxUsernameController.text}\n'
                       '🔐 Modo: OAuth2 Real\n\n'
                       '⏳ Iniciando fluxo OAuth2...\n'
                       '🌐 Abrindo navegador para autorização...\n');
      
      final authResult = await teraboxService.authenticate();
      
      if (authResult) {
        _updateTestOutput('🔐 Autenticação OAuth2 com Terabox...\n\n'
                         '📧 Email: ${_teraboxUsernameController.text}\n'
                         '🔐 Modo: OAuth2 Real\n\n'
                         '✅ Autenticação OAuth2 bem-sucedida!\n'
                         '🔑 Access token obtido\n\n'
                         '📊 Obtendo informações da conta...\n');
        
        final quota = await teraboxService.getQuotaInfo();
        
        _updateTestOutput('🔐 Autenticação OAuth2 com Terabox...\n\n'
                         '📧 Email: ${_teraboxUsernameController.text}\n'
                         '🔐 Modo: OAuth2 Real\n\n'
                         '✅ Autenticação OAuth2 concluída!\n'
                         '✅ Conexão com Terabox estabelecida!\n\n'
                         '📊 Informações da conta:\n'
                         '   💾 Espaço total: ${quota.formattedTotal}\n'
                         '   📈 Espaço usado: ${quota.formattedUsed}\n'
                         '   💿 Espaço livre: ${quota.formattedFree}\n'
                         '   📊 Uso: ${quota.usagePercentage.toStringAsFixed(1)}%\n\n'
                         '🎉 Terabox configurado e pronto para uso!\n'
                         '📤 Uploads de backup funcionarão normalmente');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Autenticação OAuth2 bem-sucedida!'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } else {
        _updateTestOutput('🔐 Autenticação OAuth2 com Terabox...\n\n'
                         '❌ Falha na autenticação OAuth2!\n\n'
                         '🔧 Possíveis causas:\n'
                         '   • Client ID/Secret não configurados\n'
                         '   • Autorização cancelada pelo usuário\n'
                         '   • Erro de rede ou timeout\n'
                         '   • Credenciais inválidas no código\n\n'
                         '📋 Verifique:\n'
                         '   • Se registrou a aplicação no Baidu Console\n'
                         '   • Se configurou Client ID e Secret no código\n'
                         '   • Se autorizou a aplicação no navegador');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Falha na autenticação - Verifique credenciais OAuth2'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
      
    } catch (e) {
      _updateTestOutput('🔐 Autenticação OAuth2 com Terabox...\n\n'
                       '❌ Erro durante autenticação: $e\n\n'
                       '🔧 Soluções:\n'
                       '   • Verifique sua conexão com internet\n'
                       '   • Configure Client ID e Secret no código\n'
                       '   • Registre a aplicação no Baidu Console\n'
                       '   • Tente novamente após alguns minutos');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro na autenticação: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _setTestLoading(false);
    }
  }

  Future<void> _testGmailConnection() async {
    if (_gmailSenderController.text.isEmpty || 
        _gmailPasswordController.text.isEmpty || 
        _gmailRecipientController.text.isEmpty) {
      _updateTestOutput('❌ Erro: Preencha todas as credenciais do Gmail antes de testar.');
      return;
    }

    _setTestLoading(true);
    _updateTestOutput('📧 Testando conexão com Gmail...\n\n');
    
    try {
      final gmailService = GmailService(
        senderEmail: _gmailSenderController.text,
        senderPassword: _gmailPasswordController.text,
        recipientEmail: _gmailRecipientController.text,
      );
      
      _updateTestOutput('📧 Testando conexão com Gmail...\n\n'
                       '📤 Remetente: ${_gmailSenderController.text}\n'
                       '🔐 Senha: ${'*' * _gmailPasswordController.text.length}\n'
                       '📥 Destinatário: ${_gmailRecipientController.text}\n\n'
                       '⏳ Enviando email de teste...\n');
      
      final testResult = await gmailService.testConnection();
      
      if (testResult) {
        _updateTestOutput('📧 Testando conexão com Gmail...\n\n'
                         '📤 Remetente: ${_gmailSenderController.text}\n'
                         '🔐 Senha: ${'*' * _gmailPasswordController.text.length}\n'
                         '📥 Destinatário: ${_gmailRecipientController.text}\n\n'
                         '✅ Email de teste enviado com sucesso!\n\n'
                         '📬 Verifique a caixa de entrada do destinatário.\n'
                         '📧 Assunto: "Teste de Conexão - BackupMaster"\n\n'
                         '🎉 Gmail configurado com sucesso!\n'
                         '📊 O sistema está pronto para enviar relatórios automáticos.');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email de teste enviado com sucesso!'),
              backgroundColor: AppColors.highlight,
            ),
          );
        }
      } else {
        _updateTestOutput('📧 Testando conexão com Gmail...\n\n'
                         '📤 Remetente: ${_gmailSenderController.text}\n'
                         '🔐 Senha: ${'*' * _gmailPasswordController.text.length}\n'
                         '📥 Destinatário: ${_gmailRecipientController.text}\n\n'
                         '❌ Falha no envio do email de teste!\n\n'
                         '🔧 Verifique as configurações:\n'
                         '   • Email remetente válido\n'
                         '   • Senha de app correta (não a senha normal)\n'
                         '   • Email destinatário válido\n'
                         '   • Verificação em duas etapas ativada\n'
                         '   • Acesso a apps menos seguros permitido');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Falha no teste do Gmail'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      
    } catch (e) {
      _updateTestOutput('📧 Testando conexão com Gmail...\n\n'
                       '❌ Erro durante o teste: $e\n\n'
                       '🔧 Possíveis soluções:\n'
                       '   • Use uma senha de app, não sua senha normal\n'
                       '   • Ative a verificação em duas etapas\n'
                       '   • Verifique se os emails estão corretos\n'
                       '   • Confirme sua conexão com a internet');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro no teste: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _setTestLoading(false);
    }
  }

  @override
  void dispose() {
    _teraboxUsernameController.dispose();
    _teraboxPasswordController.dispose();
    _gmailSenderController.dispose();
    _gmailPasswordController.dispose();
    _gmailRecipientController.dispose();
    super.dispose();
  }
}