// État de l'application : données, historique, actions, sauvegarde.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'logic.dart';
import 'med_import.dart';
import 'models.dart';
import 'notifications.dart' as notifs;
import 'storage.dart';

class AppStore extends ChangeNotifier {
  AppStore({Storage? storage, this.scheduleNotifications = true})
      : storage = storage ?? Storage();

  final Storage storage;
  final bool scheduleNotifications;

  AppData data = AppData();
  List<HistoryEntry> history = [];
  bool loaded = false;

  /// Utilisé par les tests : données en mémoire uniquement.
  AppStore.memory(this.data, this.history)
      : storage = Storage(),
        scheduleNotifications = false,
        loaded = true;

  Future<void> load() async {
    data = await storage.loadData();
    history = await storage.loadHistory();
    loaded = true;
    await refresh(forceReschedule: true);
  }

  /// Intègre les actions faites depuis les notifications, marque les
  /// oublis, reprogramme si besoin.
  Future<void> refresh({bool forceReschedule = false}) async {
    var changed = false;
    if (scheduleNotifications) {
      final journal = await storage.readJournal();
      if (journal.isNotEmpty) {
        final entries = journal.values.toList()
          ..sort((a, b) => (a.actual ?? a.planned).compareTo(b.actual ?? b.planned));
        for (final e in entries) {
          _addDedup(e);
        }
        await storage.saveHistory(history);
        await storage.removeJournal(journal.keys);
        changed = true;
      }
    }
    final missed = sweepMissed(data, history, DateTime.now(), newId: newId);
    if (missed.isNotEmpty) {
      history.addAll(missed);
      changed = true;
      await _saveHistory();
    }
    if (changed || forceReschedule) await _reschedule();
    notifyListeners();
  }

  void _addDedup(HistoryEntry e) {
    if (history.any((h) => h.id == e.id)) return;
    if (e.status == HistoryStatus.pris &&
        history.any((h) => h.key == e.key && h.status == HistoryStatus.pris)) {
      return;
    }
    history.add(e);
  }

  Future<void> _saveData() async {
    if (scheduleNotifications) await storage.saveData(data);
  }

  Future<void> _saveHistory() async {
    if (scheduleNotifications) await storage.saveHistory(history);
  }

  Future<void> _reschedule() async {
    if (!scheduleNotifications) return;
    try {
      await notifs.scheduleAll(data, history);
    } catch (e) {
      debugPrint('Erreur de programmation : $e');
    }
  }

  // --- Profil / accueil -----------------------------------------------------

  Future<void> setProfile(String name, DateTime? birthDate,
      {String? doctorName, String? doctorEmail}) async {
    final old = data.profile;
    data.profile = Profile(
      name: name.trim(),
      birthDate: birthDate,
      doctorName: (doctorName ?? old.doctorName).trim(),
      doctorEmail: (doctorEmail ?? old.doctorEmail).trim(),
    );
    await _saveData();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    data.onboardingDone = true;
    await _saveData();
    await _reschedule();
    notifyListeners();
  }

  // --- Bibliothèque ---------------------------------------------------------

