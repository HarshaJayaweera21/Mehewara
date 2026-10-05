import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/reports/report_service.dart';

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(user: _user!, auth: _auth),
    );

    if (updated != null && mounted) {
      setState(() {
        _user = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile details updated successfully.'),
          backgroundColor: CivicColors.forest,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearSession();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: CivicColors.alabaster,
        body: Center(
          child: CircularProgressIndicator(color: CivicColors.forest),
        ),
      );
    }

    if (_errorMessage != null && _user == null) {
      return Scaffold(
        backgroundColor: CivicColors.alabaster,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined, size: 54, color: CivicColors.slateGreen),
                const SizedBox(height: 14),
                const Text(
                  'Could not load resident profile',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CivicColors.slateGreen),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loadProfileData,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          color: CivicColors.forest,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Card (Avatar, Name, Status Badge, Edit trigger)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CivicColors.mintTint,
                                    border: Border.all(
                                      color: CivicColors.mintPip.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: user.profilePhotoUrl != null &&
                                            user.profilePhotoUrl!.isNotEmpty
                                        ? Image.network(
                                            user.profilePhotoUrl!,
                                            width: 64,
                                            height: 64,
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
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: CivicColors.forest,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: CivicColors.charcoal,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
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
                                              'VERIFIED RESIDENT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: CivicColors.badgeResolvedText,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CivicColors.slateGreen,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _openEditModal,
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit details',
                              color: CivicColors.forest,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. CIVIC PARTICIPATION & ACTIVITY METRICS
                    const Text(
                      'CIVIC PARTICIPATION & ACTIVITY METRICS',
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
                              icon: Icons.assignment_outlined,
                              label: 'Total Incidents Reported',
                              value: '$_totalReports community reports submitted',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.pending_actions_outlined,
                              label: 'Active Dispatched Reports',
                              value: '$_activeReports in progress with response crews',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Resolved Municipal Issues',
                              value: '$_resolvedReports verified & resolved',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.workspace_premium_outlined,
                              label: 'Citizen Community Status',
                              value: _totalReports > 5
                                  ? 'Active Civic Champion'
                                  : (_totalReports > 0
                                      ? 'Active Community Contributor'
                                      : 'Registered Citizen Member'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 3. CONTACT INFORMATION & CREDENTIALS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CONTACT INFORMATION & CREDENTIALS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        InkWell(
                          onTap: _openEditModal,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CivicColors.forest,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildProfileRow(
                              icon: Icons.badge_outlined,
                              label: 'Full Registered Name',
                              value: user.name,
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.email_outlined,
                              label: 'Registered Email Address',
                              value: user.email,
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.phone_outlined,
                              label: 'Direct Mobile Contact',
                              value: user.phoneNumber?.isNotEmpty == true
                                  ? user.phoneNumber!
                                  : 'Not specified (Tap edit to add)',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.account_circle_outlined,
                              label: 'Municipal Portal Role',
                              value: (user.role ?? 'RESIDENT').toUpperCase(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. CIVIC PROFILE & MUNICIPAL WARD
                    const Text(
                      'CIVIC PROFILE & MUNICIPAL WARD',
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
                              icon: Icons.account_balance_outlined,
                              label: 'Assigned Municipal Council',
                              value: 'Colombo Municipal Council (CMC)',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.location_city_outlined,
                              label: 'Administrative District',
                              value: 'Colombo District — Western Province',
                            ),
                            const Divider(height: 18),
                            _buildProfileRow(
                              icon: Icons.map_outlined,
                              label: 'Residency Ward / Zone',
                              value: 'Ward 07 — Cinnamon Gardens (Central Colombo)',
                            ),
                            const Divider(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
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
                                          color: AppColors.textMuted,
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
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (user.id.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    tooltip: 'Copy ID',
                                    color: CivicColors.slateGreen,
                                    onPressed: () => _copyToClipboard(user.id, 'Citizen ID'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 5. CITIZEN SERVICES & CIVIC RIGHTS
                    const Text(
                      'CITIZEN SERVICES & CIVIC RIGHTS',
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in const [
                              'File road, drainage, electrical & waste incidents directly',
                              'Real-time municipal dispatch & field crew status tracking',
                              'AI-assisted severity classification & priority routing',
                              'Direct community resolution proof with photographic evidence',
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: CivicColors.mintPip,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
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

                    const SizedBox(height: 18),

                    // 6. Municipal Citizen Support Hotline
                    Card(
                      color: CivicColors.mintTint.withValues(alpha: 0.5),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.headset_mic_outlined,
                              size: 26,
                              color: CivicColors.forest,
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Colombo Municipal Council — Citizen Support',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: CivicColors.forest,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Toll-Free Civic Helpdesk: 1910 / Direct: +94 11 269 1111 (24/7)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: CivicColors.slateGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 7. Actions: Edit Details & Log Out
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openEditModal,
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Update Profile Details'),
                        style: FilledButton.styleFrom(
                          backgroundColor: CivicColors.forest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout,
                          size: 16,
                          color: AppColors.priorityCritical,
                        ),
                        label: const Text(
                          'Log Out / Switch Account',
                          style: TextStyle(
                            color: AppColors.priorityCritical,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.statusUnavailableBorder),
                          backgroundColor: AppColors.statusUnavailableBg,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(ResidentUser user) {
    return Container(
      color: CivicColors.mintTint,
      alignment: Alignment.center,
      child: Text(
        _initials(user.name),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: CivicColors.forest,
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
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
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rich bottom sheet enabling residents to update first name, last name, phone, and photo
class _EditProfileSheet extends StatefulWidget {
  final ResidentUser user;
  final AuthService auth;

  const _EditProfileSheet({required this.user, required this.auth});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;
  late ResidentUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _phone = TextEditingController(text: widget.user.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: CivicColors.forest),
              title: const Text('Choose photo from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: CivicColors.forest),
              title: const Text('Take a new photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_currentUser.profilePhotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.priorityCritical),
                title: const Text('Remove current photo', style: TextStyle(color: AppColors.priorityCritical)),
                onTap: () => Navigator.pop(ctx, null),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (source == null) {
      // Remove photo requested if it was on
      if (_currentUser.profilePhotoUrl != null) {
        setState(() => _uploadingPhoto = true);
        try {
          final updated = await widget.auth.removeProfilePhoto();
          if (mounted) {
            setState(() {
              _currentUser = updated;
              _uploadingPhoto = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
              _uploadingPhoto = false;
            });
          }
        }
      }
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingPhoto = true);
      final updated = await widget.auth.uploadProfilePhoto(picked.path);
      if (mounted) {
        setState(() {
          _currentUser = updated;
          _uploadingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to upload photo: $e';
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.auth.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phoneNumber: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profile Details',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: CivicColors.charcoal,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_currentUser),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Profile Photo Preview & Edit
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CivicColors.mintTint,
                        border: Border.all(
                          color: CivicColors.mintPip,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _uploadingPhoto
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                                : Center(
                                    child: Text(
                                      _initials(_currentUser.name),
                                      style: const TextStyle(
                                        fontSize: 26,
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
                      child: InkWell(
                        onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: CivicColors.forest,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // First Name
              TextFormField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'First name is required.' : null,
              ),

              const SizedBox(height: 12),

              // Last Name
              TextFormField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Last name is required.' : null,
              ),

              const SizedBox(height: 12),

              // Phone Number
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: '07X XXXXXXX',
                  filled: true,
                  fillColor: const Color(0xFFFAFCFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 8),

              // Read-only Email Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: CivicColors.slateGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email (${widget.user.email}) is linked to your civic identity and cannot be changed here.',
                        style: const TextStyle(fontSize: 11, color: CivicColors.slateGreen),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: CivicColors.badgeCriticalText,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: CivicColors.forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  final value = parts.map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'R' : value;
}
