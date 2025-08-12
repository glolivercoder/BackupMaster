import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../services/database.dart';
import '../services/password_manager.dart';
import '../services/backup_service.dart';
import '../utils/app_theme.dart';

class SearchViewModel extends ChangeNotifier {
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
  final PasswordManager _passwordManager;
  final BackupService _backupService;

  // Estado da busca
  List<Backup> _searchResults = [];
  List<String> _suggestions = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String _currentQuery = '';
  String _lastCopiedPassword = '';
  Map<String, bool> _activeFilters = {};

  // Getters
  List<Backup> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  bool get isSearching => _isSearching;
  String get currentQuery => _currentQuery;

  SearchViewModel(this._database, this._passwordManager)
      : _backupService = BackupService(_database, _passwordManager) {
    _logger.i('🔍 SearchViewModel inicializado');
    _loadSuggestions();
    _loadRecentSearches();
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
      List<Backup> results = await _backupService.searchBackups(query);
      
      // Aplicar filtros ativos
      results = _applyActiveFilters(results);
      
      _searchResults = results;
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

  /// Abre o arquivo ZIP e mostra a senha em um diálogo
  Future<void> openBackupFileWithPasswordDialog(BuildContext context, String backupId) async {
    try {
      final password = await _passwordManager.retrievePassword(backupId);
      
      // Mostrar diálogo com a senha antes de abrir
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardColor,
          title: const Text(
            'Abrir Backup ZIP',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Senha do arquivo ZIP:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        password,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      onPressed: () async {
                        await copyPasswordToClipboard(backupId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Senha copiada!'),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Copiar senha',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A senha foi copiada para a área de transferência. Deseja abrir o arquivo ZIP?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
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
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Abrir ZIP',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await openBackupFile(backupId);
      }
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir backup com diálogo: $e');
      rethrow;
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
      await _backupService.openDirectory(originalPath);
      
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

  /// Carrega buscas recentes do armazenamento local
  Future<void> _loadRecentSearches() async {
    try {
      // Por enquanto, usar uma lista em memória
      // Em uma implementação completa, isso seria carregado do SharedPreferences
      _recentSearches = [];
      _logger.d('📋 Buscas recentes carregadas');
    } catch (e) {
      _logger.e('❌ Erro ao carregar buscas recentes: $e');
    }
  }

  /// Obtém lista de buscas recentes
  List<String> getRecentSearches() {
    return _recentSearches.take(5).toList();
  }

  /// Adiciona uma busca ao histórico
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    
    // Remove se já existe
    _recentSearches.remove(query);
    // Adiciona no início
    _recentSearches.insert(0, query);
    // Mantém apenas os últimos 10
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.take(10).toList();
    }
    
    _logger.d('📝 Adicionado ao histórico: "$query"');
    // Em uma implementação completa, salvaria no SharedPreferences aqui
  }

  /// Limpa o histórico de buscas
  void clearSearchHistory() {
    _recentSearches.clear();
    _logger.d('🧹 Histórico de buscas limpo');
    notifyListeners();
  }

  /// Verifica se um filtro está ativo
  bool isFilterActive(String filterKey) {
    return _activeFilters[filterKey] ?? false;
  }

  /// Alterna filtro de data
  void toggleDateFilter(String period) {
    // Desativa outros filtros de data
    _activeFilters.removeWhere((key, value) => ['today', 'week', 'month'].contains(key));
    
    if (!isFilterActive(period)) {
      _activeFilters[period] = true;
    }
    
    _logger.d('📅 Filtro de data alterado: $period');
    
    // Reaplica a busca atual
    if (_currentQuery.isNotEmpty) {
      searchBackups(_currentQuery);
    } else {
      notifyListeners();
    }
  }

  /// Alterna filtro de tamanho
  void toggleSizeFilter(String sizeType) {
    if (isFilterActive(sizeType)) {
      _activeFilters.remove(sizeType);
    } else {
      _activeFilters[sizeType] = true;
    }
    
    _logger.d('📏 Filtro de tamanho alterado: $sizeType');
    
    // Reaplica a busca atual
    if (_currentQuery.isNotEmpty) {
      searchBackups(_currentQuery);
    } else {
      notifyListeners();
    }
  }

  /// Aplica filtros ativos aos resultados
  List<Backup> _applyActiveFilters(List<Backup> results) {
    List<Backup> filteredResults = List.from(results);
    
    // Filtros de data
    if (isFilterActive('today')) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      filteredResults = filteredResults.where((backup) => 
        backup.createdAt.isAfter(startOfDay)).toList();
    } else if (isFilterActive('week')) {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      filteredResults = filteredResults.where((backup) => 
        backup.createdAt.isAfter(weekAgo)).toList();
    } else if (isFilterActive('month')) {
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      filteredResults = filteredResults.where((backup) => 
        backup.createdAt.isAfter(monthAgo)).toList();
    }
    
    // Filtros de tamanho
    if (isFilterActive('large')) {
      const largeSizeThreshold = 100 * 1024 * 1024; // 100MB
      filteredResults = filteredResults.where((backup) => 
        (backup.fileSize ?? 0) > largeSizeThreshold).toList();
    }
    
    return filteredResults;
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