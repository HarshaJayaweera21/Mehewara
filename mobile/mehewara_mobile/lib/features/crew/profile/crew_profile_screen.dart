import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/crew_model.dart';
import '../../../services/crew_service.dart';
import '../../auth/auth_widgets.dart';
import '../widgets/crew_status_badge.dart';

class CrewProfileScreen extends StatefulWidget {
  final CrewService crewService;
  final VoidCallback onLogout;

  const CrewProfileScreen({
    super.key,
    required this.crewService,
    required this.onLogout,
  });

  @override
  State<CrewProfileScreen> createState() => _CrewProfileScreenState();
}

class _CrewProfileScreenState extends State<CrewProfileScreen> {
  CrewModel? _crew;
  String? _userEmail;
  int _completedCount = 0;
  int _activeCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final crew = await widget.crewService.getCrewProfile();
      final email = await TokenStorage.getEmail();
      int completed = 0;
      int active = 0;
      try {
        final orders = await widget.crewService.getCrewWorkOrders();
        completed = orders.where((o) => o.isCompleted).length;
        active = orders.where((o) => o.isActive).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _crew = crew;
          _userEmail = email;
          _completedCount = completed;
          _activeCount = active;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getCrewEquipmentSpecs(String? crewType) {
    switch ((crewType ?? '').toUpperCase()) {
      case 'DRAINAGE':
        return {
          'depot': 'Central Colombo Depot — Ward 07 (Cinnamon Gardens)',
          'vehicle': 'Heavy Jetting Unit WP-LB-4091',
          'members': '6 Certified Field Specialists',
          'equipment': [
            'High-Pressure Sewer Jetter (250 bar)',
            'Submersible Trash Pump (4-inch)',
            'Atmospheric Gas Detection Monitors',
            'Trench Shoring Safety Apparatus',
          ],
        };
      case 'ROAD':
        return {
          'depot': 'Central Colombo Depot — Ward 03 (Kollupitiya)',
          'vehicle': 'Asphalt Patching Truck WP-GA-8112',
          'members': '5 Pavement Engineers & Laborers',
          'equipment': [
            'Dual-Drum Vibratory Asphalt Compactor',
            'Infrared Pavement Joint Heater',
            'Pneumatic Jackhammers & Cutters',
            'Solar Traffic Diversion Arrow Rig',
          ],
        };
      case 'WASTE':
        return {
          'depot': 'North Colombo Depot — Ward 12 (Kotahena)',
          'vehicle': 'Hydraulic Compactor WP-NA-2234',
          'members': '4 Sanitation Specialists',
          'equipment': [
            'Hydraulic Waste Compactor Unit',
            'Dual-Bin Mechanical Lifter',
            'Chemical Spill Containment Barrier',
            'High-Pressure Biohazard Rig',
          ],
        };
      case 'ELECTRICAL':
        return {
          'depot': 'Central Colombo Depot — Ward 05 (Havelock Town)',
          'vehicle': 'Insulated Aerial Boom Lift WP-QA-5067',
          'members': '4 High-Voltage Linesmen',
          'equipment': [
            '14m Insulated Cherry Picker Bucket',
            '1000V Rated Dielectric Hand Tools',
            'Digital Illumination Lux Meter',
            'Emergency Grid Generator (15 kVA)',
          ],
        };
      case 'ENVIRONMENT':
        return {
          'depot': 'South Colombo Depot — Ward 06 (Wellawatte)',
          'vehicle': 'Arboricultural Flatbed WP-LA-3389',
          'members': '5 Certified Tree Specialists',
          'equipment': [
            'Hydraulic Heavy Wood Chipper',
            'Commercial Rigging Chainsaws',
            'Friction Rigging Blocks & Harnesses',
            'Knuckle-Boom Debris Loader',
          ],
        };
      default:
        return {
          'depot': 'Central Colombo Municipal Depot',
          'vehicle': 'Municipal Operations Unit',
          'members': '4 Municipal Specialists',
          'equipment': ['Standard Municipal Remediation Toolset'],
        };
    }
  }

  IconData _getSquadIcon(String? crewType) {
    switch ((crewType ?? '').toUpperCase()) {
      case 'DRAINAGE':
        return Icons.water_drop_outlined;
      case 'ROAD':
        return Icons.construction_outlined;
      case 'WASTE':
        return Icons.delete_sweep_outlined;
      case 'ELECTRICAL':
        return Icons.electric_bolt_outlined;
      case 'ENVIRONMENT':
        return Icons.park_outlined;
      default:
        return Icons.groups_outlined;
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.priorityCritical),
            SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of the crew leader portal?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: CivicColors.slateGreen)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.priorityCritical,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TokenStorage.clearSession();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CivicAtmosphericBackground(
        child: Center(
          child: CircularProgressIndicator(color: CivicColors.forest),
        ),
      );
    }

    final crew = _crew;
    final specs = _getCrewEquipmentSpecs(crew?.crewType);
    final squadIcon = _getSquadIcon(crew?.crewType);

