import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: CivicColors.forest, borderRadius: BorderRadius.circular(15)),
            alignment: Alignment.center,
            child: const Text('ම', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('මෙහෙවර', style: TextStyle(color: CivicColors.forest, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('MEHEWARA', style: TextStyle(color: CivicColors.slateGreen, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      );
}

class AuthInlineMessage extends StatelessWidget {
  const AuthInlineMessage({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? CivicColors.badgeCriticalBg : CivicColors.mintTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, size: 18, color: isError ? CivicColors.badgeCriticalText : CivicColors.forest),
            const SizedBox(width: 9),
            Expanded(child: Text(text, style: TextStyle(color: isError ? CivicColors.badgeCriticalText : CivicColors.forest, fontSize: 12, height: 1.35))),
          ],
        ),
      );
}
