import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable civic brand header with official Mehewara logo and Sinhala title
class AuthBrand extends StatelessWidget {
  final bool centered;

  const AuthBrand({super.key, this.centered = false});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: CivicColors.forest.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CivicColors.forest.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/mehewara-logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: CivicColors.forest,
                alignment: Alignment.center,
                child: const Text(
                  'ම',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'මෙහෙවර',
              style: TextStyle(
                color: CivicColors.forest,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'MEHEWARA • CIVIC PORTAL',
              style: TextStyle(
                color: CivicColors.slateGreen,
                fontSize: 10.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );

    if (centered) {
      return Center(child: content);
    }
    return content;
  }
}

/// Status / alert banner used inside auth forms
class AuthInlineMessage extends StatelessWidget {
  const AuthInlineMessage({
    super.key,
    required this.text,
    required this.isError,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isError ? CivicColors.badgeCriticalBg : CivicColors.mintTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? CivicColors.badgeCriticalBorder
                : CivicColors.mintPip.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 18,
              color: isError ? CivicColors.badgeCriticalText : CivicColors.forest,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isError ? CivicColors.badgeCriticalText : CivicColors.forest,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

/// A welcoming, greenish watermark background wrapper that keeps forms centered
class AuthWatermarkBackground extends StatelessWidget {
  final Widget child;
  final Widget? topLeading;

  const AuthWatermarkBackground({
    super.key,
    required this.child,
    this.topLeading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Soft atmospheric base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3F8F4), // Fresh soft mint-tinted alabaster
                  Color(0xFFF7FAF7),
                  Color(0xFFEBF4EE), // Gentle pale sage in bottom corner
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // 2. Ambient artistic glow orbs
          Positioned(
            top: -120,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      CivicColors.mintPip.withValues(alpha: 0.18),
                      CivicColors.mintPip.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      CivicColors.forest.withValues(alpha: 0.12),
                      CivicColors.forest.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Welcoming Greenish Watermark (Oversized logo + concentric civic rings)
          Positioned(
            right: -60,
            top: 60,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -math.pi / 24,
                child: Opacity(
                  opacity: 0.042,
                  child: Image.asset(
                    'assets/images/mehewara-logo.png',
                    width: 380,
                    height: 380,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 40,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: math.pi / 18,
                child: Opacity(
                  opacity: 0.035,
                  child: Image.asset(
                    'assets/images/mehewara-logo.png',
                    width: 340,
                    height: 340,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          // 4. Subtle decorative geometric watermark ring
          Positioned(
            right: 80,
            top: 140,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CivicColors.forest.withValues(alpha: 0.035),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // 5. Main content canvas with vertical & horizontal centering
          SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Top leading navigation item if provided (e.g. back button)
                if (topLeading != null)
                  Positioned(
                    top: 8,
                    left: 12,
                    child: topLeading!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Elevated civic card wrapper for auth forms
class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDFE6E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: CivicColors.forest.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 14),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: child,
    );
  }
}
