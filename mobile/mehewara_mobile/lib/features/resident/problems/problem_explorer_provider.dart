import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/location/location_service.dart';
import '../../../models/problem.dart';
import '../../../services/problems/problem_service.dart';

enum ExplorerViewMode { map, list }

class ProblemExplorerProvider extends ChangeNotifier {
  final ProblemService _service = ProblemService();
  final MapController mapController = MapController();

  List<Problem> _allProblems = [];
  List<Problem> _filteredProblems = [];
  bool _isLoading = false;
  bool _isLocatingUser = false;
  String? _errorMessage;

  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  ExplorerViewMode _viewMode = ExplorerViewMode.map;
  Problem? _selectedProblem;

  // Real-time user location with graceful default
  LatLng _userLocation = LocationService.defaultLocation;
  LatLng get userLocation => _userLocation;
  bool get isLocatingUser => _isLocatingUser;

  // Default camera center (falls back to Colombo Ward 4 or first problem centroid)
  LatLng get defaultCenter => _selectedProblem != null
      ? LatLng(_selectedProblem!.latitude, _selectedProblem!.longitude)
      : _userLocation;

  // Getters
  List<Problem> get problems => _filteredProblems;
  int get totalIncidentCount => _allProblems.fold(0, (sum, p) => sum + p.reportCount);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  ExplorerViewMode get viewMode => _viewMode;
  Problem? get selectedProblem => _selectedProblem;

  ProblemExplorerProvider() {
    loadProblems();
    initUserLocation();
  }

  Future<void> initUserLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (loc != null) {
      _userLocation = loc;
      notifyListeners();
    }
  }

  Future<void> loadProblems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allProblems = await _service.getProblems(
        category: _selectedCategory,
        search: _searchQuery,
      );
      _applyFilters();

      if (_selectedProblem != null && !_filteredProblems.contains(_selectedProblem)) {
        _selectedProblem = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    _filteredProblems = _allProblems.where((p) {
      if (_selectedCategory != 'ALL' && p.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = p.title.toLowerCase().contains(q);
        final matchAddr = p.address?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchAddr) return false;
      }
      return true;
    }).toList();
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _applyFilters();
    if (_selectedProblem != null && !_filteredProblems.contains(_selectedProblem)) {
      _selectedProblem = null;
    }
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setViewMode(ExplorerViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void selectProblem(Problem? problem) {
    _selectedProblem = problem;
    if (problem != null) {
      // Smoothly pan camera to problem centroid
      try {
        mapController.move(
          LatLng(problem.latitude, problem.longitude),
          15.5,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> recenterToUser() async {
    _isLocatingUser = true;
    notifyListeners();

    final loc = await LocationService.getCurrentLocation();
    if (loc != null) {
      _userLocation = loc;
    }
    _isLocatingUser = false;
    notifyListeners();

    try {
      mapController.move(_userLocation, 16.0);
    } catch (_) {}
  }

  void zoomIn() {
    try {
      final currentZoom = mapController.camera.zoom;
      mapController.move(mapController.camera.center, currentZoom + 1);
    } catch (_) {}
  }

  void zoomOut() {
    try {
      final currentZoom = mapController.camera.zoom;
      mapController.move(mapController.camera.center, currentZoom - 1);
    } catch (_) {}
  }

  @visibleForTesting
  void setProblemsForTesting(List<Problem> problems) {
    _allProblems = problems;
    _applyFilters();
    notifyListeners();
  }
}

