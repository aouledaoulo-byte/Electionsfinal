class AppConstants {
  // 🔧 REMPLACEZ CES VALEURS par vos credentials Supabase
  static const String supabaseUrl = 'https://ktkjtcjmsuugogyejtwh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt0a2p0Y2ptc3V1Z29neWVqdHdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwOTY3OTYsImV4cCI6MjA4ODY3Mjc5Nn0.Hu6cWispUu13a68lH8MzzAiVAePbZjqREPfFVfzed-8';

  // Heures de vote
  static const int heureOuverture = 7;
  static const int heureFermeture = 18;

  // Couleurs
  static const int colorVert = 0xFF1B5E20;
  static const int colorVertClair = 0xFF4CAF50;
  static const int colorRouge = 0xFFB71C1C;
  static const int colorOrange = 0xFFE65100;
  static const int colorBleu = 0xFF0D47A1;

  // Seuils anomalies
  static const double seuilNulsWarning = 0.15;
  static const double seuilEcartLivePvWarning = 0.05;
  static const double seuilEcartLivePvCritique = 0.10;
}

class AppRoles {
  static const String agent = 'agent';
  static const String superviseurRegional = 'superviseur_regional';
  static const String superviseurNational = 'superviseur_national';
}

class PvStatut {
  static const String soumis = 'soumis';
  static const String valide = 'valide';
  static const String rejete = 'rejete';
}
