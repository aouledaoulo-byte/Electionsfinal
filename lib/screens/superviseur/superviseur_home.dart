import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../login_screen.dart';
import 'dashboard_live.dart';
import 'dashboard_national.dart';
import 'validation_screen.dart';
import 'agents_screen.dart';
import 'anomalies_screen.dart';
import 'inscrits_screen.dart';
import 'saisie_manuelle_screen.dart';
import 'cartes_suivi_screen.dart';
import '../agent/messagerie_screen.dart';

class SuperviseurHome extends StatefulWidget {
  final AppUser user;
  const SuperviseurHome({super.key, required this.user});
  @override
  State<SuperviseurHome> createState() => _SuperviseurHomeState();
}

class _SuperviseurHomeState extends State<SuperviseurHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    final nb = widget.user.isSuperviseurNational ? 9 : 7;
    _tabs = TabController(length: nb, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isNational = widget.user.isSuperviseurNational;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.displayName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Live'),
            if (isNational)
              const Tab(icon: Icon(Icons.public, size: 18), text: 'National'),
            const Tab(icon: Icon(Icons.verified, size: 18), text: 'Validation'),
            if (isNational)
              const Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Saisie'),
            const Tab(icon: Icon(Icons.people, size: 18), text: 'Agents'),
            const Tab(icon: Icon(Icons.warning, size: 18), text: 'Anomalies'),
            const Tab(icon: Icon(Icons.credit_card, size: 18), text: 'Cartes'),
            const Tab(icon: Icon(Icons.list, size: 18), text: 'Bureaux'),
            const Tab(icon: Icon(Icons.message, size: 18), text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          DashboardLive(user: widget.user),
          if (isNational) DashboardNational(user: widget.user),
          ValidationScreen(user: widget.user),
          if (isNational) SaisieManuelleScreen(user: widget.user),
          AgentsScreen(user: widget.user),
          AnomaliesScreen(user: widget.user),
          CartesSuiviScreen(user: widget.user),
          InscritsScreen(user: widget.user),
          MessagerieScreen(user: widget.user),
        ],
      ),
    );
  }
}
