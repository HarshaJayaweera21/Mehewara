import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/work_order_model.dart';
import '../../../services/location_service.dart';

class CrewWorkMap extends StatefulWidget {
  final CrewLocation crewLocation;
  final WorkOrderModel? inProgressOrder;
  final List<WorkOrderModel> queuedOrders;
  final Function(WorkOrderModel)? onSelectOrder;
  final VoidCallback? onRefreshGps;
  final bool isRefreshingGps;

  const CrewWorkMap({
    super.key,
    required this.crewLocation,
    this.inProgressOrder,
    this.queuedOrders = const [],
    this.onSelectOrder,
    this.onRefreshGps,
    this.isRefreshingGps = false,
  });

  @override
  State<CrewWorkMap> createState() => _CrewWorkMapState();
}

class _CrewWorkMapState extends State<CrewWorkMap> {
  int _zoom = 14;
  late double _centerLat;
  late double _centerLon;
  String? _selectedMarkerId; // 'crew' or workOrder.id

  @override
  void initState() {
    super.initState();
    _resetCenter();
  }

  @override
  void didUpdateWidget(covariant CrewWorkMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If center was pointing to default depot and live GPS just arrived, auto-center on live GPS
    if (!oldWidget.crewLocation.isLiveGps && widget.crewLocation.isLiveGps) {
      _centerOnSquad();
    }
  }

  void _resetCenter() {
    if (widget.inProgressOrder != null && widget.inProgressOrder!.hasValidCoordinates) {
      _centerLat = widget.inProgressOrder!.latitude;
      _centerLon = widget.inProgressOrder!.longitude;
      _selectedMarkerId = widget.inProgressOrder!.id;
    } else {
      _centerLat = widget.crewLocation.latitude;
      _centerLon = widget.crewLocation.longitude;
      _selectedMarkerId = 'crew';
    }
  }

  void _centerOnSquad() {
    setState(() {
      _centerLat = widget.crewLocation.latitude;
      _centerLon = widget.crewLocation.longitude;
      _selectedMarkerId = 'crew';
      _zoom = 15;
    });
  }

