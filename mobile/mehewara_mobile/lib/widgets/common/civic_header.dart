import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Reusable civic header widget used across all resident and crew screens.
/// Features the official Mehewara brand logo, Sinhala typography with fallbacks,
/// responsive back button detection, and pluggable action buttons.
class CivicHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Primary screen title (e.g. "Report Progress", "Resident Profile", "Mission Scope").
  /// If null, defaults to the official brand title "මෙහෙවර • MEHEWARA".
  final String? title;

  /// Subtitle displayed below the title or brand name.
  /// (e.g. "Incident #P-023", "Municipal Resident Portal", "Municipal Crew Dispatch Portal").
  final String? subtitle;

  /// Explicit override to show or hide the back button.
  /// If null, automatically inspects `ModalRoute.of(context)?.canPop ?? Navigator.of(context).canPop()`.
  final bool? showBackButton;

  /// Custom back button callback. Defaults to `Navigator.of(context).maybePop()`.
  final VoidCallback? onBackPressed;

  /// Action widgets aligned to the right (e.g. Refresh, Edit, Logout, Status badges).
  final List<Widget>? actions;

  /// Whether to display the Mehewara brand logo squircle. Defaults to true.
  final bool showBrandLogo;

  /// Custom background color. Defaults to `const Color(0xFFF4F7F4)`.
  final Color? backgroundColor;

  /// Whether to show the subtle bottom divider/border. Defaults to true.
  final bool showBottomBorder;

  /// Height of the interactive header content row (excluding status bar & extra top/bottom spacing).
  /// Defaults to 54.0.
  final double height;

  /// Extra breathing room above the header content, below the native status/notification bar.
  /// Ensures the header never collides with notches, punch holes, or dynamic islands.
  /// Defaults to 8.0.
  final double extraTopSpacing;

  /// Bottom padding below the header content before the bottom divider line.
  /// Defaults to 6.0.
  final double bottomSpacing;

  const CivicHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBackButton,
    this.onBackPressed,
    this.actions,
    this.showBrandLogo = true,
    this.backgroundColor,
    this.showBottomBorder = true,
    this.height = 54.0,
    this.extraTopSpacing = 8.0,
    this.bottomSpacing = 6.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(height + extraTopSpacing + bottomSpacing);

  @override
  Widget build(BuildContext context) {
    final modalRoute = ModalRoute.of(context);
    final canPop = showBackButton ?? (modalRoute?.canPop ?? Navigator.of(context).canPop());

    // Responsively obtain the native hardware/system notification bar height from the device.
    // viewPadding.top captures physical hardware insets (notch, punch hole, Dynamic Island) reliably.
    final mediaQuery = MediaQuery.of(context);
    final double statusBarHeight = mediaQuery.viewPadding.top > 0
        ? mediaQuery.viewPadding.top
        : mediaQuery.padding.top;

    final double extraBuffer = extraTopSpacing;
    final double totalTopInset = statusBarHeight + extraBuffer;
    final double totalHeaderHeight = height + totalTopInset + bottomSpacing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark notification bar icons on Android
        statusBarBrightness: Brightness.light,    // Dark notification bar text on iOS
        systemNavigationBarColor: Color(0xFFF4F7F4),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        height: totalHeaderHeight,
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFFF4F7F4),
          border: showBottomBorder
              ? const Border(
                  bottom: BorderSide(
                    color: Color(0x99DCE5DF),
                    width: 1.2,
                  ),
                )
              : null,
        ),
        padding: EdgeInsets.only(
          top: totalTopInset,
          left: 16,
          right: 16,
          bottom: bottomSpacing,
        ),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Responsive Circular Back Button (Shown when canPop is true)
              if (canPop) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (onBackPressed != null) {
                        onBackPressed!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: CivicColors.cardSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFDCE5DF),
                          width: 1.2,
                        ),
                        boxShadow: const [CivicShadows.subtle],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: CivicColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // 2. Mehewara Brand Logo Squircle
              if (showBrandLogo) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: CivicColors.forest,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [CivicShadows.subtle],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/mehewara-logo.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'ම',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          fontFamilyFallback: [
                            'Noto Sans Sinhala',
                            'Iskoola Pota',
                            'Segoe UI',
                            'sans-serif',
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // 3. Title & Subtitle Column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.charcoal,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle ?? 'මෙහෙවර • MEHEWARA',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: CivicColors.slateGreen,
                          letterSpacing: -0.1,
                          fontFamilyFallback: [
                            'Noto Sans Sinhala',
                            'Iskoola Pota',
                            'Segoe UI',
                            'sans-serif',
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const Text(
                        'මෙහෙවර • MEHEWARA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: CivicColors.forest,
                          letterSpacing: -0.2,
                          fontFamilyFallback: [
                            'Noto Sans Sinhala',
                            'Iskoola Pota',
                            'Segoe UI',
                            'sans-serif',
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle ?? 'Municipal Civic Portal',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: CivicColors.slateGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Trailing Actions Slot
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
