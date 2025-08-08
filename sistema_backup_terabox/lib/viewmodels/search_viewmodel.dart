import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../services/database.dart';
import '../services/password_manager.dart';
import '../services/backup_service.dart';

class SearchViewModel extends ChangeNotifier {
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
  final BackupService _backupService;

  // Estado da busca
  List<Backup> _searchResults = [];
  List<String> _suggestions = [];
  bool _isSearching = false;
  String _currentQuery = '';
  String _lastCopiedPassword = '';

  // Getters
  List<Backup> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  bool get isSearching => _isSearching;
  String get currentQuery => _currentQuery;

  SearchViewModel(this._database, this._passwordManager)
      : _backupService = BackupService(_database, _passwordManager) {
    _logger.i('🔍 SearchViewModel inicializado');
    _loadSuggestions();
  }

  /// Carrega sugestões iniciais baseadas nos backups existentes
  Future<void> _loadSuggestions() async {
    try {
      final backups = await _backupService.getAllBackups();
      _suggestions = backups
          .map((backup) => backup.name)
          .toSet() // Remove duplicatas
          .toList();
      
      _logger.d('💡 ${_suggestions.length} sugestões carregadas');
      notifyListeners();
      
    } catch (e) {
      _logger.e('❌ Erro ao carregar sugestões: $e');
    }
  }

  /// Executa busca em tempo real
  Future<void> searchBackups(String query) async {
    _currentQuery = query;
    
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _logger.d('🔍 Buscando: "$query"');
    _isSearching = true;
    notifyListeners();

    try {
      // Buscar no banco de dados
      _searchResults = await _backupService.searchBackups(query);
      
      _logger.d('📊 ${_searchResults.length} resultados encontrados');
      
    } catch (e) {
      _logger.e('❌ Erro na busca: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Obtém sugestões filtradas baseadas na query atual
  List<String> getFilteredSuggestions(String query) {
    if (query.isEmpty) return [];
    
    return _suggestions
        .where((suggestion) => 
            suggestion.toLowerCase().contains(query.toLowerCase()))
        .take(5) // Limitar a 5 sugestões
        .toList();
  }

  /// Copia a senha de um backup para o clipboard
  Future<void> copyPasswordToClipboard(String backupId) async {
    _logger.i('📋 Copiando senha para clipboard: $backupId');
    
    try {
      final password = await _passwordManager.retrievePassword(backupId);
      
      await Clipboard.setData(ClipboardData(text: password));
      _lastCopiedPassword = password;
      
      _logger.i('✅ Senha copiada para clipboard');
      
      // Limpar clipboard após 30 segundos por segurança
      Future.delayed(const Duration(seconds: 30), () {
        _clearClipboardIfNeeded();
      });
      
    } catch (e) {
      _logger.e('❌ Erro ao copiar senha: $e');
      rethrow;
    }
  }

  /// Limpa o clipboard se ainda contém a senha copiada
  Future<void> _clearClipboardIfNeeded() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text == _lastCopiedPassword) {
        await Clipboard.setData(const ClipboardData(text: ''));
        _logger.d('🧹 Clipboard limpo por segurança');
      }
    } catch (e) {
      _logger.w('⚠️ Erro ao limpar clipboard: $e');
    }
  }

  /// Obtém informações detalhadas de um backup para exibição
  Future<BackupSearchResult> getBackupDetails(Backup backup) async {
    try {
      final password = await _passwordManager.retrievePassword(backup.id);
      
      return BackupSearchResult(
        backup: backup,
        password: password,
        formattedDate: _formatDate(backup.createdAt),
        formattedSize: _formatFileSize(backup.fileSize ?? 0),
      );
      
    } catch (e) {
      _logger.e('❌ Erro ao obter detalhes do backup: $e');
      return BackupSearchResult(
        backup: backup,
        password: 'Erro ao recuperar senha',
        formattedDate: _formatDate(backup.createdAt),
        formattedSize: _formatFileSize(backup.fileSize ?? 0),
      );
    }
  }

  /// Formata a data para exibição em formato brasileiro
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year} '
           '${date.hour.toString().padLeft(2, '0')}:'
           '${date.minute.toString().padLeft(2, '0')}:'
           '${date.second.toString().padLeft(2, '0')}';
  }

  /// Formata o tamanho do arquivo para exibição
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Abre o diretório original do backup
  Future<void> openOriginalDirectory(String originalPath) async {
    _logger.i('📁 Abrindo diretório original: $originalPath');
    
    try {
      // TODO: Implementar abertura do diretório no Windows
      // Process.run('explorer', [originalPath]);
      _logger.i('🔗 Diretório: $originalPath');
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir diretório: $e');
      rethrow;
    }
  }

  /// Abre o arquivo ZIP com senha
  Future<void> openBackupFile(String backupId) async {
    _logger.i('📦 Abrindo arquivo de backup: $backupId');
    
    try {
      await _backupService.openZipWithPassword(backupId);
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir backup: $e');
      rethrow;
    }
  }

  /// Limpa os resultados da busca
  void clearSearch() {
    _currentQuery = '';
    _searchResults = [];
    notifyListeners();
    _logger.d('🧹 Busca limpa');
  }

  /// Atualiza as sugestões quando novos backups são criados
  void refreshSuggestions() {
    _loadSuggestions();
  }

  @override
  void dispose() {
    _logger.i('🧹 SearchViewModel disposed');
    super.dispose();
  }
}

/// Classe para encapsular os resultados da busca com informações formatadas
class BackupSearchResult {
  final Backup backup;
  final String password;
  final String formattedDate;
  final String formattedSize;

  BackupSearchResult({
    required this.backup,
    required this.password,
    required this.formattedDate,
    required this.formattedSize,
  });
}