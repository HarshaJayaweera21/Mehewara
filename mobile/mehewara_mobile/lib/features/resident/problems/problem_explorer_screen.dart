import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/common/civic_bottom_nav_bar.dart';
import '../../../widgets/common/civic_header.dart';
import '../../../widgets/problems/category_filter_bar.dart';
import '../../../widgets/problems/problem_pin_marker.dart';
import '../../../widgets/problems/problem_preview_card.dart';
import '../../auth/auth_widgets.dart';
import 'problem_detail_screen.dart';
import 'problem_explorer_provider.dart';

class ProblemExplorerScreen extends StatefulWidget {
  final bool embedded;

  const ProblemExplorerScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ProblemExplorerScreen> createState() => _ProblemExplorerScreenState();
}

class _ProblemExplorerScreenState extends State<ProblemExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProblemExplorerProvider(),
      child: Consumer<ProblemExplorerProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F7F4),
            appBar: CivicHeader(
              title: 'Community Incidents',
              subtitle: 'Live Municipal Map & Directory',
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded, color: CivicColors.forest),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    provider.loadProblems();
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  // 1. MAIN BODY: MAP VIEW OR LIST VIEW
                  Positioned.fill(
                    child: provider.viewMode == ExplorerViewMode.map
                        ? _buildMapView(provider)
                        : _buildListView(provider),
                  ),

                  // 2. TOP HEADER SECTION (FROSTED OVERLAY)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopHeaderSection(provider),
                  ),

                  // 3. FLOATING PREVIEW CARD (When Map Mode is active and problem selected)
                  if (provider.viewMode == ExplorerViewMode.map &&
                      provider.selectedProblem != null)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: widget.embedded ? 14 : 76,
                      child: ProblemPreviewCard(
                        problem: provider.selectedProblem!,
                        onTrackProgress: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProblemDetailScreen(
                                problem: provider.selectedProblem!,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 4. BOTTOM NAVIGATION BAR (When not embedded in resident shell)
                  if (!widget.embedded)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: CivicBottomNavBar(
                        currentTab: CivicNavTab.incidents,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TOP HEADER & FILTER SECTION
  // ===========================================================================
  Widget _buildTopHeaderSection(ProblemExplorerProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F4).withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0x99DCE5DF), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: CivicColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
                boxShadow: const [CivicShadows.subtle],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: CivicColors.forest,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        provider.updateSearch(val);
                        setState(() {});
                      },
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: CivicColors.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search incidents, streets or wards...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: CivicColors.subdued,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        provider.updateSearch('');
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 17,
                          color: CivicColors.subdued,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Category Filter Chips
          CategoryFilterBar(
            selectedCategory: provider.selectedCategory,
            totalCount: provider.totalIncidentCount,
            onSelectCategory: provider.selectCategory,
          ),
          const SizedBox(height: 8),

          // 4. View Switcher Row (Map View vs List View)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: CivicColors.segmentBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFDCE5DF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Map View Button
                      _buildSegmentButton(
                        icon: Icons.map_rounded,
                        label: 'Map View',
                        isActive: provider.viewMode == ExplorerViewMode.map,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.setViewMode(ExplorerViewMode.map);
                        },
                      ),
                      const SizedBox(width: 3),
                      // List View Button
                      _buildSegmentButton(
                        icon: Icons.view_agenda_rounded,
                        label: 'List (${provider.problems.length})',
                        isActive: provider.viewMode == ExplorerViewMode.list,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          provider.setViewMode(ExplorerViewMode.list);
                        },
                      ),
                    ],
                  ),
                ),
                Text(
                  '${provider.problems.length} of ${provider.totalIncidentCount} reports',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: CivicColors.slateGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? CivicColors.cardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive ? const [CivicShadows.subtle] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.5,
              color: isActive ? CivicColors.forest : CivicColors.slateGreen,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? CivicColors.forest : CivicColors.slateGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE MAP CANVAS
  // ===========================================================================
  Widget _buildMapView(ProblemExplorerProvider provider) {
    return Stack(
      children: [
        FlutterMap(
          mapController: provider.mapController,
          options: MapOptions(
            initialCenter: provider.defaultCenter,
            initialZoom: 15.0,
            minZoom: 10.0,
            maxZoom: 18.0,
          ),
          children: [
            // OpenStreetMap Standard Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mehewara.mobile',
            ),

            // Markers Layer: Problems + User Location Marker
            MarkerLayer(
              markers: [
                // 1. User Location ("You are here")
                Marker(
                  point: provider.userLocation,
                  width: 140,
                  height: 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CivicColors.charcoal,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Colors.blueAccent,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'You are here',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade600,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Incident Pin Markers for each Problem in DB
                ...provider.problems.map((problem) {
                  final isSelected = provider.selectedProblem?.id == problem.id;
                  return Marker(
                    point: LatLng(problem.latitude, problem.longitude),
                    width: 54,
                    height: 64,
                    child: ProblemPinMarker(
                      problem: problem,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.selectProblem(problem);
                      },
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Floating Map Utility Controls (Upper-Right)
        Positioned(
          top: 185,
          right: 14,
          child: Column(
            children: [
              // Recenter GPS Button
              _buildMapControlBtn(
                icon: Icons.my_location_rounded,
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.recenterToUser();
                },
                iconColor: CivicColors.forest,
                isLoading: provider.isLocatingUser,
                tooltip: 'Recenter on my location',
              ),
              const SizedBox(height: 10),
              // Zoom In / Out Group
              Container(
                decoration: BoxDecoration(
                  color: CivicColors.cardSurface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
                  boxShadow: const [CivicShadows.subtle],
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.zoomIn();
                      },
                      child: const SizedBox(
                        width: 38,
                        height: 36,
                        child: Center(
                          child: Icon(Icons.add_rounded, size: 20, color: CivicColors.charcoal),
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8E4)),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        provider.zoomOut();
                      },
                      child: const SizedBox(
                        width: 38,
                        height: 36,
                        child: Center(
                          child: Icon(Icons.remove_rounded, size: 20, color: CivicColors.charcoal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
    bool isLoading = false,
    String? tooltip,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: CivicColors.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
        boxShadow: const [CivicShadows.subtle],
      ),
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CivicColors.forest,
                ),
              ),
            )
          : IconButton(
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 20, color: iconColor),
              onPressed: onTap,
            ),
    );
  }

  // ===========================================================================
  // ALTERNATIVE LIST VIEW (When List toggle is pressed)
  // ===========================================================================
  Widget _buildListView(ProblemExplorerProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CivicColors.forest),
      );
    }

    return CivicAtmosphericBackground(
      child: RefreshIndicator(
        color: CivicColors.forest,
        onRefresh: provider.loadProblems,
        child: provider.problems.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 200, left: 24, right: 24),
                child: Center(
                  child: CivicSurfaceCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: CivicColors.mintTint,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CivicColors.mintPip.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 28,
                            color: CivicColors.forest,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No Active Incidents Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CivicColors.charcoal,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No results match "${_searchController.text}". Try a different search term or category filter.'
                              : 'There are currently no incidents recorded for the ${provider.selectedCategory} category.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CivicColors.subdued,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            provider.updateSearch('');
                            provider.selectCategory('ALL');
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset All Filters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CivicColors.forest,
                            side: const BorderSide(color: CivicColors.forest),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: 195,
                  bottom: widget.embedded ? 24 : 96,
                  left: 16,
                  right: 16,
                ),
                itemCount: provider.problems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final problem = provider.problems[index];
                  return ProblemPreviewCard(
                    problem: problem,
                    onTrackProgress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProblemDetailScreen(
                            problem: problem,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
