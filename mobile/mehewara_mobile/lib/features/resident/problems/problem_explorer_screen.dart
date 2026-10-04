import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common/civic_bottom_nav_bar.dart';
import '../../../widgets/problems/category_filter_bar.dart';
import '../../../widgets/problems/problem_pin_marker.dart';
import '../../../widgets/problems/problem_preview_card.dart';
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
            backgroundColor: CivicColors.alabaster,
            body: SafeArea(
              child: Stack(
                children: [
                  // 1. MAIN BACKGROUND: MAP VIEW OR LIST VIEW
                  Positioned.fill(
                    child: provider.viewMode == ExplorerViewMode.map
                        ? _buildMapView(provider)
                        : _buildListView(provider),
                  ),

                  // 2. TOP HEADER SECTION (Z-INDEX OVER MAP)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopHeaderSection(provider),
                  ),

                  // 3. FLOATING BOTTOM CARD (When Map Mode is active and problem selected)
                  if (provider.viewMode == ExplorerViewMode.map &&
                      provider.selectedProblem != null)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: widget.embedded ? 14 : 74, // Above the bottom nav bar
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

                  // 4. BOTTOM NAVIGATION BAR
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
        color: CivicColors.alabaster.withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: Color(0x99DDE2DE), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. App Bar Row
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Center(
              child: Text(
                'Community Incidents',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: CivicColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CivicColors.borderSubtle, width: 1),
                boxShadow: const [CivicShadows.subtle],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: CivicColors.slateGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: provider.updateSearch,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CivicColors.charcoal,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search problems or locations...',
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
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CivicColors.borderSubtle.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Map View Button
                      _buildSegmentButton(
                        icon: Icons.map_outlined,
                        label: 'Map View',
                        isActive: provider.viewMode == ExplorerViewMode.map,
                        onTap: () => provider.setViewMode(ExplorerViewMode.map),
                      ),
                      const SizedBox(width: 2),
                      // List View Button
                      _buildSegmentButton(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'List (${provider.problems.length})',
                        isActive: provider.viewMode == ExplorerViewMode.list,
                        onTap: () => provider.setViewMode(ExplorerViewMode.list),
                      ),
                    ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? CivicColors.cardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive ? [CivicShadows.subtle] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? CivicColors.forest : CivicColors.slateGreen,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
            // OpenStreetMap Standard Tiles (100% Free, Zero API Keys, Full Color)
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
                      onTap: () => provider.selectProblem(problem),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Floating Map Utility Controls (Upper-Right)
        Positioned(
          top: 175,
          right: 12,
          child: Column(
            children: [
              // Recenter GPS Button
              _buildMapControlBtn(
                icon: Icons.my_location_rounded,
                onTap: provider.recenterToUser,
                iconColor: CivicColors.charcoal,
                isLoading: provider.isLocatingUser,
              ),
              const SizedBox(height: 8),
              // Zoom In / Out Group
              Container(
                decoration: BoxDecoration(
                  color: CivicColors.cardSurface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CivicColors.borderSubtle, width: 1),
                  boxShadow: const [CivicShadows.subtle],
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: provider.zoomIn,
                      child: const SizedBox(
                        width: 36,
                        height: 32,
                        child: Center(
                          child: Icon(Icons.add, size: 18, color: CivicColors.charcoal),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: CivicColors.borderSubtle),
                    InkWell(
                      onTap: provider.zoomOut,
                      child: const SizedBox(
                        width: 36,
                        height: 32,
                        child: Center(
                          child: Icon(Icons.remove, size: 18, color: CivicColors.charcoal),
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
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: CivicColors.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CivicColors.borderSubtle, width: 1),
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
              padding: EdgeInsets.zero,
              icon: Icon(icon, size: 18, color: iconColor),
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

    if (provider.problems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: CivicColors.slateGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'No active incidents in this area',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: CivicColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Category: ${provider.selectedCategory}',
              style: const TextStyle(fontSize: 13, color: CivicColors.subdued),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 175, bottom: 90, left: 16, right: 16),
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
    );
  }


}
