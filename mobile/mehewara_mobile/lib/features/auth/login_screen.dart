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

  @override
  Widget build(BuildContext context) {
    return AuthWatermarkBackground(
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
                'Welcome back',
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
                'Sign in to report local issues and follow their progress.',
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

              // 4. Email Input
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email address',
                  hintText: 'name@example.com',
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    size: 20,
                    color: CivicColors.slateGreen,
                  ),
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
                ),
                validator: (value) =>
                    value == null || !value.contains('@') ? 'Enter a valid email address.' : null,
              ),
              const SizedBox(height: 14),

              // 5. Password Input
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: CivicColors.slateGreen,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: CivicColors.slateGreen,
                    ),
                  ),
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
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
              ),
              const SizedBox(height: 20),

              // 6. Primary Sign-in Button
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
                            'Sign in',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 8. Create account link
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'New to Mehewara? ',
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
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.register),
                    child: const Text(
                      'Create an account',
                      style: TextStyle(
                        color: CivicColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 9. Watermark Civic Footer
              const Text(
                'MUNICIPAL CIVIC OPERATIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CivicColors.subdued,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
