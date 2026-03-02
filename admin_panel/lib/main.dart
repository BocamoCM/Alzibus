import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stops_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/users_screen.dart';
import 'screens/notices_admin_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'theme/admin_theme.dart';

void main() {
  runApp(const AlzibusAdminApp());
}

class AlzibusAdminApp extends StatefulWidget {
  const AlzibusAdminApp({super.key});

  @override
  State<AlzibusAdminApp> createState() => _AlzibusAdminAppState();
}

class _AlzibusAdminAppState extends State<AlzibusAdminApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alzibus Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.lightTheme,
      darkTheme: AdminTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: ApiService().isAuthenticated
          ? AdminHome(
              isDarkMode: _isDarkMode,
              onThemeToggle: _toggleTheme,
            )
          : LoginScreen(onLoginSuccess: () => setState(() {})),
    );
  }
}

class AdminHome extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const AdminHome({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  
  final List<NavigationItem> _navItems = [
    NavigationItem(icon: Icons.dashboard, label: 'Dashboard'),
    NavigationItem(icon: Icons.location_on, label: 'Paradas'),
    NavigationItem(icon: Icons.route, label: 'Rutas'),
    NavigationItem(icon: Icons.bar_chart, label: 'Estadísticas'),
    NavigationItem(icon: Icons.people, label: 'Usuarios'),
    NavigationItem(icon: Icons.campaign, label: 'Avisos'),
    NavigationItem(icon: Icons.settings, label: 'Configuración'),
    NavigationItem(icon: Icons.logout, label: 'Cerrar Sesión'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            extended: isWide,
            minExtendedWidth: 200,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (index == 7) {
                // Logout logic
                ApiService().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AlzibusAdminApp()),
                  (route) => false,
                );
              } else {
                setState(() => _selectedIndex = index);
              }
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  if (isWide) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Alzibus Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            destinations: _navItems.map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            )).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const StopsScreen();
      case 2:
        return const RoutesScreen();
      case 3:
        return const StatsScreen();
      case 4:
        return const UsersScreen();
      case 5:
        return const NoticesAdminScreen();
      case 6:
        return SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeToggle: widget.onThemeToggle,
        );
      case 7:
        // Logout handled in NavigationRail
        return const Center(child: CircularProgressIndicator());
      default:
        return const DashboardScreen();
    }
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  
  NavigationItem({required this.icon, required this.label});
}
