import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:drift/drift.dart';
import '../services/database.dart';
import '../services/password_manager.dart';
import '../services/backup_service.dart';

class BackupViewModel extends ChangeNotifier {
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
  late final BackupService _backupService;

  // Estado da UI
  bool _isLoading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _selectedDirectory;
  String? _currentBackupId;

  // Getters
  bool get isLoading => _isLoading;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get selectedDirectory => _selectedDirectory;
  String? get currentBackupId => _currentBackupId;

  BackupViewModel(this._database, this._passwordManager) {
    _backupService = BackupService(_database, _passwordManager);
    _logger.i('🔧 BackupViewModel inicializado');
  }

  /// Seleciona um diretório para backup
  Future<void> selectDirectory() async {
    _logger.i('📁 Iniciando seleção de diretório...');
    
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (selectedDirectory != null) {
        _selectedDirectory = selectedDirectory;
        _statusMessage = 'Diretório selecionado: ${_getDirectoryName(selectedDirectory)}';
        _logger.i('✅ Diretório selecionado: $selectedDirectory');
        notifyListeners();
      } else {
        _logger.i('❌ Seleção de diretório cancelada pelo usuário');
      }
    } catch (e) {
      _logger.e('❌ Erro ao selecionar diretório: $e');
      _statusMessage = 'Erro ao selecionar diretório: $e';
      notifyListeners();
    }
  }

  /// Cria um backup do diretório selecionado
  Future<void> createBackup() async {
    if (_selectedDirectory == null) {
      _statusMessage = 'Nenhum diretório selecionado';
      notifyListeners();
      return;
    }

    _logger.i('🚀 Iniciando criação de backup para: $_selectedDirectory');
    
    _isLoading = true;
    _progress = 0.0;
    _statusMessage = 'Iniciando backup...';
    notifyListeners();

    try {
      // Gerar ID único para o backup
      _currentBackupId = 'backup_${DateTime.now().millisecondsSinceEpoch}';
      
      // Etapa 1: Gerar senha
      _updateProgress(0.1, 'Gerando senha segura...');
      final password = _passwordManager.generateSecurePassword();
      await _passwordManager.storePassword(_currentBackupId!, password);
      
      // Etapa 2: Criar arquivo ZIP
      _updateProgress(0.3, 'Criando arquivo ZIP...');
      final zipPath = await _backupService.createZipWithPassword(
        _selectedDirectory!,
        _currentBackupId!,
        password,
        onProgress: (progress) {
          _updateProgress(0.3 + (progress * 0.4), 'Compactando arquivos... ${(progress * 100).toInt()}%');
        },
      );
      
      // Etapa 3: Calcular checksum
      _updateProgress(0.7, 'Calculando checksum...');
      final checksum = await _backupService.calculateChecksum(zipPath);
      
      // Etapa 4: Salvar no banco de dados
      _updateProgress(0.8, 'Salvando informações...');
      await _database.insertBackup(BackupsCompanion.insert(
        id: _currentBackupId!,
        name: _backupService.generateBackupName(_getDirectoryName(_selectedDirectory!)),
        originalPath: _selectedDirectory!,
        zipPath: Value(zipPath),
        passwordHash: _passwordManager.generatePasswordHash(password),
        fileSize: Value(await _backupService.getFileSize(zipPath)),
        checksum: Value(checksum),
      ));
      
      // Etapa 5: Upload para Terabox (simulado por enquanto)
      _updateProgress(0.9, 'Enviando para Terabox...');
      await Future.delayed(const Duration(seconds: 2)); // Simular upload
      
      // Etapa 6: Enviar email (simulado por enquanto)
      _updateProgress(0.95, 'Enviando notificação por email...');
      await Future.delayed(const Duration(seconds: 1)); // Simular email
      
      // Finalizar
      _updateProgress(1.0, 'Backup concluído com sucesso!');
      
      _logger.i('✅ Backup criado com sucesso!');
      _logger.i('   📁 Diretório: $_selectedDirectory');
      _logger.i('   📦 Arquivo ZIP: $zipPath');
      _logger.i('   🔐 Senha: $password');
      _logger.i('   🆔 ID: $_currentBackupId');
      
      // Aguardar um pouco para mostrar a mensagem de sucesso
      await Future.delayed(const Duration(seconds: 2));
      
      // Reset do estado
      _resetState();
      
    } catch (e) {
      _logger.e('❌ Erro durante criação do backup: $e');
      _statusMessage = 'Erro ao criar backup: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atualiza o progresso e status
  void _updateProgress(double progress, String message) {
    _progress = progress;
    _statusMessage = message;
    notifyListeners();
    _logger.d('📊 Progresso: ${(progress * 100).toInt()}% - $message');
  }

  /// Reseta o estado após conclusão
  void _resetState() {
    _isLoading = false;
    _progress = 0.0;
    _statusMessage = '';
    _selectedDirectory = null;
    _currentBackupId = null;
    notifyListeners();
  }

  /// Extrai o nome do diretório do caminho completo
  String _getDirectoryName(String path) {
    return path.split('\\').last;
  }

  /// Cancela o backup em andamento
  void cancelBackup() {
    if (_isLoading) {
      _logger.w('⚠️ Backup cancelado pelo usuário');
      _resetState();
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 BackupViewModel disposed');
    super.dispose();
  }
}