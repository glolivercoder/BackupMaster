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

    _logger.i('🚀 Iniciando criação de backup completo para: $_selectedDirectory');
    
    _isLoading = true;
    _progress = 0.0;
    _statusMessage = 'Iniciando backup...';
    notifyListeners();

    try {
      // Usar o novo método createCompleteBackup que integra Terabox e Gmail
      _currentBackupId = await _backupService.createCompleteBackup(
        _selectedDirectory!,
        onStatusUpdate: (status) {
          _statusMessage = status;
          notifyListeners();
          _logger.d('📊 Status: $status');
        },
        onProgress: (progress) {
          _progress = progress;
          notifyListeners();
          _logger.d('📊 Progresso: ${(progress * 100).toInt()}%');
        },
      );
      
      _logger.i('✅ Backup completo criado com sucesso!');
      _logger.i('   📁 Diretório: $_selectedDirectory');
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

  /// Verifica se os serviços estão configurados
  bool get isTeraboxConfigured => _backupService.isTeraboxConfigured;
  bool get isGmailConfigured => _backupService.isGmailConfigured;

  /// Envia relatório de backups por email
  Future<bool> sendBackupReport({String? customMessage}) async {
    if (!isGmailConfigured) {
      _logger.w('⚠️ Gmail não configurado');
      return false;
    }

    _logger.i('📧 Enviando relatório de backups...');
    
    try {
      final success = await _backupService.sendBackupReport(
        customMessage: customMessage,
        lastDays: 30, // Últimos 30 dias
      );
      
      if (success) {
        _logger.i('✅ Relatório enviado com sucesso');
      } else {
        _logger.e('❌ Falha ao enviar relatório');
      }
      
      return success;
      
    } catch (e) {
      _logger.e('❌ Erro ao enviar relatório: $e');
      return false;
    }
  }

  /// Obtém informações de quota do Terabox
  Future<String?> getTeraboxQuotaInfo() async {
    if (!isTeraboxConfigured) {
      return null;
    }

    try {
      final quota = await _backupService.getTeraboxQuota();
      if (quota != null) {
        return '${quota.formattedUsed} / ${quota.formattedTotal} (${quota.usagePercentage.toStringAsFixed(1)}%)';
      }
    } catch (e) {
      _logger.e('❌ Erro ao obter quota: $e');
    }
    
    return null;
  }

  @override
  void dispose() {
    _logger.i('🧹 BackupViewModel disposed');
    super.dispose();
  }
}