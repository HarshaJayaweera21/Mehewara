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
  bool _isMapReady = false;
  bool _hasRealUserLocation = false;
  String? _errorMessage;

  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  ExplorerViewMode _viewMode = ExplorerViewMode.map;
  Problem? _selectedProblem;

  // Real-time user location with graceful default
  LatLng _userLocation = LocationService.defaultLocation;
  LatLng get userLocation => _userLocation;
  bool get isLocatingUser => _isLocatingUser;
  bool get hasRealUserLocation => _hasRealUserLocation;
  bool get isMapReady => _isMapReady;

  // Dynamic camera center: selected problem -> centroid of problems -> user location
  LatLng get defaultCenter {
    if (_selectedProblem != null) {
      return LatLng(_selectedProblem!.latitude, _selectedProblem!.longitude);
    }
    final activeList = _filteredProblems.isNotEmpty ? _filteredProblems : _allProblems;
    if (activeList.isNotEmpty) {
      final avgLat =
          activeList.map((p) => p.latitude).reduce((a, b) => a + b) / activeList.length;
      final avgLng =
          activeList.map((p) => p.longitude).reduce((a, b) => a + b) / activeList.length;
      return LatLng(avgLat, avgLng);
    }
    return _userLocation;
  }

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

  void onMapReady() {
    _isMapReady = true;
    if (_filteredProblems.isNotEmpty && _selectedProblem == null) {
      fitToProblems();
    }
  }

  /// Automatically adjusts camera bounds or center so all active incident pins are visible
  void fitToProblems() {
    if (_filteredProblems.isEmpty) return;
    try {
      if (_filteredProblems.length == 1) {
        mapController.move(
          LatLng(_filteredProblems.first.latitude, _filteredProblems.first.longitude),
          15.0,
        );
      } else {
        final points = _filteredProblems
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        final bounds = LatLngBounds.fromPoints(points);
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(
              top: 190,
              bottom: 170,
              left: 48,
              right: 48,
            ),
            maxZoom: 16.0,
            minZoom: 12.0,
          ),
        );
      }
    } catch (_) {
      // MapController not mounted yet; will be triggered when onMapReady fires
    }
  }

  Future<void> initUserLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (loc != null) {
      _userLocation = loc;
      _hasRealUserLocation = true;
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

      if (_isMapReady && _filteredProblems.isNotEmpty && _selectedProblem == null) {
        fitToProblems();
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
    if (_isMapReady && _filteredProblems.isNotEmpty && _selectedProblem == null) {
      fitToProblems();
    }
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    if (_isMapReady && _filteredProblems.isNotEmpty && _selectedProblem == null) {
      fitToProblems();
    }
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
    } else {
      if (_isMapReady && _filteredProblems.isNotEmpty) {
        fitToProblems();
      }
    }
    notifyListeners();
  }

  Future<void> recenterToUser() async {
    _isLocatingUser = true;
    notifyListeners();

    final loc = await LocationService.getCurrentLocation();
    if (loc != null) {
      _userLocation = loc;
      _hasRealUserLocation = true;
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

