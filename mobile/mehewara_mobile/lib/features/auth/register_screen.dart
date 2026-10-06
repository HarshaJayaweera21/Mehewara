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

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color: CivicColors.slateGreen,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFAFCFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE4E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE4E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: CivicColors.forest,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthWatermarkBackground(
      topLeading: Tooltip(
        message: 'Back to sign in',
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: CivicColors.forest.withValues(alpha: 0.12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: CivicColors.charcoal,
              ),
            ),
          ),
        ),
      ),
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Mehewara Brand Header with Official Web Logo
              const AuthBrand(centered: true),
              const SizedBox(height: 24),

              // 2. Welcoming Title & Subtitle
              const Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CivicColors.charcoal,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join your community to report issues and track local improvements.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CivicColors.slateGreen,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // 3. Inline Error Banner
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) => _viewModel.error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AuthInlineMessage(
                          text: _viewModel.error!,
                          isError: true,
                        ),
                      ),
              ),

              // 4. Full Name
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _inputDecoration(
                  labelText: 'Full name',
                  hintText: 'e.g. Nimal Perera',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                validator: (value) => value == null ||
                        value.trim().split(RegExp(r'\s+')).length < 2
                    ? 'Enter your first and last name.'
                    : null,
              ),
              const SizedBox(height: 14),

              // 5. Email Address
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: _inputDecoration(
                  labelText: 'Email address',
                  hintText: 'name@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address.'
                    : null,
              ),
              const SizedBox(height: 14),

              // 6. Phone Number (Optional)
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: _inputDecoration(
                  labelText: 'Phone number (optional)',
                  hintText: '07X XXXXXXX',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 14),

              // 7. Password
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _inputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 6 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: CivicColors.slateGreen,
                    ),
                  ),
                ),
                validator: (value) =>
                    value == null || value.length < 6 ? 'Use at least 6 characters.' : null,
              ),
              const SizedBox(height: 14),

              // 8. Confirm Password
              TextFormField(
                controller: _confirmPassword,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _inputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icons.lock_reset_rounded,
                  suffixIcon: IconButton(
                    tooltip:
                        _obscureConfirm ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: CivicColors.slateGreen,
                    ),
                  ),
                ),
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match.' : null,
              ),
              const SizedBox(height: 22),

              // 9. Submit Button
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, _) => SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _viewModel.isBusy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: CivicColors.forest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _viewModel.isBusy
                        ? const SizedBox.square(
                            dimension: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 10. Secondary note
              const AuthInlineMessage(
                text: 'Ward selection will be available inside your profile settings.',
                isError: false,
              ),
              const SizedBox(height: 16),

              // 11. Already have an account link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: CivicColors.slateGreen,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.login),
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        color: CivicColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
