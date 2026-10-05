import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import 'auth_view_model.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _viewModel = AuthViewModel();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    final lastName = parts.removeLast();
    final firstName = parts.join(' ');
    final role = await _viewModel.register(
      firstName: firstName,
      lastName: lastName,
      email: _email.text,
      password: _password.text,
      phoneNumber: _phone.text.isEmpty ? null : _phone.text,
    );
    if (!mounted || role == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      role.toUpperCase() == 'RESIDENT' ? AppRoutes.residentHome : AppRoutes.crewShell,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CivicColors.alabaster,
        appBar: AppBar(
          backgroundColor: CivicColors.alabaster,
          leading: IconButton(tooltip: 'Back to sign in', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    children: [
                      const AuthBrand(),
                      const SizedBox(height: 26),
                      Text('Create your account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: CivicColors.charcoal)),
                      const SizedBox(height: 6),
                      const Text('Use your account to submit reports and follow updates.', style: TextStyle(color: CivicColors.slateGreen, height: 1.45)),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _viewModel,
                        builder: (context, _) => _viewModel.error == null
                            ? const SizedBox.shrink()
                            : Padding(padding: const EdgeInsets.only(bottom: 16), child: AuthInlineMessage(text: _viewModel.error!, isError: true)),
                      ),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (value) => value == null || value.trim().split(RegExp(r'\s+')).length < 2 ? 'Enter your first and last name.' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address.' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(labelText: 'Phone number (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 6 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6 ? 'Use at least 6 characters.' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
                      ),
                      const SizedBox(height: 22),
                      AnimatedBuilder(
                        animation: _viewModel,
                        builder: (context, _) => SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _viewModel.isBusy ? null : _submit,
                            style: FilledButton.styleFrom(backgroundColor: CivicColors.forest, foregroundColor: Colors.white),
                            child: _viewModel.isBusy
                                ? const SizedBox.square(dimension: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Create account', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const AuthInlineMessage(text: 'Ward selection is not part of account registration yet.', isError: false),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?', style: TextStyle(color: CivicColors.slateGreen)),
                          TextButton(onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.login), child: const Text('Sign in', style: TextStyle(color: CivicColors.forest, fontWeight: FontWeight.w800))),
                        ],
                      ),
                      if (constraints.maxHeight > 760) const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
