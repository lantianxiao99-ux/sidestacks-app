import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'stacks_hub_screen.dart';
import 'tax_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    StacksHubScreen(),
    TaxScreen(),
    AnalyticsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final picUrl = context.watch<AppProvider>().profilePictureUrl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens
              .asMap()
              .entries
              .map((e) => HeroMode(
                    enabled: e.key == _currentIndex,
                    child: e.value,
                  ))
              .toList(),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppTheme.of(context).border, width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'HOME',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.layers_outlined),
                activeIcon: Icon(Icons.layers),
                label: 'STACKS',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.calculate_outlined),
                activeIcon: Icon(Icons.calculate),
                label: 'ESTIMATES',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.rocket_launch_outlined),
                activeIcon: Icon(Icons.rocket_launch),
                label: 'INSIGHTS',
              ),
              BottomNavigationBarItem(
                icon: _AvatarNavIcon(picUrl: picUrl, active: false),
                activeIcon: _AvatarNavIcon(picUrl: picUrl, active: true),
                label: 'PROFILE',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar icon for bottom nav ───────────────────────────────────────────────

class _AvatarNavIcon extends StatelessWidget {
  final String? picUrl;
  final bool active;
  const _AvatarNavIcon({required this.picUrl, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppTheme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: picUrl != null
            ? Image.network(
                picUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppTheme.accentDim,
        child: const Center(
          child: Icon(Icons.person_outline, size: 15, color: AppTheme.accent),
        ),
      );
}
