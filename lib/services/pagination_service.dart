import 'package:flutter/foundation.dart';

/// Service générique pour gérer la pagination des données
class PaginationService<T> extends ChangeNotifier {
  // Variables de pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;
  
  // Données
  List<T> _items = [];
  final int _pageSize;
  
  // Configuration
  final Future<PaginationResult<T>> Function(int page, int limit) _fetchFunction;
  final bool _enableInfiniteScroll;
  
  PaginationService({
    required Future<PaginationResult<T>> Function(int page, int limit) fetchFunction,
    int pageSize = 6,
    bool enableInfiniteScroll = true,
  }) : _fetchFunction = fetchFunction,
       _pageSize = pageSize,
       _enableInfiniteScroll = enableInfiniteScroll;
  
  // Getters
  List<T> get items => List.unmodifiable(_items);
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  int get pageSize => _pageSize;
  
  /// Charge la première page (refresh)
  Future<void> loadFirstPage() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _items.clear();
    notifyListeners();
    
    try {
      final result = await _fetchFunction(_currentPage, _pageSize);
      
      if (result.success && result.data != null) {
        _items = result.data!;
        _currentPage = result.pagination?.page ?? 1;
        _totalPages = result.pagination?.totalPages ?? 1;
        _totalItems = result.pagination?.total ?? _items.length;
        _hasMoreData = _currentPage < _totalPages;
        _error = null;
      } else {
        _error = result.error ?? 'Erreur lors du chargement des données';
        _items.clear();
      }
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      _items.clear();
      debugPrint('PaginationService error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Charge la page suivante (infinite scroll)
  Future<void> loadNextPage() async {
    if (!_enableInfiniteScroll || 
        _isLoadingMore || 
        !_hasMoreData || 
        _isLoading) {
      return;
    }
    
    _isLoadingMore = true;
    _error = null;
    notifyListeners();
    
    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchFunction(nextPage, _pageSize);
      
      if (result.success && result.data != null) {
        _items.addAll(result.data!);
        _currentPage = result.pagination?.page ?? nextPage;
        _totalPages = result.pagination?.totalPages ?? _totalPages;
        _totalItems = result.pagination?.total ?? _totalItems;
        _hasMoreData = _currentPage < _totalPages;
        _error = null;
      } else {
        _error = result.error ?? 'Erreur lors du chargement de la page suivante';
      }
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      debugPrint('PaginationService loadNextPage error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
  
  /// Charge une page spécifique (pagination classique)
  Future<void> loadPage(int page) async {
    if (_isLoading || page < 1 || page > _totalPages) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _fetchFunction(page, _pageSize);
      
      if (result.success && result.data != null) {
        _items = result.data!;
        _currentPage = result.pagination?.page ?? page;
        _totalPages = result.pagination?.totalPages ?? _totalPages;
        _totalItems = result.pagination?.total ?? _totalItems;
        _hasMoreData = _currentPage < _totalPages;
        _error = null;
      } else {
        _error = result.error ?? 'Erreur lors du chargement de la page $page';
      }
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      debugPrint('PaginationService loadPage error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Vérifie si on doit charger plus de données (pour infinite scroll)
  bool shouldLoadMore(int index) {
    if (!_enableInfiniteScroll || !_hasMoreData || _isLoadingMore) {
      return false;
    }
    
    // Déclencher le chargement quand on arrive à 3 éléments de la fin
    return index >= _items.length - 3;
  }
  
  /// Reset le service
  void reset() {
    _currentPage = 1;
    _totalItems = 0;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMoreData = true;
    _error = null;
    _items.clear();
    notifyListeners();
  }
  
  /// Ajoute un élément à la liste (pour les créations en temps réel)
  void addItem(T item, {bool atBeginning = true}) {
    if (atBeginning) {
      _items.insert(0, item);
    } else {
      _items.add(item);
    }
    _totalItems++;
    notifyListeners();
  }
  
  /// Supprime un élément de la liste
  void removeItem(T item) {
    final removed = _items.remove(item);
    if (removed) {
      _totalItems--;
      notifyListeners();
    }
  }
  
  /// Met à jour un élément de la liste
  void updateItem(T oldItem, T newItem) {
    final index = _items.indexOf(oldItem);
    if (index != -1) {
      _items[index] = newItem;
      notifyListeners();
    }
  }
}

/// Classe pour encapsuler le résultat d'une requête paginée
class PaginationResult<T> {
  final bool success;
  final List<T>? data;
  final PaginationInfo? pagination;
  final String? error;
  
  PaginationResult.success(this.data, this.pagination)
      : success = true,
        error = null;
  
  PaginationResult.error(this.error)
      : success = false,
        data = null,
        pagination = null;
}

/// Informations de pagination
class PaginationInfo {
  final int page;
  final int totalPages;
  final int total;
  final int limit;
  
  PaginationInfo({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.limit,
  });
  
  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: _safeParseInt(json['page']) ?? 1,
      totalPages: _safeParseInt(json['totalPages']) ?? 1,
      total: _safeParseInt(json['total']) ?? 0,
      limit: _safeParseInt(json['limit']) ?? 20,
    );
  }
  
  /// Convertit de manière sécurisée une valeur en int
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }
}
