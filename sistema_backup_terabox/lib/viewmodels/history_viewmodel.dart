import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../services/database.dart';
import '../services/password_manager.dart';
import '../services/backup_service.dart';
import '../utils/app_theme.dart';

enum SortOption {
  dateDesc('Data (Mais recente)'),
  dateAsc('Data (Mais antigo)'),
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  sizeDesc('Tamanho (Maior)'),
  sizeAsc('Tamanho (Menor)');

  const SortOption(this.displayName);
  final String displayName;
}

enum FilterOption {
  all('Todos'),
  completed('Concluídos'),
  failed('Falhados'),
  today('Hoje'),
  thisWeek('Esta semana'),
  thisMonth('Este mês');

  const FilterOption(this.displayName);
  final String displayName;
}

class HistoryViewModel extends ChangeNotifier {
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

  // Estado do histórico
  List<Backup> _allBackups = [];
  List<Backup> _filteredBackups = [];
  bool _isLoading = false;
  SortOption _currentSort = SortOption.dateDesc;
  FilterOption _currentFilter = FilterOption.all;
  String _searchQuery = '';

  // Getters
  List<Backup> get filteredBackups => _filteredBackups;
  bool get isLoading => _isLoading;
  SortOption get currentSort => _currentSort;
  FilterOption get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  int get totalBackups => _allBackups.length;
  int get completedBackups => _allBackups.where((b) => b.status == 'completed').length;
  int get failedBackups => _allBackups.where((b) => b.status == 'failed').length;

  HistoryViewModel(this._database, this._passwordManager)
      : _backupService = BackupService(_database, _passwordManager) {
    _logger.i('📚 HistoryViewModel inicializado');
    loadHistory();
  }

