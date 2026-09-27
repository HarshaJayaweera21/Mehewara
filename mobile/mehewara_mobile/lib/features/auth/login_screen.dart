import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../services/crew_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'crew.drainage@mehewara.gov.lk');
  final _passwordController = TextEditingController(text: 'Crew@123');
  final _crewService = CrewService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin({String? email, String? password}) async {
    final loginEmail = email ?? _emailController.text.trim();
    final loginPass = password ?? _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _crewService.login(loginEmail, loginPass);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.crewShell);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryForest,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryForest.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'ම',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'මෙහෙවර • MEHEWARA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryForest,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Municipal Crew Dispatch Mobile Workspace',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusUnavailableBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.statusUnavailableBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.priorityCritical),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 12, color: AppColors.priorityCritical),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Manual Login Form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign In with Government Credentials',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Official Email',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, size: 18),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _handleLogin(),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Sign In as Crew Leader'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick One-Tap Presets for Evaluation
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'EVALUATION PRESETS (ONE-TAP)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _buildPresetButton(
                    title: '💧 Drainage Alpha (Sunil) — BUSY',
                    subtitle: 'Culvert & Stormwater • Has Active Mission',
                    email: 'crew.drainage@mehewara.gov.lk',
                  ),
                  const SizedBox(height: 8),
                  _buildPresetButton(
                    title: '🛣️ Road Bravo (Nimal) — AVAILABLE',
                    subtitle: 'Pavement & Asphalt Restoration • Standby',
                    email: 'crew.road@mehewara.gov.lk',
                  ),
                  const SizedBox(height: 8),
                  _buildPresetButton(
                    title: '🌿 Environment Echo (Kumara) — AVAILABLE',
                    subtitle: 'Arboricultural & Tree Clearance • Standby',
                    email: 'crew.environment@mehewara.gov.lk',
                  ),
                  const SizedBox(height: 8),
                  _buildPresetButton(
                    title: '⚡ Electrical Delta (Priya) — BUSY',
                    subtitle: 'Streetlight & Grid Maintenance • Busy',
                    email: 'crew.electrical@mehewara.gov.lk',
                  ),
                  const SizedBox(height: 8),
                  _buildPresetButton(
                    title: '🗑️ Waste Charlie (Amara) — AVAILABLE',
                    subtitle: 'Solid Waste & Heavy Clearing • Standby',
                    email: 'crew.waste@mehewara.gov.lk',
                  ),

                  const SizedBox(height: 20),

                  // Switch to Resident Mode (Member 1)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.residentHome);
                      },
                      icon: const Icon(Icons.person_pin_outlined, size: 16),
                      label: const Text('Switch to Resident Mode (Member 1)'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryForest,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String title,
    required String subtitle,
    required String email,
  }) {
    return InkWell(
      onTap: _isLoading ? null : () => _handleLogin(email: email, password: 'Crew@123'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
