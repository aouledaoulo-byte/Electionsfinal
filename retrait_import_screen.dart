import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _sb = Supabase.instance.client;

// ============================================================
//  SCREEN : Import CSV retraits cartes → Supabase
//  CSV format: code_centre,nom_centre,date,retraits,arrondissement
// ============================================================
class RetraitImportScreen extends StatefulWidget {
  const RetraitImportScreen({super.key});
  @override
  State<RetraitImportScreen> createState() => _RetraitImportScreenState();
}

class _RetraitImportScreenState extends State<RetraitImportScreen> {
  // ── State ──────────────────────────────────────────────────
  bool _loading = false;
  bool _importing = false;
  String? _fileName;
  List<Map<String, dynamic>> _preview = [];
  List<Map<String, dynamic>> _allRows = [];
  String _status = '';
  bool _statusOk = true;
  int _imported = 0;
  int _errors = 0;
  String _filterDate = '';
  List<String> _availableDates = [];
  String? _selectedDate;

  // ── KPIs Supabase ──────────────────────────────────────────
  Map<String, dynamic>? _kpiSupabase;

  @override
  void initState() {
    super.initState();
    _loadKpi();
  }

  Future<void> _loadKpi() async {
    try {
      final res = await _sb.from('v_retrait_par_date').select();
      final List rows = res as List;
      int total = 0;
      for (final r in rows) total += (r['total_retraits'] as num).toInt();
      setState(() => _kpiSupabase = {
        'total': total,
        'nb_jours': rows.length,
        'derniere_date': rows.isNotEmpty ? rows.last['date'] : '—',
      });
    } catch (_) {}
  }

  // ── Sélectionner CSV ───────────────────────────────────────
  Future<void> _pickFile() async {
    setState(() { _loading = true; _status = ''; _preview = []; _allRows = []; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() { _loading = false; _status = 'Aucun fichier sélectionné.'; _statusOk = false; });
        return;
      }
      final file = result.files.first;
      _fileName = file.name;
      final bytes = file.bytes!;
      final content = utf8.decode(bytes);
      _parseCSV(content);
    } catch (e) {
      setState(() { _status = 'Erreur lecture : $e'; _statusOk = false; });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _parseCSV(String content) {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) {
      setState(() { _status = 'Fichier vide.'; _statusOk = false; }); return;
    }

    // Detect separator
    final header = lines[0].trim();
    final sep = header.contains(';') ? ';' : ',';
    final cols = header.split(sep).map((c) => c.trim().toLowerCase()).toList();

    // Validate expected columns
    final expected = ['code_centre', 'nom_centre', 'date', 'retraits', 'arrondissement'];
    for (final e in expected) {
      if (!cols.contains(e)) {
        setState(() { _status = 'Colonne manquante : $e'; _statusOk = false; }); return;
      }
    }

    final rows = <Map<String, dynamic>>[];
    final dates = <String>{};
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final vals = line.split(sep);
      if (vals.length < cols.length) continue;
      final row = <String, dynamic>{};
      for (int j = 0; j < cols.length; j++) {
        row[cols[j]] = vals[j].trim().replaceAll('"', '');
      }
      // Parse retraits as int
      row['retraits'] = int.tryParse(row['retraits'].toString()) ?? 0;
      row['code_centre'] = int.tryParse(row['code_centre'].toString()) ?? 0;
      dates.add(row['date'].toString());
      rows.add(row);
    }

