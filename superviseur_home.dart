import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../utils/constants.dart';
import '../login_screen.dart';
import 'dashboard_national.dart';
import 'dashboard_live.dart';
import 'validation_screen.dart';
import 'anomalies_screen.dart';

class SuperviseurHome extends StatefulWidget {
  const SuperviseurHome({super.key});
  @override
  State<SuperviseurHome> createState() => _SuperviseurHomeState();
}

class _SuperviseurHomeState extends State<SuperviseurHome> {
  int _page = 0;
  String _nom = '', _role = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = AuthService();
    final nom  = await auth.getUserNom();
    final role = await auth.getUserRole();
    setState(() {
      _nom  = nom ?? '';
      _role = role ?? '';
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  final _pages = const [
    DashboardNational(),
    DashboardLive(),
    ValidationScreen(),
    AnomaliesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isNational = _role == AppRoles.superviseurNational;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNational ? 'Dashboard National' : 'Dashboard Régional'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text(_nom,
                style: const TextStyle(fontSize: 13, color: Colors.white70))),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _pages[_page],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Résultats'),
          NavigationDestination(icon: Icon(Icons.access_time), label: 'LIVE'),
          NavigationDestination(icon: Icon(Icons.fact_check), label: 'Validation'),
          NavigationDestination(icon: Icon(Icons.warning), label: 'Anomalies'),
        ],
      ),
    );
  }
}
