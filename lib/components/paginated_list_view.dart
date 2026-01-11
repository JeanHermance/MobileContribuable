import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pagination_service.dart';

/// Widget générique pour afficher une liste paginée avec infinite scroll
class PaginatedListView<T> extends StatefulWidget {
  final PaginationService<T> paginationService;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? separator;
  final bool showLoadingIndicator;
  final String? loadingText;
  
  const PaginatedListView({
    super.key,
    required this.paginationService,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.errorBuilder,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.separator,
    this.showLoadingIndicator = true,
    this.loadingText,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    
    // Écouter le scroll pour l'infinite scroll
    _scrollController.addListener(_onScroll);
    
    // Charger les données initiales si nécessaire
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.paginationService.items.isEmpty && !widget.paginationService.isLoading) {
        widget.paginationService.loadFirstPage();
      }
    });
  }
  
  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Charger plus de données quand on approche de la fin
      widget.paginationService.loadNextPage();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaginationService<T>>.value(
      value: widget.paginationService,
      child: Consumer<PaginationService<T>>(
        builder: (context, paginationService, child) {
          // État de chargement initial
          if (paginationService.isLoading && paginationService.items.isEmpty) {
            return widget.loadingWidget ?? _buildDefaultLoadingWidget();
          }
          
          // État d'erreur
          if (paginationService.error != null && paginationService.items.isEmpty) {
            final error = paginationService.error;
            return widget.errorBuilder?.call(context, error ?? 'Erreur inconnue') ??
                _buildDefaultErrorWidget(error ?? 'Erreur inconnue');
          }
          
          // État vide
          if (paginationService.isEmpty) {
            return widget.emptyWidget ?? _buildDefaultEmptyWidget();
          }
          
          // Liste avec données
          return RefreshIndicator(
            onRefresh: () => paginationService.loadFirstPage(),
            child: _buildListView(paginationService),
          );
        },
      ),
    );
  }
  
  Widget _buildListView(PaginationService<T> paginationService) {
    final itemCount = paginationService.items.length + 
        (paginationService.isLoadingMore ? 1 : 0);
    
    return ListView.separated(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: itemCount,
      separatorBuilder: (context, index) {
        if (index >= paginationService.items.length) {
          return const SizedBox.shrink();
        }
        return widget.separator ?? const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        // Indicateur de chargement en bas
        if (index >= paginationService.items.length) {
          return _buildLoadingMoreIndicator();
        }
        
        final item = paginationService.items[index];
        
        // Déclencher le chargement de la page suivante si nécessaire
        if (paginationService.shouldLoadMore(index)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            paginationService.loadNextPage();
          });
        }
        
        return widget.itemBuilder(context, item, index);
      },
    );
  }
  
  Widget _buildDefaultLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (widget.loadingText != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.loadingText ?? 'Chargement...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDefaultErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => widget.paginationService.loadFirstPage(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDefaultEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Aucune donnée disponible',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingMoreIndicator() {
    if (!widget.showLoadingIndicator) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Chargement...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour la pagination classique avec boutons de navigation
class PaginatedGridView<T> extends StatelessWidget {
  final PaginationService<T> paginationService;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final bool showPaginationControls;
  
  const PaginatedGridView({
    super.key,
    required this.paginationService,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
    this.padding,
    this.emptyWidget,
    this.loadingWidget,
    this.showPaginationControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaginationService<T>>.value(
      value: paginationService,
      child: Consumer<PaginationService<T>>(
        builder: (context, service, child) {
          if (service.isLoading && service.items.isEmpty) {
            return loadingWidget ?? const Center(child: CircularProgressIndicator());
          }
          
          if (service.isEmpty) {
            return emptyWidget ?? const Center(child: Text('Aucune donnée'));
          }
          
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => service.loadFirstPage(),
                  child: GridView.builder(
                    padding: padding,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: crossAxisSpacing,
                      mainAxisSpacing: mainAxisSpacing,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: service.items.length,
                    itemBuilder: (context, index) {
                      return itemBuilder(context, service.items[index], index);
                    },
                  ),
                ),
              ),
              if (showPaginationControls && service.totalPages > 1)
                _buildPaginationControls(context, service),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildPaginationControls(BuildContext context, PaginationService<T> service) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: service.currentPage > 1 ? () => service.loadPage(service.currentPage - 1) : null,
            child: const Text('Précédent'),
          ),
          Text(
            'Page ${service.currentPage} sur ${service.totalPages}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          ElevatedButton(
            onPressed: service.currentPage < service.totalPages ? () => service.loadPage(service.currentPage + 1) : null,
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}
