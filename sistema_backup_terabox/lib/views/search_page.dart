import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/search_viewmodel.dart';
import '../utils/app_theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus && _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // SearchBar interativa no topo
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Consumer<SearchViewModel>(
              builder: (context, searchVM, child) {
                return Column(
                  children: [
                    // Campo de busca principal com animações
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _searchFocusNode.hasFocus 
                              ? AppColors.primary 
                              : AppColors.primary.withOpacity(0.3),
                          width: _searchFocusNode.hasFocus ? 2 : 1,
                        ),
                        boxShadow: _searchFocusNode.hasFocus ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome, data ou caminho...',
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                          prefixIcon: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.search_rounded,
                              color: _searchFocusNode.hasFocus 
                                  ? AppColors.primary 
                                  : AppColors.textSecondary,
                              size: 24,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Contador de resultados
                                    if (searchVM.searchResults.isNotEmpty && !searchVM.isSearching)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${searchVM.searchResults.length}',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    // Botão limpar
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        searchVM.clearSearch();
                                        setState(() {
                                          _showSuggestions = false;
                                        });
                                      },
                                      tooltip: 'Limpar busca',
                                    ),
                                  ],
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        onChanged: (query) {
                          searchVM.searchBackups(query);
                          setState(() {
                            _showSuggestions = query.isNotEmpty && _searchFocusNode.hasFocus;
                          });
                          
                          if (query.isNotEmpty) {
                            _animationController.forward();
                          } else {
                            _animationController.reverse();
                          }
                        },
                        onSubmitted: (query) {
                          if (query.isNotEmpty) {
                            searchVM.addToSearchHistory(query);
                            _searchFocusNode.unfocus();
                            setState(() {
                              _showSuggestions = false;
                            });
                          }
                        },
                      ),
                    ),
                    
                    // Sugestões de autocompletar com animação
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showSuggestions ? null : 0,
                      child: _showSuggestions ? Column(
                        children: [
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 160),
                              child: _buildInteractiveSuggestions(searchVM),
                            ),
                          ),
                        ],
                      ) : const SizedBox.shrink(),
                    ),
                    
                    // Filtros rápidos
                    if (_searchController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildQuickFilters(searchVM),
                    ],
                  ],
                );
              },
            ),
          ),
          
          // Resultados da busca
          Expanded(
            child: Consumer<SearchViewModel>(
              builder: (context, searchVM, child) {
                if (searchVM.currentQuery.isEmpty) {
                  return _buildEmptyState();
                }
                
                if (searchVM.isSearching) {
                  return _buildLoadingState();
                }
                
                if (searchVM.searchResults.isEmpty) {
                  return _buildNoResultsState();
                }
                
                return _buildSearchResults(searchVM);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveSuggestions(SearchViewModel searchVM) {
    final suggestions = searchVM.getFilteredSuggestions(_searchController.text);
    final recentSearches = searchVM.getRecentSearches();
    
    if (suggestions.isEmpty && recentSearches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Digite para ver sugestões...',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sugestões baseadas em backups existentes
          if (suggestions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sugestões',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...suggestions.take(3).map((suggestion) => _buildSuggestionItem(
              suggestion,
              Icons.folder_outlined,
              AppColors.primary,
              () {
                _searchController.text = suggestion;
                searchVM.searchBackups(suggestion);
                _searchFocusNode.unfocus();
                setState(() {
                  _showSuggestions = false;
                });
              },
            )),
          ],
          
          // Buscas recentes
          if (recentSearches.isNotEmpty) ...[
            if (suggestions.isNotEmpty) const Divider(height: 1, color: AppColors.textSecondary),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Buscas recentes',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      searchVM.clearSearchHistory();
                      setState(() {});
                    },
                    child: const Text(
                      'Limpar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...recentSearches.take(3).map((search) => _buildSuggestionItem(
              search,
              Icons.history,
              AppColors.textSecondary,
              () {
                _searchController.text = search;
                searchVM.searchBackups(search);
                _searchFocusNode.unfocus();
                setState(() {
                  _showSuggestions = false;
                });
              },
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.north_west_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters(SearchViewModel searchVM) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            'Hoje',
            Icons.today_rounded,
            searchVM.isFilterActive('today'),
            () => searchVM.toggleDateFilter('today'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Esta semana',
            Icons.date_range_rounded,
            searchVM.isFilterActive('week'),
            () => searchVM.toggleDateFilter('week'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Este mês',
            Icons.calendar_month_rounded,
            searchVM.isFilterActive('month'),
            () => searchVM.toggleDateFilter('month'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Grandes (>100MB)',
            Icons.storage_rounded,
            searchVM.isFilterActive('large'),
            () => searchVM.toggleSizeFilter('large'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Digite algo para buscar',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Você pode buscar por nome do backup\nou caminho do diretório',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(height: 16),
          Text(
            'Buscando...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum backup encontrado',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente buscar por "${_searchController.text}" com outros termos',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(SearchViewModel searchVM) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchVM.searchResults.length,
      itemBuilder: (context, index) {
        final backup = searchVM.searchResults[index];
        return FutureBuilder(
          future: searchVM.getBackupDetails(backup),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildLoadingResultCard();
            }
            
            final result = snapshot.data!;
            return _buildResultCard(result, searchVM);
          },
        );
      },
    );
  }

  Widget _buildLoadingResultCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          SizedBox(width: 16),
          Text(
            'Carregando...',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BackupSearchResult result, SearchViewModel searchVM) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com nome e data
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.archive,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.backup.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.formattedDate,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  result.formattedSize,
                  style: const TextStyle(
                    color: AppColors.highlight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Caminho original
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.backup.originalPath,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.open_in_new,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                  onPressed: () async {
                    try {
                      await searchVM.openOriginalDirectory(result.backup.originalPath);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao abrir pasta: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'Abrir pasta original',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Senha (clicável para copiar) - Melhorada
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Senha: ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await searchVM.copyPasswordToClipboard(result.backup.id);
                      
                      if (mounted) {
                        // Feedback visual melhorado
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Senha copiada!',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.primary,
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              result.password,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              color: AppColors.accent,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Ações
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await searchVM.openBackupFileWithPasswordDialog(context, result.backup.id);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao abrir ZIP: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.folder_zip,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    label: const Text(
                      'Abrir ZIP',
                      style: TextStyle(
                        color: AppColors.secondary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.secondary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await searchVM.openOriginalDirectory(result.backup.originalPath);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao abrir pasta: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.folder_open,
                      size: 16,
                      color: AppColors.highlight,
                    ),
                    label: const Text(
                      'Pasta Original',
                      style: TextStyle(
                        color: AppColors.highlight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.highlight.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}