import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/user.dart';
import '../../../services/auth/auth_service.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  final _auth = AuthService();
  late Future<ResidentUser> _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.getCurrentUser();
  }

  Future<void> _refresh() async {
    setState(() {
      _user = _auth.getCurrentUser();
    });
    await _user;
  }

  Future<void> _edit(ResidentUser user) async {
    final result = await showModalBottomSheet<ResidentUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(user: user, auth: _auth),
    );
    if (result != null && mounted) {
      setState(() {
        _user = Future.value(result);
      });
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearSession();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: FutureBuilder<ResidentUser>(
                  future: _user,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: CivicColors.forest));
                    }
                    if (snapshot.hasError) {
                      return _ProfileMessage(error: snapshot.error.toString(), onRetry: _refresh);
                    }
                    final user = snapshot.data!;
                    return RefreshIndicator(
                      color: CivicColors.forest,
                      onRefresh: _refresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 24, wide ? 32 : 20, 32),
                        children: [
                          const Text('Your profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
                          const SizedBox(height: 5),
                          const Text('Manage the contact details on your account.', style: TextStyle(color: CivicColors.slateGreen)),
                          const SizedBox(height: 22),
                          _ProfileHeader(user: user, onEdit: () => _edit(user)),
                          const SizedBox(height: 16),
                          _ProfileDetails(user: user, onEdit: () => _edit(user)),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, color: CivicColors.forest),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'These are the account details currently available in Mehewara. Ward assignment and notification preferences are not managed here yet.',
                                      style: TextStyle(height: 1.4, color: CivicColors.slateGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(foregroundColor: CivicColors.badgeCriticalText, minimumSize: const Size.fromHeight(50)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onEdit});
  final ResidentUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
        color: CivicColors.forest,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: CivicColors.mintPip,
                child: Text(_initials(user.name), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CivicColors.forest)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty ? 'Resident' : user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(color: Color(0xFFD9EEE5))),
                    const SizedBox(height: 8),
                    const Text('Community member', style: TextStyle(fontSize: 12, color: Color(0xFFD9EEE5))),
                  ],
                ),
              ),
              IconButton(onPressed: onEdit, tooltip: 'Edit profile', color: Colors.white, icon: const Icon(Icons.edit_outlined)),
            ],
          ),
        ),
      );
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user, required this.onEdit});
  final ResidentUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Contact information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CivicColors.charcoal))),
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                ],
              ),
              _DetailRow(icon: Icons.person_outline_rounded, label: 'Name', value: user.name),
              const Divider(height: 22),
              _DetailRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
              const Divider(height: 22),
              _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phoneNumber?.isNotEmpty == true ? user.phoneNumber! : 'Not added'),
            ],
          ),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: CivicColors.forest, size: 20),
          const SizedBox(width: 12),
          SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 13, color: CivicColors.slateGreen))),
          Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600, color: CivicColors.charcoal))),
        ],
      );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user, required this.auth});
  final ResidentUser user;
  final AuthService auth;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final user = await widget.auth.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phoneNumber: _phone.text,
      );
      if (mounted) Navigator.of(context).pop(user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Edit contact details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
              const SizedBox(height: 18),
              TextFormField(controller: _firstName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _lastName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name'), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: CivicColors.badgeCriticalText)),
              ],
              const SizedBox(height: 18),
              FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save changes')),
            ],
          ),
        ),
      );

  String? _required(String? value) => value?.trim().isNotEmpty == true ? null : 'This field is required';
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 48, color: CivicColors.slateGreen),
              const SizedBox(height: 14),
              const Text('We could not load your profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: CivicColors.slateGreen)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  final value = parts.map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'R' : value;
}
