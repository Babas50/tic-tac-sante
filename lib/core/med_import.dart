// Import d'une liste de médicaments depuis un tableau Excel (.xlsx) ou CSV.
//
// Le modèle à remplir (assets/import/modele-tic-tac-sante.xlsx) a une ligne
// de titres puis une ligne par médicament :
//   Médicament* | Description | Consigne | Heures de prise | Quantité | Unité | Fréquence
// Seul le nom est obligatoire. Les heures créent les rappels.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'logic.dart';
import 'models.dart';

/// Nom du fichier modèle, tel qu'enregistré ou envoyé.
const importTemplateName = 'modele-tic-tac-sante.xlsx';
const importTemplateAsset = 'assets/import/$importTemplateName';

/// Lignes d'exemple du modèle (nom, description, consigne, heures, unité,
/// fréquence) : ignorées si l'utilisateur les a laissées telles quelles.
/// Doit correspondre à tool/make_import_template.py.
const templateExamples = <List<String>>[
  ['Doliprane 1000 mg', 'Paracétamol, douleur', '3 maximum par jour, espacer de 6 heures', '08:00 ; 14:00 ; 20:00', 'comprimé', 'Tous les jours'],
  ['Kardégic 75', 'Aspirine, cœur', 'Pendant le repas', '12:30', 'sachet', 'Tous les jours'],
  ['Collyre', 'Yeux secs', '', '19:00', 'goutte', 'Tous les jours'],
  ['Vitamine D', '', 'Pendant un repas', '09:00', 'dose', 'Lundi'],
  ['Furosémide 40 mg', 'Diurétique', 'Le matin', '08:00', 'comprimé', '1 jour sur 2'],
  ['Spray nasal', '', 'Si besoin', '', '', ''],
];

String _exampleKey(List<String> f) => f.map(normalizeText).join('|');
final _exampleKeys = {for (final e in templateExamples) _exampleKey(e)};

// ---------------------------------------------------------------------------
// Lecture des fichiers
// ---------------------------------------------------------------------------

/// Une ligne lue dans le fichier, avec son numéro (comme dans Excel).
class RawRow {
  final int line;
  final List<String> cells;
  const RawRow(this.line, this.cells);
}

/// Lit un fichier .xlsx ou .csv. Lève une [FormatException] lisible si le
/// fichier ne peut pas être lu.
List<RawRow> readTable(Uint8List bytes, String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.xlsx') || _isZip(bytes)) return readXlsx(bytes);
  if (lower.endsWith('.xls')) {
    throw const FormatException(
        'Ancien format Excel (.xls). Dans Excel : Fichier, Enregistrer sous, choisissez « Classeur Excel (.xlsx) ».');
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    throw const FormatException(
        'Fichier Word. Copiez le tableau Word dans le modèle Excel, puis importez le fichier Excel.');
  }
  return readCsv(bytes);
}

bool _isZip(Uint8List b) => b.length > 4 && b[0] == 0x50 && b[1] == 0x4B;

/// Lecture CSV : séparateur « ; », « , » ou tabulation, guillemets, UTF-8 ou
/// Windows-1252 (ce qu'enregistre souvent Excel).
List<RawRow> readCsv(Uint8List bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    text = latin1.decode(bytes);
  }
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final sep = [';', '\t', ','].reduce((a, b) => a.allMatches(firstLine).length >= b.allMatches(firstLine).length ? a : b);
  final rows = <RawRow>[];
  var cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var line = 1;
  var rowLine = 1;
  void endCell() {
    cells.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (cells.any((c) => c.trim().isNotEmpty)) rows.add(RawRow(rowLine, cells));
    cells = <String>[];
    rowLine = line;
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        if (c == '\n') line++;
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == sep) {
      endCell();
    } else if (c == '\n') {
      line++;
      endRow();
    } else if (c != '\r') {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || cells.isNotEmpty) endRow();
  return rows;
}

