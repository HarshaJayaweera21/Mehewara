import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/crew_service.dart';
import '../../widgets/common/civic_bottom_nav_bar.dart';
import '../../widgets/common/civic_header.dart';
import 'home/crew_home_screen.dart';
import 'jobs/crew_jobs_screen.dart';
import 'profile/crew_profile_screen.dart';

class CrewShellScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const CrewShellScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<CrewShellScreen> createState() => _CrewShellScreenState();
}

class _CrewShellScreenState extends State<CrewShellScreen> {
  int _currentIndex = 0;
  final CrewService _crewService = CrewService();

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: CivicColors.forest),
            SizedBox(width: 8),
            Text(
              'Sign Out Crew?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of the municipal dispatch terminal? Your active session will be ended.',
          style: TextStyle(fontSize: 13, color: CivicColors.charcoal, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: CivicColors.slateGreen)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: CivicHeader(
        subtitle: 'Municipal Crew Dispatch Portal',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _confirmLogout();
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CivicColors.cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDCE5DF), width: 1.2),
                    boxShadow: const [CivicShadows.subtle],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      size: 17,
                      color: CivicColors.slateGreen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CrewHomeScreen(
            crewService: _crewService,
            onNavigateToJobs: () => setState(() => _currentIndex = 1),
          ),
          CrewJobsScreen(
            crewService: _crewService,
          ),
          CrewProfileScreen(
            crewService: _crewService,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: CivicBottomNavBar.crew(
        currentIndex: _currentIndex,
        onTabSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