  void _centerOnActive() {
    if (widget.inProgressOrder != null && widget.inProgressOrder!.hasValidCoordinates) {
      setState(() {
        _centerLat = widget.inProgressOrder!.latitude;
        _centerLon = widget.inProgressOrder!.longitude;
        _selectedMarkerId = widget.inProgressOrder!.id;
        _zoom = 15;
      });
    }
  }

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() => _zoom += 1);
    }
  }

  void _zoomOut() {
    if (_zoom > 11) {
      setState(() => _zoom -= 1);
    }
  }

  // Web Mercator helpers
  double _lonToX(double lon, int zoom) {
    final n = pow(2, zoom).toDouble();
    return (lon + 180.0) / 360.0 * n * 256.0;
  }

  double _latToY(double lat, int zoom) {
    final n = pow(2, zoom).toDouble();
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final latRad = clampedLat * pi / 180.0;
    return (1.0 - log(tan(latRad) + (1.0 / cos(latRad))) / pi) / 2.0 * n * 256.0;
  }

  double _xToLon(double x, int zoom) {
    final n = pow(2, zoom).toDouble();
    return (x / (n * 256.0)) * 360.0 - 180.0;
  }

  double _yToLat(double y, int zoom) {
    final n = pow(2, zoom).toDouble();
    final yNorm = 1.0 - (2.0 * y) / (n * 256.0);
    final clampedYNorm = yNorm.clamp(-1.0, 1.0);
    final latRad = atan(_sinh(pi * clampedYNorm));
    return latRad * 180.0 / pi;
  }

  double _sinh(double x) => (exp(x) - exp(-x)) / 2.0;

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(max(0.0, a)));
  }

  @override
  Widget build(BuildContext context) {
    final validOrders = <WorkOrderModel>[];
    if (widget.inProgressOrder != null && widget.inProgressOrder!.hasValidCoordinates) {
      validOrders.add(widget.inProgressOrder!);
    }
    for (final order in widget.queuedOrders) {
      if (order.hasValidCoordinates && order.id != widget.inProgressOrder?.id) {
        validOrders.add(order);
      }
    }

    WorkOrderModel? selectedOrder;
    if (_selectedMarkerId != null && _selectedMarkerId != 'crew') {
      selectedOrder = validOrders.where((o) => o.id == _selectedMarkerId).firstOrNull;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Live Status Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 16, color: AppColors.primaryForest),
                const SizedBox(width: 6),
                const Text(
                  'OPERATIONAL FIELD WORK MAP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // GPS Live status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.crewLocation.isLiveGps
                        ? AppColors.statusAvailableBg
                        : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.crewLocation.isLiveGps
                          ? AppColors.statusAvailableBorder
                          : AppColors.borderDefault,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.crewLocation.isLiveGps
                              ? AppColors.statusAvailableText
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.crewLocation.isLiveGps ? 'GPS LIVE' : 'DEPOT PIN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: widget.crewLocation.isLiveGps
                              ? AppColors.statusAvailableText
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // GPS Refresh Button
                if (widget.onRefreshGps != null)
                  InkWell(
                    onTap: widget.isRefreshingGps ? null : widget.onRefreshGps,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        border: Border.all(color: AppColors.borderDefault),
                        shape: BoxShape.circle,
                      ),
                      child: widget.isRefreshingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryForest,
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                              size: 14,
                              color: AppColors.primaryForest,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Interactive Map Viewport
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E3DF),
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Tiles Layer with Pan Gesture Support
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;

                      final centerPxX = _lonToX(_centerLon, _zoom);
                      final centerPxY = _latToY(_centerLat, _zoom);

                      final minX = centerPxX - (width / 2.0);
                      final maxX = centerPxX + (width / 2.0);
                      final minY = centerPxY - (height / 2.0);
                      final maxY = centerPxY + (height / 2.0);

                      final startTileX = (minX / 256.0).floor();
                      final endTileX = (maxX / 256.0).floor();
                      final startTileY = (minY / 256.0).floor();
                      final endTileY = (maxY / 256.0).floor();
                      final maxTileIndex = (pow(2, _zoom).toInt() - 1);

                      final tiles = <Widget>[];

                      for (int tx = startTileX; tx <= endTileX; tx++) {
                        for (int ty = startTileY; ty <= endTileY; ty++) {
                          if (ty < 0 || ty > maxTileIndex) continue;
                          final tileX = ((tx % (maxTileIndex + 1)) + (maxTileIndex + 1)) % (maxTileIndex + 1);
                          final tileY = ty;

                          final tileLeft = (tx * 256.0) - minX;
                          final tileTop = (ty * 256.0) - minY;

                          tiles.add(
                            Positioned(
                              left: tileLeft,
                              top: tileTop,
                              width: 256,
                              height: 256,
                              child: Image.network(
                                'https://tile.openstreetmap.org/$_zoom/$tileX/$tileY.png',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFFE5E3DF),
                                  child: const Center(
                                    child: Icon(Icons.map_outlined, color: Colors.black26),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      // Markers on top of tiles
                      final markerWidgets = <Widget>[];

                      // 1. Crew GPS Squad Marker
                      final crewPxX = _lonToX(widget.crewLocation.longitude, _zoom);
                      final crewPxY = _latToY(widget.crewLocation.latitude, _zoom);
                      final crewScreenX = crewPxX - minX;
                      final crewScreenY = crewPxY - minY;

                      markerWidgets.add(
                        Positioned(
                          left: crewScreenX - 22,
                          top: crewScreenY - 44,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMarkerId = 'crew'),
                            child: _buildSquadPin(isSelected: _selectedMarkerId == 'crew'),
                          ),
                        ),
                      );

                      // 2. Problem Location Markers
                      for (int i = 0; i < validOrders.length; i++) {
                        final order = validOrders[i];
                        final orderPxX = _lonToX(order.longitude, _zoom);
                        final orderPxY = _latToY(order.latitude, _zoom);
                        final orderScreenX = orderPxX - minX;
                        final orderScreenY = orderPxY - minY;

                        final isOrderActive = order.id == widget.inProgressOrder?.id;
                        final isSelected = _selectedMarkerId == order.id;

                        markerWidgets.add(
                          Positioned(
                            left: orderScreenX - 20,
                            top: orderScreenY - 42,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMarkerId = order.id),
                              child: _buildProblemPin(
                                order: order,
                                index: i + 1,
                                isActive: isOrderActive,
                                isSelected: isSelected,
                              ),
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onPanUpdate: (details) {
                          final currentCenterX = _lonToX(_centerLon, _zoom);
                          final currentCenterY = _latToY(_centerLat, _zoom);
                          final newCenterX = currentCenterX - details.delta.dx;
                          final newCenterY = currentCenterY - details.delta.dy;
                          setState(() {
                            _centerLon = _xToLon(newCenterX, _zoom);
                            _centerLat = _yToLat(newCenterY, _zoom);
                          });
                        },
                        child: Stack(
                          children: [
                            ...tiles,
                            ...markerWidgets,
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Map Attribution
                Positioned(
                  bottom: 4,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 8.5, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                // Controls Toolbar (Top Right): Zoom & Center Toggles
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      // Zoom In
                      Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: InkWell(
                          onTap: _zoomIn,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.add, size: 20, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      // Zoom Out
                      Material(
                        color: Colors.white,
                        elevation: 2,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        child: InkWell(
                          onTap: _zoomOut,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.remove, size: 20, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Recenter on Squad GPS
                      Material(
                        color: _selectedMarkerId == 'crew' ? AppColors.primaryForest : Colors.white,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _centerOnSquad,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.navigation_outlined,
                              size: 18,
                              color: _selectedMarkerId == 'crew' ? Colors.white : AppColors.primaryForest,
                            ),
                          ),
                        ),
                      ),
                      if (widget.inProgressOrder != null && widget.inProgressOrder!.hasValidCoordinates) ...[
                        const SizedBox(height: 6),
                        // Recenter on Active Mission
                        Material(
                          color: _selectedMarkerId == widget.inProgressOrder!.id
                              ? AppColors.priorityCritical
                              : Colors.white,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: _centerOnActive,
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: _selectedMarkerId == widget.inProgressOrder!.id
                                    ? Colors.white
                                    : AppColors.priorityCritical,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Selected Pin Information Callout Card
        if (selectedOrder != null) ...[
          _buildOrderInfoCard(selectedOrder)
        ] else ...[
          _buildSquadInfoCard()
        ],
      ],
    );
  }

  Widget _buildSquadPin({required bool isSelected}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryForest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: const Text(
            'SQUAD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryForest,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryForest.withValues(alpha: isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 16,
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildProblemPin({
    required WorkOrderModel order,
    required int index,
    required bool isActive,
    required bool isSelected,
  }) {
    final pinColor = isActive ? AppColors.priorityCritical : AppColors.priorityHigh;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: pinColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            isActive ? 'ACTIVE' : '#$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: pinColor.withValues(alpha: isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: Icon(
            isActive ? Icons.warning_rounded : Icons.location_on,
            color: Colors.white,
            size: 15,
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildSquadInfoCard() {
    return Card(
      elevation: 0,
      color: AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softSage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.navigation, color: AppColors.primaryForest, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Squad Field GPS Location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.crewLocation.isLiveGps)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.statusAvailableBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.statusAvailableText,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.crewLocation.latitude.toStringAsFixed(5)}° N, ${widget.crewLocation.longitude.toStringAsFixed(5)}° E • ${widget.crewLocation.statusMessage ?? "Central Colombo Depot"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(WorkOrderModel order) {
    final distanceKm = _calculateDistanceKm(
      widget.crewLocation.latitude,
      widget.crewLocation.longitude,
      order.latitude,
      order.longitude,
    );

    final distanceStr = distanceKm < 1.0
        ? '${(distanceKm * 1000).toStringAsFixed(0)} m away'
        : '${distanceKm.toStringAsFixed(1)} km away';

    final isActive = order.id == widget.inProgressOrder?.id;

    return Card(
      elevation: 0,
      color: isActive ? AppColors.priorityCriticalBg : AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isActive ? AppColors.priorityCritical.withValues(alpha: 0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.priorityCritical.withValues(alpha: 0.15)
                    : AppColors.priorityHighBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive ? Icons.warning_amber_rounded : Icons.assignment_outlined,
                color: isActive ? AppColors.priorityCritical : AppColors.priorityHigh,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.problemTitle.isNotEmpty ? order.problemTitle : order.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          distanceStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryForest,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.problemAddress ?? 'Municipal Field Site, Colombo',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onSelectOrder != null)
              ElevatedButton(
                onPressed: () => widget.onSelectOrder!(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? AppColors.priorityCritical : AppColors.primaryForest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  isActive ? 'Active Mission' : 'View',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
