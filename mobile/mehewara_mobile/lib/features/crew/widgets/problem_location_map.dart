import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class ProblemLocationMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;

  const ProblemLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  State<ProblemLocationMap> createState() => _ProblemLocationMapState();
}

class _ProblemLocationMapState extends State<ProblemLocationMap> {
  int _zoom = 15;
  bool _copied = false;

  bool get _hasValidCoords =>
      widget.latitude != 0.0 &&
      widget.longitude != 0.0 &&
      widget.latitude.abs() <= 90.0 &&
      widget.longitude.abs() <= 180.0;

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() => _zoom += 1);
    }
  }

  void _zoomOut() {
    if (_zoom > 12) {
      setState(() => _zoom -= 1);
    }
  }

  void _copyCoordinates() {
    Clipboard.setData(ClipboardData(text: '${widget.latitude}, ${widget.longitude}'));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidCoords) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.canvasBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_outlined, color: AppColors.textMuted, size: 28),
              const SizedBox(height: 6),
              const Text(
                'Precise GPS coordinates pending field verification',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              if (widget.address != null && widget.address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.address!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Calculate tile coordinate
    final n = pow(2, _zoom).toDouble();
    final xDouble = (widget.longitude + 180.0) / 360.0 * n;
    final latRad = widget.latitude * pi / 180.0;
    final yDouble = (1.0 - log(tan(latRad) + (1.0 / cos(latRad))) / pi) / 2.0 * n;

    final xCenterTile = xDouble.floor();
    final yCenterTile = yDouble.floor();

    final xOffsetPercent = (xDouble - xCenterTile);
    final yOffsetPercent = (yDouble - yCenterTile);

    const tileSize = 256.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Map Container
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E3DF),
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 3x3 Tile Grid Centered around target
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final centerX = constraints.maxWidth / 2;
                      final centerY = constraints.maxHeight / 2;

                      // Top left of center tile
                      final centerTileLeft = centerX - (xOffsetPercent * tileSize);
                      final centerTileTop = centerY - (yOffsetPercent * tileSize);

                      final tiles = <Widget>[];

                      for (int dx = -1; dx <= 1; dx++) {
                        for (int dy = -1; dy <= 1; dy++) {
                          final tileX = xCenterTile + dx;
                          final tileY = yCenterTile + dy;
                          final left = centerTileLeft + (dx * tileSize);
                          final top = centerTileTop + (dy * tileSize);

                          tiles.add(
                            Positioned(
                              left: left,
                              top: top,
                              width: tileSize,
                              height: tileSize,
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

                      return Stack(children: tiles);
                    },
                  ),
                ),

                // Pulsating Centered Location Pin Marker
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.priorityCritical,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.priorityCritical.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 6,
                        color: AppColors.priorityCritical,
                      ),
                      Container(
                        width: 8,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Map Attribution
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 9, color: Colors.black54),
                    ),
                  ),
                ),

                // Zoom Controls
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        elevation: 2,
                        child: InkWell(
                          onTap: _zoomIn,
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.add, size: 18, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Material(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                        elevation: 2,
                        child: InkWell(
                          onTap: _zoomOut,
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.remove, size: 18, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Coordinates & Copy Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 14, color: AppColors.primaryForest),
                const SizedBox(width: 4),
                Text(
                  '${widget.latitude.toStringAsFixed(6)}°, ${widget.longitude.toStringAsFixed(6)}°',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _copyCoordinates,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      _copied ? Icons.check : Icons.copy_outlined,
                      size: 13,
                      color: _copied ? AppColors.statusAvailableText : AppColors.primaryForest,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _copied ? 'Copied' : 'Copy GPS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _copied ? AppColors.statusAvailableText : AppColors.primaryForest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
