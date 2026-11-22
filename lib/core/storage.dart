// Stockage local : fichiers JSON pour les données et l'historique, et un
// « journal » dans SharedPreferences pour les actions faites depuis une
// notification pendant que l'application est fermée (autre isolate).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _journalPrefix = 'journal_';
final _rand = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';

class Storage {
  Directory? _dir;

  Future<Directory> _base() async =>
      _dir ??= await getApplicationSupportDirectory();

  Future<File> _file(String name) async => File('${(await _base()).path}/$name');

  Future<void> _writeAtomic(String name, String content) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(f.path);
  }

  Future<AppData> loadData() async {
    try {
      final f = await _file('data.json');
      if (!await f.exists()) return AppData();
      return AppData.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return AppData();
    }
  }

  Future<void> saveData(AppData d) =>
      _writeAtomic('data.json', jsonEncode(d.toJson()));

  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final f = await _file('history.json');
      if (!await f.exists()) return [];
      return (jsonDecode(await f.readAsString()) as List)
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> h) =>
      _writeAtomic('history.json', jsonEncode(h.map((e) => e.toJson()).toList()));

  // --- Journal (écrit par l'isolate de notification) ------------------------

  late final _prefs = SharedPreferencesAsync();

  Future<void> appendJournal(HistoryEntry e) =>
      _prefs.setString('$_journalPrefix${newId()}', jsonEncode(e.toJson()));

  /// Entrées du journal (clé -> entrée), sans les supprimer.
  Future<Map<String, HistoryEntry>> readJournal() async {
    final keys = await _prefs.getKeys();
    final out = <String, HistoryEntry>{};
    for (final k in keys.where((k) => k.startsWith(_journalPrefix))) {
      final s = await _prefs.getString(k);
      if (s == null) continue;
      try {
        out[k] = HistoryEntry.fromJson(jsonDecode(s));
      } catch (_) {}
    }
    return out;
  }

  Future<void> removeJournal(Iterable<String> keys) async {
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