  /// Carrega o histórico completo de backups
  Future<void> loadHistory() async {
    _logger.i('📋 Carregando histórico de backups...');
    
    _isLoading = true;
    notifyListeners();

    try {
      _allBackups = await _backupService.getAllBackups();
      _applyFiltersAndSort();
      
      _logger.i('✅ ${_allBackups.length} backups carregados');
      
    } catch (e) {
      _logger.e('❌ Erro ao carregar histórico: $e');
      _allBackups = [];
      _filteredBackups = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aplica filtros e ordenação aos backups
  void _applyFiltersAndSort() {
    List<Backup> filtered = List.from(_allBackups);

    // Aplicar filtro de busca
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((backup) =>
          backup.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          backup.originalPath.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Aplicar filtro por status/data
    switch (_currentFilter) {
      case FilterOption.completed:
        filtered = filtered.where((b) => b.status == 'completed').toList();
        break;
      case FilterOption.failed:
        filtered = filtered.where((b) => b.status == 'failed').toList();
        break;
      case FilterOption.today:
        final today = DateTime.now();
        filtered = filtered.where((b) => 
            b.createdAt.year == today.year &&
            b.createdAt.month == today.month &&
            b.createdAt.day == today.day
        ).toList();
        break;
      case FilterOption.thisWeek:
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        filtered = filtered.where((b) => b.createdAt.isAfter(weekStart)).toList();
        break;
      case FilterOption.thisMonth:
        final now = DateTime.now();
        filtered = filtered.where((b) => 
            b.createdAt.year == now.year && b.createdAt.month == now.month
        ).toList();
        break;
      case FilterOption.all:
        // Não aplicar filtro
        break;
    }

    // Aplicar ordenação
    switch (_currentSort) {
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortOption.sizeDesc:
        filtered.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));
        break;
      case SortOption.sizeAsc:
        filtered.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
        break;
    }

    _filteredBackups = filtered;
    _logger.d('🔍 ${_filteredBackups.length} backups após filtros');
  }

  /// Altera a ordenação
  void setSortOption(SortOption sortOption) {
    if (_currentSort != sortOption) {
      _currentSort = sortOption;
      _applyFiltersAndSort();
      notifyListeners();
      _logger.d('📊 Ordenação alterada para: ${sortOption.displayName}');
    }
  }

  /// Altera o filtro
  void setFilterOption(FilterOption filterOption) {
    if (_currentFilter != filterOption) {
      _currentFilter = filterOption;
      _applyFiltersAndSort();
      notifyListeners();
      _logger.d('🔍 Filtro alterado para: ${filterOption.displayName}');
    }
  }

  /// Aplica busca no histórico
  void searchHistory(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
    _logger.d('🔍 Busca aplicada: "$query"');
  }

  /// Obtém informações detalhadas de um backup
  Future<BackupHistoryItem> getBackupHistoryItem(Backup backup) async {
    try {
      final password = await _passwordManager.retrievePassword(backup.id);
      
      return BackupHistoryItem(
        backup: backup,
        password: password,
        formattedDate: _formatDate(backup.createdAt),
        formattedSize: _formatFileSize(backup.fileSize ?? 0),
        statusColor: _getStatusColor(backup.status),
        statusIcon: _getStatusIcon(backup.status),
      );
      
    } catch (e) {
      _logger.e('❌ Erro ao obter detalhes do backup ${backup.id}: $e');
      return BackupHistoryItem(
        backup: backup,
        password: 'Erro ao recuperar',
        formattedDate: _formatDate(backup.createdAt),
        formattedSize: _formatFileSize(backup.fileSize ?? 0),
        statusColor: Colors.grey,
        statusIcon: Icons.error,
      );
    }
  }

  /// Abre o arquivo ZIP com senha
  Future<void> openBackupFile(String backupId) async {
    _logger.i('📦 Abrindo backup: $backupId');
    
    try {
      await _backupService.openZipWithPassword(backupId);
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir backup: $e');
      rethrow;
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
                        await Clipboard.setData(ClipboardData(text: password));
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

  /// Abre o diretório original
  Future<void> openOriginalDirectory(String originalPath) async {
    _logger.i('📁 Abrindo diretório: $originalPath');
    
    try {
      await _backupService.openDirectory(originalPath);
      
    } catch (e) {
      _logger.e('❌ Erro ao abrir diretório: $e');
      rethrow;
    }
  }

  /// Deleta um backup
  Future<void> deleteBackup(String backupId) async {
    _logger.i('🗑️ Deletando backup: $backupId');
    
    try {
      await _backupService.deleteBackup(backupId);
      await loadHistory(); // Recarregar lista
      
    } catch (e) {
      _logger.e('❌ Erro ao deletar backup: $e');
      rethrow;
    }
  }

  /// Exporta o histórico para arquivo
  Future<void> exportHistory() async {
    _logger.i('📤 Exportando histórico...');
    
    try {
      // TODO: Implementar exportação
      _logger.i('📊 ${_allBackups.length} backups para exportar');
      
    } catch (e) {
      _logger.e('❌ Erro ao exportar histórico: $e');
      rethrow;
    }
  }

  /// Formata data para exibição brasileira
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
           '${date.month.toString().padLeft(2, '0')}/'
           '${date.year} '
           '${date.hour.toString().padLeft(2, '0')}:'
           '${date.minute.toString().padLeft(2, '0')}:'
           '${date.second.toString().padLeft(2, '0')}';
  }

  /// Formata tamanho do arquivo
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Obtém cor do status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'creating':
      case 'uploading':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Obtém ícone do status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'creating':
        return Icons.archive;
      case 'uploading':
        return Icons.cloud_upload;
      default:
        return Icons.help;
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 HistoryViewModel disposed');
    super.dispose();
  }
}

/// Classe para encapsular informações de um item do histórico
class BackupHistoryItem {
  final Backup backup;
  final String password;
  final String formattedDate;
  final String formattedSize;
  final Color statusColor;
  final IconData statusIcon;

  BackupHistoryItem({
    required this.backup,
    required this.password,
    required this.formattedDate,
    required this.formattedSize,
    required this.statusColor,
    required this.statusIcon,
  });
}