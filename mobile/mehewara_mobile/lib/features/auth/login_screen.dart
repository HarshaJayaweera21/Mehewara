import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'auth_view_model.dart';
import 'auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _viewModel = AuthViewModel();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final role = await _viewModel.signIn(_email.text, _password.text);
    if (!mounted || role == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      role.toUpperCase() == 'RESIDENT' ? AppRoutes.residentHome : AppRoutes.crewShell,
      (_) => false,
    );
  }

  void _selectStaffPreset(String email) {
    _email.text = email;
    _password.text = 'Crew@123';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CivicColors.alabaster,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  children: [
                    const AuthBrand(),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: CivicColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to report local issues and follow their progress.',
                      style: TextStyle(color: CivicColors.slateGreen, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, _) => _viewModel.error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AuthInlineMessage(text: _viewModel.error!, isError: true),
                            ),
                    ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@') ? 'Enter a valid email address.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, _) => SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _viewModel.isBusy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: CivicColors.forest,
                            foregroundColor: Colors.white,
                          ),
                          child: _viewModel.isBusy
                              ? const SizedBox.square(
                                  dimension: 21,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const AuthInlineMessage(
                      text: 'Google sign-in is not connected in this app yet.',
                      isError: false,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('New to Mehewara? ', style: TextStyle(color: CivicColors.slateGreen)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                          child: const Text(
                            'Create an account',
                            style: TextStyle(color: CivicColors.forest, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StaffAccess(onPresetSelected: _selectStaffPreset),
                    if (constraints.maxHeight > 760) const SizedBox(height: 22),
                    const Text(
                      'MEHEWARA • COMMUNITY WORKS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CivicColors.subdued,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffAccess extends StatelessWidget {
  const _StaffAccess({required this.onPresetSelected});

  final ValueChanged<String> onPresetSelected;

  static const _presets = <(String, String, String)>[
    ('Drainage crew', 'Culvert & stormwater response', 'crew.drainage@mehewara.gov.lk'),
    ('Road crew', 'Pavement & asphalt restoration', 'crew.road@mehewara.gov.lk'),
    ('Environment crew', 'Tree and pathway maintenance', 'crew.environment@mehewara.gov.lk'),
    ('Electrical crew', 'Streetlight & grid maintenance', 'crew.electrical@mehewara.gov.lk'),
    ('Waste crew', 'Solid waste response', 'crew.waste@mehewara.gov.lk'),
  ];

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        leading: const Icon(Icons.badge_outlined, color: CivicColors.slateGreen),
        title: const Text('Municipal staff sign-in',
            style: TextStyle(fontWeight: FontWeight.w700, color: CivicColors.charcoal)),
        subtitle: const Text('Crew workspace and evaluation accounts',
            style: TextStyle(fontSize: 12, color: CivicColors.slateGreen)),
        children: [
          for (final preset in _presets)
            ListTile(
              dense: true,
              leading: const Icon(Icons.engineering_outlined, color: CivicColors.forest),
              title: Text(preset.$1),
              subtitle: Text(preset.$2),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => onPresetSelected(preset.$3),
            ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Evaluation shortcuts use the crew demo password. Use Sign in above for other accounts.',
              style: TextStyle(fontSize: 11, color: CivicColors.slateGreen),
            ),
          ),
        ],
      );
}
