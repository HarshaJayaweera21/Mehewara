import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/crew_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primaryForest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'ම',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'මෙහෙවර • MEHEWARA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryForest,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Municipal Crew Dispatch Portal',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppColors.textSecondary),
            tooltip: 'Log out',
            onPressed: widget.onLogout,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Workload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