    final sortedDates = dates.toList()..sort();
    setState(() {
      _allRows = rows;
      _availableDates = sortedDates;
      _selectedDate = sortedDates.isNotEmpty ? sortedDates.last : null;
      _preview = _selectedDate != null
          ? rows.where((r) => r['date'] == _selectedDate).take(5).toList()
          : rows.take(5).toList();
      _status = '✅ ${rows.length} lignes lues · ${dates.length} jour(s)';
      _statusOk = true;
    });
  }

  void _updatePreview(String? date) {
    setState(() {
      _selectedDate = date;
      _preview = date != null
          ? _allRows.where((r) => r['date'] == date).take(5).toList()
          : _allRows.take(5).toList();
    });
  }

  // ── Importer vers Supabase ─────────────────────────────────
  Future<void> _importToSupabase() async {
    if (_allRows.isEmpty) return;

    final toImport = _selectedDate != null
        ? _allRows.where((r) => r['date'] == _selectedDate).toList()
        : _allRows;

    if (toImport.isEmpty) {
      setState(() { _status = 'Aucune ligne pour cette date.'; _statusOk = false; }); return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l\'import'),
        content: Text(
          'Importer ${toImport.length} ligne(s)'
          '${_selectedDate != null ? " du $_selectedDate" : " (toutes dates)"}?\n\n'
          'Les doublons (même centre + même date) seront remplacés.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: const Text('Importer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _importing = true; _imported = 0; _errors = 0; _status = 'Import en cours...'; });

    final prefs = await SharedPreferences.getInstance();
    final userNom = prefs.getString('user_nom') ?? 'superviseur';

    // Batch par 50
    const batchSize = 50;
    for (int i = 0; i < toImport.length; i += batchSize) {
      final batch = toImport.sublist(i, i + batchSize > toImport.length ? toImport.length : i + batchSize);
      try {
        await _sb.from('retrait_cartes').upsert(
          batch.map((r) => {
            'code_centre':    r['code_centre'],
            'nom_centre':     r['nom_centre'],
            'arrondissement': r['arrondissement'],
            'date':           r['date'],
            'retraits':       r['retraits'],
            'importe_par':    userNom,
          }).toList(),
          onConflict: 'code_centre,date',
        );
        setState(() => _imported += batch.length);
      } catch (e) {
        setState(() => _errors += batch.length);
      }
    }

    await _loadKpi();
    setState(() {
      _importing = false;
      _statusOk = _errors == 0;
      _status = _errors == 0
          ? '✅ $_imported lignes importées avec succès !'
          : '⚠️ $_imported importées · $_errors erreurs';
    });
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadKpi,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // En-tête
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: const Column(children: [
                Icon(Icons.upload_file, color: Colors.white, size: 36),
                SizedBox(height: 8),
                Text('IMPORT RETRAITS CARTES', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 4),
                Text('Importer CSV depuis Suivi-retrait → Supabase', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 14),

            // KPI Supabase actuel
            if (_kpiSupabase != null) _buildKpiCard(),
            const SizedBox(height: 12),

            // Format attendu
            _buildFormatCard(),
            const SizedBox(height: 14),

            // Bouton sélectionner
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _pickFile,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.folder_open, size: 20),
                label: Text(_loading ? 'Lecture...' : 'Sélectionner fichier CSV',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0d9488), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Center(child: Text('📄 $_fileName', style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ],
            const SizedBox(height: 12),

            // Statut parsing
            if (_status.isNotEmpty) _buildStatus(),

            // Sélection date + prévisualisation
            if (_allRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDateSelector(),
              const SizedBox(height: 10),
              _buildPreview(),
              const SizedBox(height: 14),

              // Bouton import
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _importing ? null : _importToSupabase,
                  icon: _importing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload, size: 22),
                  label: Text(
                    _importing
                        ? 'Import $_imported lignes...'
                        : _selectedDate != null
                            ? 'Importer $_selectedDate (${_allRows.where((r) => r["date"] == _selectedDate).length} lignes)'
                            : 'Importer tout (${_allRows.length} lignes)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: const Color(0xFF1565C0).withOpacity(0.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFf0fdf4), border: Border.all(color: const Color(0xFF86efac)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_done, color: Color(0xFF16a34a), size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Données dans Supabase', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF166534))),
          const SizedBox(height: 3),
          Text(
            '${_kpiSupabase!['total']} retraits · ${_kpiSupabase!['nb_jours']} jour(s) · Dernier : ${_kpiSupabase!['derniere_date']}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
          ),
        ])),
        IconButton(onPressed: _loadKpi, icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF16a34a))),
      ]),
    );
  }

  Widget _buildFormatCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Format CSV Suivi-retrait', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'code_centre,nom_centre,date,retraits,arrondissement\n'
          '1,PREFECTURE,31/03/2026,50,Arrondissement du Plateau\n'
          '2,ECOLE ZPS,31/03/2026,227,Arrondissement du Plateau',
          style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF86EFAC)),
        ),
      ]),
    );
  }

  Widget _buildStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _statusOk ? const Color(0xFFf0fdf4) : const Color(0xFFfff1f2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusOk ? const Color(0xFF86efac) : const Color(0xFFfca5a5)),
      ),
      child: Text(_status, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: _statusOk ? const Color(0xFF166534) : const Color(0xFF991b1b),
      )),
    );
  }

  Widget _buildDateSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SÉLECTIONNER LA DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6b7280), letterSpacing: 0.6)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFe5e7eb)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: _selectedDate,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: null, child: Text('Toutes les dates (${_allRows.length} lignes)')),
              ..._availableDates.map((d) => DropdownMenuItem(
                value: d,
                child: Text('$d  (${_allRows.where((r) => r["date"] == d).length} centres)'),
              )),
            ],
            onChanged: _updatePreview,
          ),
        ),
      ),
    ]);
  }

  Widget _buildPreview() {
    if (_preview.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('APERÇU (5 premières lignes)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6b7280), letterSpacing: 0.6)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFe5e7eb)),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
            ),
            child: const Row(children: [
              Expanded(flex: 3, child: Text('Centre', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
              SizedBox(width: 50, child: Text('Retraits', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ]),
          ),
          ..._preview.asMap().entries.map((e) {
            final row = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: e.key % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
              child: Row(children: [
                Expanded(flex: 3, child: Text(row['nom_centre']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text(row['date']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF6b7280)))),
                SizedBox(width: 50, child: Text(
                  row['retraits']?.toString() ?? '0',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16a34a)),
                  textAlign: TextAlign.right,
                )),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }
}