/// Lecture .xlsx : onglet « Mes médicaments » s'il existe, sinon le premier.
List<RawRow> readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('Fichier Excel illisible.');
  }
  String? read(String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final wbXml = read('xl/workbook.xml');
  if (wbXml == null) throw const FormatException('Ce fichier n\'est pas un classeur Excel.');
  final wb = XmlDocument.parse(wbXml);
  final sheets = wb.findAllElements('sheet').toList();
  if (sheets.isEmpty) throw const FormatException('Le classeur ne contient aucun onglet.');
  final chosen = sheets.firstWhere(
      (s) => normalizeText(s.getAttribute('name') ?? '').contains('medicament'),
      orElse: () => sheets.first);
  final rid = chosen.attributes
          .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
          .firstOrNull
          ?.value ??
      '';

  var target = 'worksheets/sheet1.xml';
  final relsXml = read('xl/_rels/workbook.xml.rels');
  if (relsXml != null && rid.isNotEmpty) {
    for (final r in XmlDocument.parse(relsXml).findAllElements('Relationship')) {
      if (r.getAttribute('Id') == rid) target = r.getAttribute('Target') ?? target;
    }
  }
  final sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final sheetXml = read(sheetPath);
  if (sheetXml == null) throw const FormatException('Onglet introuvable dans le classeur.');

  final shared = <String>[];
  final ssXml = read('xl/sharedStrings.xml');
  if (ssXml != null) {
    for (final si in XmlDocument.parse(ssXml).findAllElements('si')) {
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  final rows = <RawRow>[];
  for (final row in XmlDocument.parse(sheetXml).findAllElements('row')) {
    final line = int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1;
    final cells = <String>[];
    for (final c in row.findElements('c')) {
      final col = _colIndex(c.getAttribute('r') ?? '') ?? cells.length;
      while (cells.length < col) {
        cells.add('');
      }
      final type = c.getAttribute('t');
      String v;
      if (type == 'inlineStr') {
        v = c.findAllElements('t').map((t) => t.innerText).join();
      } else {
        final raw = c.getElement('v')?.innerText ?? '';
        if (type == 's') {
          final i = int.tryParse(raw);
          v = (i != null && i < shared.length) ? shared[i] : '';
        } else {
          v = raw;
        }
      }
      if (cells.length == col) {
        cells.add(v);
      } else {
        cells[col] = v;
      }
    }
    if (cells.any((c) => c.trim().isNotEmpty)) rows.add(RawRow(line, cells));
  }
  return rows;
}

int? _colIndex(String ref) {
  final m = RegExp(r'^([A-Z]+)').firstMatch(ref);
  if (m == null) return null;
  var n = 0;
  for (final ch in m.group(1)!.codeUnits) {
    n = n * 26 + (ch - 64);
  }
  return n - 1;
}

// ---------------------------------------------------------------------------
// Interprétation des cellules
// ---------------------------------------------------------------------------

/// Minuscules sans accents, pour comparer et rechercher.
String normalizeText(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

enum _Col { name, description, notes, times, quantity, unit, frequency }

_Col? _headerCol(String h) {
  final n = normalizeText(h);
  if (n.isEmpty) return null;
  if (n.startsWith('medicament') || n == 'nom') return _Col.name;
  if (n.startsWith('description') || n.startsWith('descriptif')) return _Col.description;
  if (n.startsWith('consigne') || n.startsWith('note')) return _Col.notes;
  if (n.startsWith('heure')) return _Col.times;
  if (n.startsWith('quantite') || n.startsWith('dose')) return _Col.quantity;
  if (n.startsWith('unite')) return _Col.unit;
  if (n.startsWith('frequence')) return _Col.frequency;
  return null;
}

/// Heures : « 08:00 ; 20:00 », « 8h, 20h30 », « 8 h 30 et 20 h ». Une heure
/// saisie dans une cellule Excel au format heure arrive en fraction de jour.
/// Renvoie null si une des heures n'est pas comprise.
List<(int, int)>? parseTimes(String s) {
  final t = s.trim();
  if (t.isEmpty) return [];
  final frac = double.tryParse(t);
  if (frac != null && frac >= 0 && frac < 1 && t.contains('.')) {
    final mins = (frac * 24 * 60).round() % (24 * 60);
    return [(mins ~/ 60, mins % 60)];
  }
  final out = <(int, int)>[];
  for (final part in t.split(RegExp(r'[;,/\n+]|\s+et\s+|\s+-\s+|\s{2,}'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    final m = RegExp(r'^(\d{1,2})\s*(?:[hH:.]\s*(\d{2})?)?$').firstMatch(p);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2) ?? '0');
    if (h > 23 || mi > 59) return null;
    if (!out.contains((h, mi))) out.add((h, mi));
  }
  out.sort((a, b) => (a.$1 * 60 + a.$2).compareTo(b.$1 * 60 + b.$2));
  return out;
}

/// Quantité : « 1 », « 0,5 », « 1.5 », « 1/2 », « ½ », « 1 ½ ». Vide = 1.
double? parseQuantity(String s) {
  var t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return 1;
  double extra = 0;
  for (final (sym, v) in [('½', 0.5), ('¼', 0.25), ('¾', 0.75)]) {
    if (t.contains(sym)) {
      extra = v;
      t = t.replaceAll(sym, '').trim();
    }
  }
  double? q;
  if (t.isEmpty) {
    q = 0;
  } else if (RegExp(r'^\d+\s*/\s*\d+$').hasMatch(t)) {
    final p = t.split('/');
    final d = double.parse(p[1]);
    q = d == 0 ? null : double.parse(p[0]) / d;
  } else {
    q = double.tryParse(t);
  }
  if (q == null) return null;
  final r = q + extra;
  if (r <= 0 || r > 100) return null;
  return r;
}

/// Fréquence : vide ou « tous les jours » ; « 1 jour sur N » ou « tous les N
/// jours » ; ou une liste de jours (« Lundi, Jeudi »). Null si incomprise.
({Recurrence repeat, int interval, List<int> weekdays})? parseFrequency(String s) {
  final n = normalizeText(s);
  if (n.isEmpty || n == 'tous les jours' || n == 'chaque jour' || n == 'quotidien' || n == 'quotidienne' || n == '1 jour sur 1') {
    return (repeat: Recurrence.interval, interval: 1, weekdays: const <int>[]);
  }
  final m = RegExp(r'^(?:1|un) jours? sur (\d+)$').firstMatch(n) ?? RegExp(r'^tous les (\d+) jours$').firstMatch(n);
  if (m != null) {
    final k = int.parse(m.group(1)!);
    if (k < 1 || k > 365) return null;
    return (repeat: Recurrence.interval, interval: k, weekdays: const <int>[]);
  }
  const prefixes = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
  final days = <int>[];
  for (final w in n.split(RegExp(r'[\s,;/]+|\bet\b'))) {
    final t = w.trim();
    if (t.isEmpty || t == 'le' || t == 'les' || t == 'chaque') continue;
    final i = prefixes.indexWhere((p) => t.startsWith(p));
    if (i < 0) return null;
    if (!days.contains(i + 1)) days.add(i + 1);
  }
  if (days.isEmpty) return null;
  days.sort();
  if (days.length == 7) return (repeat: Recurrence.interval, interval: 1, weekdays: const <int>[]);
  return (repeat: Recurrence.weekdays, interval: 1, weekdays: days);
}

// ---------------------------------------------------------------------------
// Plan d'import
// ---------------------------------------------------------------------------

enum RowStatus { ready, incomplete, ignored, existing }

/// Rappel à créer.
class ReminderSpec {
  final int hour, minute;
  final double quantity;
  final String unit;
  final Recurrence repeat;
  final int interval;
  final List<int> weekdays;
  const ReminderSpec(this.hour, this.minute, this.quantity, this.unit, this.repeat, this.interval, this.weekdays);
}

/// Résultat pour une ligne du fichier.
class ImportRow {
  final int line;
  final String name;
  RowStatus status;
  final String message; // problème rencontré, vide si aucun
  final String summary; // « 1 comprimé à 08:00, tous les jours »
  ImportRow(this.line, this.name, this.status, this.message, this.summary);
}

/// Médicament à créer ou à mettre à jour (plusieurs lignes peuvent porter le
/// même nom : leurs rappels s'ajoutent).
class ImportMed {
  final String name;
  String description = '';
  String notes = '';
  final List<ReminderSpec> reminders = [];
  final List<ImportRow> rows = [];
  final Medication? existing;

  /// Pour un médicament déjà présent : remplacer par la version du fichier.
  bool replace = false;
  ImportMed(this.name, this.existing);

  bool get willImport => existing == null || replace;
}

class ImportPlan {
  final List<ImportRow> rows;
  final List<ImportMed> meds;
  ImportPlan(this.rows, this.meds);

  int count(RowStatus s) => rows.where((r) => r.status == s).length;
  List<ImportMed> get toImport => meds.where((m) => m.willImport).toList();
  int get reminderCount => toImport.fold(0, (n, m) => n + m.reminders.length);
  bool get headerMissing => rows.isEmpty;
}

String _frequencyText(Recurrence r, int interval, List<int> days) {
  if (r == Recurrence.weekdays) {
    final names = days.map((d) => weekdayLong[d - 1]).join(', ');
    return 'le ${names.replaceFirst(RegExp(r', (?=[^,]*$)'), ' et ')}';
  }
  return interval <= 1 ? 'tous les jours' : '1 jour sur $interval';
}

/// Analyse les lignes lues et prépare l'import, sans rien enregistrer.
ImportPlan buildImportPlan(List<RawRow> raw, List<Medication> existing) {
  // Ligne de titres : la première dont une cellule commence par « Médicament ».
  var start = 0;
  var cols = {for (final c in _Col.values) c: c.index};
  for (var i = 0; i < raw.length && i < 10; i++) {
    final found = <_Col, int>{};
    for (var j = 0; j < raw[i].cells.length; j++) {
      final c = _headerCol(raw[i].cells[j]);
      if (c != null && !found.containsKey(c)) found[c] = j;
    }
    if (found.containsKey(_Col.name)) {
      cols = found;
      start = i + 1;
      break;
    }
  }

  final byName = <String, ImportMed>{};
  final rows = <ImportRow>[];
  for (final r in raw.skip(start)) {
    String cell(_Col c) {
      final j = cols[c];
      if (j == null || j >= r.cells.length) return '';
      return r.cells[j].trim();
    }

    final name = cell(_Col.name).replaceAll(RegExp(r'\s+'), ' ');
    final desc = cell(_Col.description);
    final notes = cell(_Col.notes);
    final timesTxt = cell(_Col.times);
    final qtyTxt = cell(_Col.quantity);
    final unitTxt = cell(_Col.unit);
    final freqTxt = cell(_Col.frequency);
    if ([name, desc, notes, timesTxt, qtyTxt, unitTxt, freqTxt].every((v) => v.isEmpty)) continue;

    if (name.isEmpty) {
      rows.add(ImportRow(r.line, '(nom vide)', RowStatus.ignored,
          'Il manque le nom du médicament. Cette ligne ne sera pas importée.', ''));
      continue;
    }
    if (_exampleKeys.contains(_exampleKey([name, desc, notes, timesTxt, unitTxt, freqTxt]))) {
      rows.add(ImportRow(r.line, name, RowStatus.ignored,
          'Exemple du modèle, laissé tel quel : ligne ignorée.', ''));
      continue;
    }

    final key = normalizeText(name);
    final ex = existing.where((m) => normalizeText(m.name) == key).firstOrNull;
    final med = byName.putIfAbsent(key, () => ImportMed(ex?.name ?? name, ex));
    if (med.description.isEmpty) med.description = desc;
    if (med.notes.isEmpty) med.notes = notes;

    final problems = <String>[];
    final times = parseTimes(timesTxt);
    final qty = parseQuantity(qtyTxt);
    final freq = parseFrequency(freqTxt);
    if (times == null) problems.add('Heure « $timesTxt » non comprise. Écrivez par exemple 08:00 ; 20:00.');
    if (qty == null) problems.add('Quantité « $qtyTxt » non comprise. Écrivez un chiffre, par exemple 1 ou 0,5.');
    if (freq == null) {
      problems.add('Fréquence « $freqTxt » non comprise. Écrivez « Tous les jours », « 1 jour sur 2 » ou des jours (Lundi, Jeudi).');
    }
    final unit = unitTxt.isEmpty ? 'comprimé' : unitTxt.toLowerCase();

    String summary;
    if (problems.isEmpty && times!.isNotEmpty) {
      for (final (h, m) in times) {
        med.reminders.add(ReminderSpec(h, m, qty!, unit, freq!.repeat, freq.interval, freq.weekdays));
      }
      final hs = times.map((t) => hmOf(t.$1, t.$2)).toList();
      final at = hs.length == 1 ? hs.first : '${hs.sublist(0, hs.length - 1).join(', ')} et ${hs.last}';
      summary = '${formatQuantity(qty!, unit)} à $at, ${_frequencyText(freq!.repeat, freq.interval, freq.weekdays)}';
    } else {
      summary = 'Sans rappel';
    }

    final status = ex != null
        ? RowStatus.existing
        : problems.isNotEmpty
            ? RowStatus.incomplete
            : RowStatus.ready;
    final msg = problems.isEmpty
        ? ''
        : '${problems.join(' ')} Le médicament sera ajouté sans ce rappel, à compléter ensuite.';
    final row = ImportRow(r.line, med.name, status, msg, summary);
    med.rows.add(row);
    rows.add(row);
  }
  return ImportPlan(rows, byName.values.toList());
}

/// Forme proposée selon l'unité (index dans medIcons).
int iconForUnit(String unit) => switch (normalizeText(unit)) {
      'goutte' => 2,
      'ml' || 'cuillere' || 'sachet' => 1,
      'injection' => 3,
      'bouffee' || 'inhalation' => 4,
      'patch' || 'application' => 5,
      _ => 0,
    };
