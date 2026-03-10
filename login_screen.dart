import 'package:flutter/material.dart';
import '../services/services.dart';
import '../utils/constants.dart';
import 'agent/agent_home.dart';
import 'superviseur/superviseur_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _erreur;

  Future<void> _login() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _erreur = 'Veuillez saisir votre code');
      return;
    }
    setState(() { _loading = true; _erreur = null; });

    final user = await AuthService().loginWithCode(code);
    if (!mounted) return;
    setState(() => _loading = false);

    if (user == null) {
      setState(() => _erreur = 'Code invalide ou compte inactif');
      return;
    }

    if (user.role == AppRoles.agent) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgentHome()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperviseurHome()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.how_to_vote, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('ELECTION',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 4)),
                const SizedBox(height: 6),
                Text('Suivi électoral en temps réel',
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
                const SizedBox(height: 48),

                // Carte connexion
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Connexion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Code unique',
                            hintText: 'Ex: AGENT-001',
                            prefixIcon: const Icon(Icons.vpn_key),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            errorText: _erreur,
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 20),
                        _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _login,
                                icon: const Icon(Icons.login),
                                label: const Text('Se connecter',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('v1.0.0 · com.ynet.election',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
