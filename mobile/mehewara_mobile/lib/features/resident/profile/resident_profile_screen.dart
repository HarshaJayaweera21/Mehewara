import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/reports/report_service.dart';
import '../../auth/auth_widgets.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  final _auth = AuthService();
  final _reportService = ReportService();

  ResidentUser? _user;
  int _totalReports = 0;
  int _activeReports = 0;
  int _resolvedReports = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _auth.getCurrentUser();
      int total = 0;
      int active = 0;
      int resolved = 0;

      try {
        final reports = await _reportService.getMyReports();
        total = reports.length;
        active = reports
            .where((r) => {'PENDING', 'PROCESSING', 'ASSIGNED'}.contains(r.status.toUpperCase()))
            .length;
        resolved = reports.where((r) => r.status.toUpperCase() == 'RESOLVED').length;
      } catch (_) {
        // Fallback to zeroes if report service fails
      }

      if (mounted) {
        setState(() {
          _user = user;
          _totalReports = total;
          _activeReports = active;
          _resolvedReports = resolved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditModal() async {
    if (_user == null) return;
    final updated = await showModalBottomSheet<ResidentUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditProfileSheet(user: _user!, auth: _auth),
    );

    if (updated != null && mounted) {
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Profile details updated successfully.'),
            ],
          ),
          backgroundColor: CivicColors.forest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _logout() async {
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
          'Are you sure you want to sign out of your Mehewara resident account?',
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

    if (confirm == true && mounted) {
      await _auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'R';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildInitialsAvatar(ResidentUser user) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CivicColors.mintTint,
            Color(0xFFD6F0E3),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(user.name),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: CivicColors.forest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Row(
          children: [
            Text(
              'Resident Profile',
              style: TextStyle(
                color: CivicColors.forest,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadProfileData,
            icon: const Icon(Icons.refresh_rounded, color: CivicColors.forest),
            tooltip: 'Refresh Profile',
          ),
          if (_user != null)
            IconButton(
              onPressed: _openEditModal,
              icon: const Icon(Icons.edit_outlined, color: CivicColors.forest),
              tooltip: 'Edit Profile',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CivicAtmosphericBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: CivicColors.forest),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CivicSurfaceCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppColors.priorityCritical,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: CivicColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CivicColors.slateGreen,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadProfileData,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              style: FilledButton.styleFrom(
                                backgroundColor: CivicColors.forest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final user = _user!;

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: CivicColors.forest,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO PROFILE CARD
            CivicSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar with camera badge
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CivicColors.mintPip.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CivicColors.forest.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: user.profilePhotoUrl != null &&
                                  user.profilePhotoUrl!.isNotEmpty
                              ? Image.network(
                                  user.profilePhotoUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildInitialsAvatar(user),
                                )
                              : _buildInitialsAvatar(user),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _openEditModal,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CivicColors.forest,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Name, verified badge, and email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 18,
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
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: CivicColors.badgeResolvedBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CivicColors.badgeResolvedBorder,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: CivicColors.badgeResolvedText,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'VERIFIED CITIZEN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: CivicColors.badgeResolvedText,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: CivicColors.slateGreen,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Edit button
                  IconButton.filledTonal(
                    onPressed: _openEditModal,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit details',
                    style: IconButton.styleFrom(
                      backgroundColor: CivicColors.mintTint,
                      foregroundColor: CivicColors.forest,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. CIVIC ACTIVITY & METRICS GRID (Modern Stat Tiles)
            _buildSectionHeader(
              title: 'CIVIC PARTICIPATION & ACTIVITY',
              icon: Icons.analytics_outlined,
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Total Reports',
                    value: '$_totalReports',
                    subtitle: 'Incidents filed',
                    icon: Icons.assignment_outlined,
                    iconBg: CivicColors.mintTint,
                    iconColor: CivicColors.forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Dispatched',
                    value: '$_activeReports',
                    subtitle: 'Crew responding',
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
                    title: 'Resolved Issues',
                    value: '$_resolvedReports',
                    subtitle: 'Verified complete',
                    icon: Icons.check_circle_outline_rounded,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF166534),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Civic Tier',
                    value: _totalReports >= 5
                        ? 'Champion'
                        : (_totalReports > 0 ? 'Contributor' : 'Active'),
                    subtitle: 'Citizen Member',
                    icon: Icons.workspace_premium_outlined,
                    iconBg: CivicColors.mintTint,
                    iconColor: CivicColors.forest,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. CONTACT INFORMATION & CREDENTIALS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  title: 'CONTACT CREDENTIALS',
                  icon: Icons.badge_outlined,
                ),
                InkWell(
                  onTap: _openEditModal,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: CivicColors.forest,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            CivicSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  _buildProfileRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: user.name,
                  ),
                  const Divider(height: 22, color: Color(0xFFEBEFEA)),
                  _buildProfileRow(
                    icon: Icons.email_outlined,
                    label: 'Registered Email',
                    value: user.email,
                  ),
                  const Divider(height: 22, color: Color(0xFFEBEFEA)),
                  _buildProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Mobile Contact Number',
                    value: user.phoneNumber?.isNotEmpty == true
                        ? user.phoneNumber!
                        : 'Not specified (Tap edit to add)',
                    isMuted: user.phoneNumber?.isEmpty ?? true,
                  ),
                  const Divider(height: 22, color: Color(0xFFEBEFEA)),
                  _buildProfileRow(
                    icon: Icons.security_rounded,
                    label: 'System Access Role',
                    value: (user.role ?? 'RESIDENT').toUpperCase(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. CIVIC PROFILE & MUNICIPAL JURISDICTION
            _buildSectionHeader(
              title: 'CIVIC JURISDICTION & WARD',
              icon: Icons.account_balance_outlined,
            ),
            const SizedBox(height: 10),

            CivicSurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  _buildProfileRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Municipal Council',
                    value: 'Colombo Municipal Council (CMC)',
                  ),
                  const Divider(height: 22, color: Color(0xFFEBEFEA)),
                  _buildProfileRow(
                    icon: Icons.location_city_outlined,
                    label: 'Administrative District',
                    value: 'Western Province — Colombo District',
                  ),
                  const Divider(height: 22, color: Color(0xFFEBEFEA)),
                  _buildProfileRow(
                    icon: Icons.map_outlined,
                    label: 'Assigned Electoral Ward',
                    value: 'Ward 07 — Cinnamon Gardens (Central Colombo)',
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
                              'Citizen Portal ID',
                              style: TextStyle(
                                fontSize: 11,
                                color: CivicColors.slateGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.id.isNotEmpty
                                  ? (user.id.length > 22
                                      ? '${user.id.substring(0, 22)}...'
                                      : user.id)
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
                      if (user.id.isNotEmpty)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy ID',
                          style: IconButton.styleFrom(
                            backgroundColor: CivicColors.mintTint,
                            foregroundColor: CivicColors.forest,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _copyToClipboard(user.id, 'Citizen ID'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Municipal Citizen Support Hotline Banner
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
                          'Municipal Citizen Helpdesk',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: CivicColors.forest,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Toll-Free Hotline: 1910 • Office: +94 11 269 1111 (24/7)',
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

            // 6. Action Buttons: Update Details & Sign Out
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _openEditModal,
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text(
                  'Update Profile Details',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: CivicColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _logout,
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
    bool isMuted = false,
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
                style: TextStyle(
                  fontSize: 13,
                  color: isMuted ? AppColors.textMuted : CivicColors.charcoal,
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

/// Slide-up sheet to update resident names, phone number, and avatar photo
class _EditProfileSheet extends StatefulWidget {
  final ResidentUser user;
  final AuthService auth;

  const _EditProfileSheet({
    required this.user,
    required this.auth,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  final _picker = ImagePicker();

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _sheetError;
  late ResidentUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    final parts = _currentUser.name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts[0] : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _firstName = TextEditingController(text: first);
    _lastName = TextEditingController(text: last);
    _phone = TextEditingController(text: _currentUser.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _isUploadingPhoto = true;
        _sheetError = null;
      });

      final updated = await widget.auth.uploadProfilePhoto(picked);
      if (mounted) {
        setState(() {
          _currentUser = updated;
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sheetError = 'Photo upload failed: $e';
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    try {
      setState(() {
        _isUploadingPhoto = true;
        _sheetError = null;
      });
      final updated = await widget.auth.removeProfilePhoto();
      if (mounted) {
        setState(() {
          _currentUser = updated;
          _isUploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sheetError = 'Photo removal failed: $e';
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _saveDetails() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _sheetError = null;
    });

    try {
      final updated = await widget.auth.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phoneNumber: _phone.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sheetError = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: CivicColors.forest),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: CivicColors.forest),
                title: const Text('Take a Photo with Camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              if (_currentUser.profilePhotoUrl != null &&
                  _currentUser.profilePhotoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityCritical),
                  title: const Text(
                    'Remove Current Photo',
                    style: TextStyle(color: AppColors.priorityCritical),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'R';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              const Text(
                'Update Profile Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Keep your municipal contact information up to date.',
                style: TextStyle(fontSize: 12.5, color: CivicColors.slateGreen),
              ),
              const SizedBox(height: 18),

              // Inline error banner
              if (_sheetError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AuthInlineMessage(
                    text: _sheetError!,
                    isError: true,
                  ),
                ),

              // Avatar Editor
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CivicColors.mintPip.withValues(alpha: 0.5),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CivicColors.forest.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _isUploadingPhoto
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: CivicColors.forest,
                                ),
                              )
                            : (_currentUser.profilePhotoUrl != null &&
                                    _currentUser.profilePhotoUrl!.isNotEmpty
                                ? Image.network(
                                    _currentUser.profilePhotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        _initials(_currentUser.name),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: CivicColors.forest,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: CivicColors.mintTint,
                                    alignment: Alignment.center,
                                    child: Text(
                                      _initials(_currentUser.name),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: CivicColors.forest,
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CivicColors.forest,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: _isUploadingPhoto ? null : _showPhotoOptions,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text(
                    'Change Photo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: CivicColors.forest,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // First Name Field
              TextFormField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your first name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Last Name Field
              TextFormField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your last name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Phone Number Field
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+94 77 123 4567',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDE2DE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: CivicColors.forest, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: CivicColors.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
