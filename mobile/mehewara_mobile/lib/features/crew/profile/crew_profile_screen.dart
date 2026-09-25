import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/token_storage.dart';
import '../../../models/crew_model.dart';
import '../../../services/crew_service.dart';
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
      if (mounted) {
        setState(() {
          _crew = crew;
          _userEmail = email;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryForest),
      );
    }

    final crew = _crew;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.softSage,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppColors.primaryForest,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (crew != null)
                          CrewStatusBadge(status: crew.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Operational Mandate Section
          if (crew?.description != null && crew!.description!.isNotEmpty) ...[
            const Text(
              'OPERATIONAL MANDATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  crew.description!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Crew Leader Profile Section
          const Text(
            'CREW LEADER CREDENTIALS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileRow(
                    icon: Icons.person_outline,
                    label: 'Crew Leader Name',
                    value: crew?.crewLeaderName ?? 'Municipal Supervisor',
                  ),
                  const Divider(height: 18),
                  _buildProfileRow(
                    icon: Icons.email_outlined,
                    label: 'Official Government Email',
                    value: _userEmail ?? 'crew.leader@mehewara.gov.lk',
                  ),
                  const Divider(height: 18),
                  _buildProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Field Dispatch Contact',
                    value: crew?.contactNumber ?? '+94 11 269 1111',
                  ),
                  const Divider(height: 18),
                  _buildProfileRow(
                    icon: Icons.category_outlined,
                    label: 'Squad Specialization',
                    value: '${crew?.crewType ?? "GENERAL"} Remediation',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Municipal Support Hotline
          Card(
            color: AppColors.softSage.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.headset_mic_outlined, size: 24, color: AppColors.primaryForest),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Municipal Operations Control Room',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryForest),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Depot Dispatch Hotline: +94 11 269 1111 (24/7)',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Logout Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await TokenStorage.clearSession();
                widget.onLogout();
              },
              icon: const Icon(Icons.logout, size: 16, color: AppColors.priorityCritical),
              label: const Text(
                'Log Out / Switch Account',
                style: TextStyle(color: AppColors.priorityCritical, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.statusUnavailableBorder),
                backgroundColor: AppColors.statusUnavailableBg,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
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
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