    return CivicAtmosphericBackground(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        color: CivicColors.forest,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO SQUAD CARD
              CivicSurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            CivicColors.mintTint,
                            Color(0xFFD6F0E3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CivicColors.mintPip.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CivicColors.forest.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        squadIcon,
                        color: CivicColors.forest,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crew?.name ?? 'Municipal Operations Crew',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.charcoal,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: CivicColors.mintTint,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: CivicColors.mintPip.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${crew?.crewType ?? "GENERAL"} SQUAD',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: CivicColors.forest,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (crew != null) CrewStatusBadge(status: crew.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Leader: ${crew?.crewLeaderName ?? "Municipal Supervisor"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CivicColors.slateGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. SQUAD TELEMETRY & PERFORMANCE METRICS (2x2 Grid)
              _buildSectionHeader(
                title: 'SQUAD DEPLOYMENT & METRICS',
                icon: Icons.analytics_outlined,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Completed',
                      value: '$_completedCount',
                      subtitle: 'Work orders resolved',
                      icon: Icons.check_circle_outline_rounded,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Active Tasks',
                      value: '$_activeCount',
                      subtitle: 'Field tasks assigned',
                      icon: Icons.pending_actions_outlined,
                      iconBg: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFC2410C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Field Headcount',
                      value: '${specs['members'].toString().split(' ').first} Staff',
                      subtitle: 'Certified Specialists',
                      icon: Icons.groups_outlined,
                      iconBg: CivicColors.mintTint,
                      iconColor: CivicColors.forest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      title: 'Squad Status',
                      value: crew?.isAvailable == true
                          ? 'Available'
                          : (crew?.isBusy == true ? 'On Field' : 'Standby'),
                      subtitle: crew?.isAvailable == true
                          ? 'Ready for dispatch'
                          : (crew?.isBusy == true ? 'Mission active' : 'Depot standby'),
                      icon: Icons.radio_button_checked_rounded,
                      iconBg: crew?.isAvailable == true
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFF7ED),
                      iconColor: crew?.isAvailable == true
                          ? const Color(0xFF166534)
                          : const Color(0xFFC2410C),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. OPERATIONAL MANDATE
              if (crew?.description != null && crew!.description!.isNotEmpty) ...[
                _buildSectionHeader(
                  title: 'OPERATIONAL MANDATE',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 10),
                CivicSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: CivicColors.mintTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.format_quote_rounded,
                          size: 20,
                          color: CivicColors.forest,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          crew.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CivicColors.charcoal,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 4. CREW LEADER CREDENTIALS
              _buildSectionHeader(
                title: 'CREW LEADER CREDENTIALS',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 10),

              CivicSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    _buildProfileRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Crew Leader Name',
                      value: crew?.crewLeaderName ?? 'Municipal Supervisor',
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.email_outlined,
                      label: 'Official Government Email',
                      value: _userEmail ?? 'crew.leader@mehewara.gov.lk',
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.phone_outlined,
                      label: 'Field Dispatch Contact',
                      value: crew?.contactNumber ?? '+94 11 269 1111',
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.category_outlined,
                      label: 'Squad Specialization',
                      value: '${crew?.crewType ?? "GENERAL"} Remediation Squad',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. SQUAD TELEMETRY & SPECIFICATIONS
              _buildSectionHeader(
                title: 'SQUAD TELEMETRY & SPECIFICATIONS',
                icon: Icons.settings_suggest_outlined,
              ),
              const SizedBox(height: 10),

              CivicSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    _buildProfileRow(
                      icon: Icons.business_outlined,
                      label: 'Assigned Depot / Ward',
                      value: specs['depot'] as String,
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Vehicle Fleet Unit ID',
                      value: specs['vehicle'] as String,
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.groups_outlined,
                      label: 'Squad Roster Headcount',
                      value: specs['members'] as String,
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    _buildProfileRow(
                      icon: Icons.phone_in_talk_outlined,
                      label: 'Emergency Dispatch Contact Line',
                      value: crew?.contactNumber ?? '+94 11 269 1111',
                    ),
                    const Divider(height: 22, color: Color(0xFFEBEFEA)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CivicColors.mintTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 18,
                            color: CivicColors.forest,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Municipal Registry ID',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: CivicColors.slateGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                crew != null && crew.id.isNotEmpty
                                    ? (crew.id.length > 22
                                        ? '${crew.id.substring(0, 22)}...'
                                        : crew.id)
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CivicColors.charcoal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (crew != null && crew.id.isNotEmpty)
                          IconButton.filledTonal(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy ID',
                            style: IconButton.styleFrom(
                              backgroundColor: CivicColors.mintTint,
                              foregroundColor: CivicColors.forest,
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => _copyToClipboard(crew.id, 'Registry ID'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 6. CERTIFIED HEAVY MACHINERY & EQUIPMENT
              _buildSectionHeader(
                title: 'CERTIFIED EQUIPMENT & HEAVY MACHINERY',
                icon: Icons.hardware_outlined,
              ),
              const SizedBox(height: 10),

              CivicSurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in ((specs['equipment'] as List<String>?) ?? []))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: CivicColors.badgeResolvedBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: CivicColors.badgeResolvedText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: CivicColors.charcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 7. MUNICIPAL OPERATIONS CONTROL ROOM HOTLINE
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEBF6F0), Color(0xFFF3FAF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: CivicColors.mintPip.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CivicColors.forest.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.headset_mic_rounded,
                        size: 24,
                        color: CivicColors.forest,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Municipal Operations Control Room',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: CivicColors.forest,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Depot Dispatch Hotline: +94 11 269 1111 (24/7)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: CivicColors.slateGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 8. LOGOUT ACTION
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.priorityCritical,
                  ),
                  label: const Text(
                    'Sign Out / Switch Account',
                    style: TextStyle(
                      color: AppColors.priorityCritical,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFFCA5A5),
                      width: 1.2,
                    ),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CivicColors.forest),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: CivicColors.slateGreen,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return CivicSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: value.length > 7 ? 16 : 22,
                  fontWeight: FontWeight.w900,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: CivicColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: CivicColors.slateGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CivicColors.mintTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: CivicColors.forest),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: CivicColors.slateGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: CivicColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