  Future<Medication> saveMed(Medication m) async {
    final i = data.meds.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      data.meds[i] = m;
    } else {
      data.meds.add(m);
    }
    data.meds.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _saveData();
    await _reschedule(); // le nom apparaît dans les notifications
    notifyListeners();
    return m;
  }

  List<Reminder> remindersOf(String medId) =>
      data.reminders.where((r) => r.medId == medId).toList();

  Future<void> deleteMed(String id) async {
    data.meds.removeWhere((m) => m.id == id);
    data.reminders.removeWhere((r) => r.medId == id);
    await _saveData();
    await _reschedule();
    notifyListeners();
  }

  // --- Rappels --------------------------------------------------------------

  Future<void> saveReminder(Reminder r) async {
    final i = data.reminders.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      data.reminders[i] = r;
    } else {
      data.reminders.add(r);
    }
    data.reminders.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    await _saveData();
    await _reschedule();
    notifyListeners();
  }

  int takeNid() => data.nextNid++;

  Future<void> deleteReminder(String id) async {
    data.reminders.removeWhere((r) => r.id == id);
    await _saveData();
    await _reschedule();
    notifyListeners();
  }

  // --- Import d'une liste --------------------------------------------------

  /// Crée (ou remplace) les médicaments et rappels du plan d'import, en une
  /// seule fois. Renvoie le nombre de médicaments ajoutés ou remplacés.
  Future<int> applyImport(ImportPlan plan, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final today = dateKey(at);
    var n = 0;
    for (final m in plan.toImport) {
      final Medication med;
      if (m.existing != null) {
        med = m.existing!;
        if (m.description.isNotEmpty) med.description = m.description;
        if (m.notes.isNotEmpty) med.notes = m.notes;
        if (m.reminders.isNotEmpty) data.reminders.removeWhere((r) => r.medId == med.id);
      } else {
        med = Medication(
          id: newId(),
          name: m.name,
          description: m.description,
          notes: m.notes,
          colorIndex: data.meds.length % 8,
          iconIndex: iconForUnit(m.reminders.isEmpty ? '' : m.reminders.first.unit),
        );
        data.meds.add(med);
      }
      for (final r in m.reminders) {
        data.reminders.add(Reminder(
          id: newId(),
          medId: med.id,
          type: ReminderType.daily,
          hour: r.hour,
          minute: r.minute,
          quantity: r.quantity,
          unit: r.unit,
          createdAt: at,
          nid: takeNid(),
          repeat: r.repeat,
          intervalDays: r.interval,
          startDate: r.interval > 1 ? today : null,
          weekdays: [...r.weekdays],
        ));
      }
      n++;
    }
    data.meds.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    data.reminders.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    await _saveData();
    await _reschedule();
    notifyListeners();
    return n;
  }

  // --- Prises ---------------------------------------------------------------

  HistoryEntry _entry(Occurrence o, HistoryStatus s, {DateTime? actual, DateTime? until}) =>
      HistoryEntry(
        id: newId(),
        reminderId: o.reminder.id,
        medId: o.reminder.medId,
        medName: o.medName,
        quantity: o.reminder.quantity,
        unit: o.reminder.unit,
        date: o.date,
        planned: o.planned,
        actual: actual,
        status: s,
        once: o.reminder.type == ReminderType.once,
        until: until,
      );

  Future<void> markTaken(Occurrence o, {DateTime? at}) async {
    // Une prise annule un éventuel « oublié ».
    history.removeWhere((h) => h.key == o.key && h.status == HistoryStatus.oublie);
    _addDedup(_entry(o, HistoryStatus.pris, actual: at ?? DateTime.now()));
    await _afterOccurrenceChange(o);
  }

  Future<void> undoTaken(Occurrence o) async {
    history.removeWhere((h) =>
        h.key == o.key &&
        (h.status == HistoryStatus.pris || h.status == HistoryStatus.oublie));
    await _afterOccurrenceChange(o);
  }

  Future<void> snooze(Occurrence o, Duration d) async {
    final now = DateTime.now();
    history.add(_entry(o, HistoryStatus.decale, actual: now, until: now.add(d)));
    await _afterOccurrenceChange(o);
  }

  Future<void> _afterOccurrenceChange(Occurrence o) async {
    await _saveHistory();
    if (scheduleNotifications) {
      await notifs.cancelOccurrence(o.reminder.nid, o.date);
    }
    await _reschedule();
    notifyListeners();
  }

  // --- Prises ponctuelles et corrections -----------------------------------

  /// Enregistre une prise faite hors rappel (date et heure au choix).
  Future<void> addManualIntake(Medication med, double quantity, String unit, DateTime at) async {
    final id = newId();
    history.add(HistoryEntry(
      id: id,
      reminderId: '$manualPrefix$id',
      medId: med.id,
      medName: med.name,
      quantity: quantity,
      unit: unit,
      date: dateKey(at),
      planned: at,
      actual: at,
      status: HistoryStatus.pris,
      once: true,
    ));
    await _saveHistory();
    notifyListeners();
  }

  /// Remplace une ligne d'historique (correction de l'heure, de la quantité,
  /// du statut...).
  Future<void> updateEntry(HistoryEntry e) async {
    final i = history.indexWhere((h) => h.id == e.id);
    if (i < 0) return;
    final old = history[i];
    history[i] = e;
    if (e.status == HistoryStatus.pris && !e.manual) {
      // Une prise confirmée remplace un « oublié » de la même occurrence.
      history.removeWhere((h) => h.id != e.id && h.key == e.key && h.status == HistoryStatus.oublie);
    }
    await _afterEntryChange(old);
  }

  Future<void> deleteEntry(HistoryEntry e) async {
    history.removeWhere((h) => h.id == e.id);
    await _afterEntryChange(e);
  }

  Future<void> _afterEntryChange(HistoryEntry e) async {
    await _saveHistory();
    // Les oublis peuvent réapparaître si une prise passée est supprimée.
    final missed = sweepMissed(data, history, DateTime.now(), newId: newId);
    if (missed.isNotEmpty) {
      history.addAll(missed);
      await _saveHistory();
    }
    if (!e.manual) await _reschedule();
    notifyListeners();
  }

  // --- Sauvegarde / restauration -------------------------------------------

  String exportBackup() => const JsonEncoder.withIndent(' ').convert({
        'app': 'rappel-medicaments',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': data.toJson(),
        'history': history.map((h) => h.toJson()).toList(),
      });

  /// Remplace toutes les données. Lève une [FormatException] si le fichier
  /// n'est pas une sauvegarde de l'application.
  Future<void> restoreBackup(String json) async {
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Fichier illisible');
    }
    if (j['app'] != 'rappel-medicaments' || j['data'] == null) {
      throw const FormatException('Ce fichier n\'est pas une sauvegarde de Tic-Tac Santé');
    }
    final newData = AppData.fromJson(Map<String, dynamic>.from(j['data']));
    final newHistory = ((j['history'] ?? []) as List)
        .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    newData.onboardingDone = true;
    final maxNid = newData.reminders.fold<int>(0, (m, r) => r.nid > m ? r.nid : m);
    if (newData.nextNid <= maxNid) newData.nextNid = maxNid + 1;
    data = newData;
    history = newHistory;
    await _saveData();
    await _saveHistory();
    await _reschedule();
    notifyListeners();
  }
}
