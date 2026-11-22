// Logique pure (sans Flutter) : occurrences, statuts, statistiques, planning
// des notifications. Testée dans test/logic_test.dart.

import 'dart:convert';

import 'models.dart';

/// Délai après lequel une prise sans réponse est notée « oubliée ».
const missedAfter = Duration(hours: 3);

/// Délai de la relance automatique si aucune réponse.
const relanceAfter = Duration(minutes: 15);

/// Une prise est « à l'heure » si elle a lieu dans cet écart.
const onTimeTolerance = Duration(minutes: 30);

String two(int n) => n.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime parseDateKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String hmOf(int h, int m) => '${two(h)}:${two(m)}';

/// Numéro de jour depuis l'époque (indépendant de l'heure d'été).
int epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

// ---------------------------------------------------------------------------
// Quantités
// ---------------------------------------------------------------------------

const units = <String>[
  'comprimé',
  'gélule',
  'goutte',
  'ml',
  'sachet',
  'cuillère',
  'bouffée',
  'dose',
  'injection',
  'patch',
  'application',
];

/// Pas du bouton +/- selon l'unité.
double quantityStep(String unit) =>
    (unit == 'comprimé' || unit == 'cuillère') ? 0.25 : 1;

String formatNumber(double q) {
  final whole = q.floor();
  final frac = q - whole;
  String f = '';
  if ((frac - 0.25).abs() < 0.01) f = '¼';
  if ((frac - 0.5).abs() < 0.01) f = '½';
  if ((frac - 0.75).abs() < 0.01) f = '¾';
  if (f.isEmpty) {
    if (frac.abs() < 0.01) return '$whole';
    return q.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
  }
  return whole == 0 ? f : '$whole $f';
}

String unitLabel(String unit, double q) {
  if (q <= 1 || unit == 'ml') return unit;
  if (unit.endsWith('s') || unit.endsWith('x')) return unit;
  return '${unit}s';
}

String formatQuantity(double q, String unit) =>
    '${formatNumber(q)} ${unitLabel(unit, q)}';

// ---------------------------------------------------------------------------
// Moments de la journée
// ---------------------------------------------------------------------------

enum Moment { matin, midi, apresMidi, soir, nuit }

Moment momentOf(int hour) {
  if (hour >= 5 && hour < 11) return Moment.matin;
  if (hour >= 11 && hour < 14) return Moment.midi;
  if (hour >= 14 && hour < 18) return Moment.apresMidi;
  if (hour >= 18 && hour < 22) return Moment.soir;
  return Moment.nuit;
}

String momentLabel(Moment m) => switch (m) {
      Moment.matin => 'Matin',
      Moment.midi => 'Midi',
      Moment.apresMidi => 'Après-midi',
      Moment.soir => 'Soir',
      Moment.nuit => 'Nuit',
    };

// ---------------------------------------------------------------------------
// Occurrences
// ---------------------------------------------------------------------------

class Occurrence {
  final Reminder reminder;
  final Medication? med;
  final String date;
  final DateTime planned;
  Occurrence(this.reminder, this.med, this.date, this.planned);
  String get key => occurrenceKey(reminder.id, date);
  String get medName => med?.name ?? 'Médicament supprimé';
}

DateTime plannedFor(Reminder r, String date) {
  final d = parseDateKey(date);
  return DateTime(d.year, d.month, d.day, r.hour, r.minute);
}

/// Occurrences d'un rappel pour un jour donné (0 ou 1).
Occurrence? occurrenceOn(AppData data, Reminder r, DateTime day) {
  if (!r.active) return null;
  final dk = dateKey(day);
  if (r.type == ReminderType.once) {
    if (r.date != dk) return null;
  } else {
    final planned = plannedFor(r, dk);
    // Un rappel quotidien commence à partir de sa création.
    if (planned.isBefore(r.createdAt.subtract(const Duration(minutes: 1)))) {
      return null;
    }
  }
  return Occurrence(r, data.med(r.medId), dk, plannedFor(r, dk));
}

List<Occurrence> occurrencesOn(AppData data, DateTime day) {
  final list = <Occurrence>[];
  for (final r in data.reminders) {
    final o = occurrenceOn(data, r, day);
    if (o != null) list.add(o);
  }
  list.sort((a, b) => a.planned.compareTo(b.planned));
  return list;
}

Map<String, List<HistoryEntry>> indexHistory(List<HistoryEntry> history) {
  final map = <String, List<HistoryEntry>>{};
  for (final h in history) {
    map.putIfAbsent(h.key, () => []).add(h);
  }
  return map;
}

enum OccStatus { upcoming, snoozed, due, taken, missed }

class OccState {
  final OccStatus status;
  final DateTime? takenAt;
  final DateTime? snoozedUntil;
  final int snoozeCount;
  const OccState(this.status,
      {this.takenAt, this.snoozedUntil, this.snoozeCount = 0});
}

OccState stateOf(Occurrence o, Map<String, List<HistoryEntry>> idx, DateTime now) {
  final entries = idx[o.key] ?? const <HistoryEntry>[];
  HistoryEntry? taken;
  HistoryEntry? lastSnooze;
  var missed = false;
  var snoozes = 0;
  for (final e in entries) {
    switch (e.status) {
      case HistoryStatus.pris:
        taken = e;
      case HistoryStatus.oublie:
        missed = true;
      case HistoryStatus.decale:
        snoozes++;
        if (lastSnooze == null ||
            (e.actual ?? e.planned).isAfter(lastSnooze.actual ?? lastSnooze.planned)) {
          lastSnooze = e;
        }
    }
  }
  if (taken != null) {
    return OccState(OccStatus.taken, takenAt: taken.actual, snoozeCount: snoozes);
  }
  if (missed) return OccState(OccStatus.missed, snoozeCount: snoozes);
  final until = lastSnooze?.until;
  final effective = until ?? o.planned;
  if (now.isBefore(effective)) {
    return OccState(until != null ? OccStatus.snoozed : OccStatus.upcoming,
        snoozedUntil: until, snoozeCount: snoozes);
  }
  if (now.isBefore(effective.add(missedAfter))) {
    return OccState(OccStatus.due, snoozedUntil: until, snoozeCount: snoozes);
  }
  return OccState(OccStatus.missed, snoozeCount: snoozes);
}

/// Crée les lignes « oublié » pour les prises restées sans réponse.
List<HistoryEntry> sweepMissed(
    AppData data, List<HistoryEntry> history, DateTime now,
    {int days = 31, required String Function() newId}) {
  final idx = indexHistory(history);
  final result = <HistoryEntry>[];
  final today = dayOnly(now);
  for (var i = days; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    for (final o in occurrencesOn(data, day)) {
      final entries = idx[o.key] ?? const [];
      if (entries.any((e) =>
          e.status == HistoryStatus.pris || e.status == HistoryStatus.oublie)) {
        continue;
      }
      if (stateOf(o, idx, now).status == OccStatus.missed) {
        result.add(HistoryEntry(
          id: newId(),
          reminderId: o.reminder.id,
          medId: o.reminder.medId,
          medName: o.medName,
          quantity: o.reminder.quantity,
          unit: o.reminder.unit,
          date: o.date,
          planned: o.planned,
          status: HistoryStatus.oublie,
          once: o.reminder.type == ReminderType.once,
        ));
      }
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Planning des notifications
// ---------------------------------------------------------------------------

const windowEndNotificationId = 1;
const testNotificationId = 2;

int mainNotifId(int nid, String date) =>
    nid * 100 + (epochDay(parseDateKey(date)) % 30) * 2;
int relanceNotifId(int nid, String date) => mainNotifId(nid, date) + 1;
int snoozeNotifId(int nid) => nid * 100 + 60;
int snoozeRelanceNotifId(int nid) => nid * 100 + 61;

/// Tous les identifiants de notification liés à une occurrence.
List<int> notifIdsFor(int nid, String date) => [
      mainNotifId(nid, date),
      relanceNotifId(nid, date),
      snoozeNotifId(nid),
      snoozeRelanceNotifId(nid),
    ];

class PlannedNotification {
  final int id;
  final DateTime time;
  final String title;
  final String body;
  final String payload;
  final bool withActions;
  PlannedNotification(this.id, this.time, this.title, this.body, this.payload,
      {this.withActions = true});
}

String payloadFor(String reminderId, String date) =>
    jsonEncode({'rid': reminderId, 'date': date});

/// Nombre de jours programmés à l'avance (limite Android ~500 alarmes).
int windowDays(AppData data) {
  final n = data.reminders.where((r) => r.active).length;
  if (n == 0) return 14;
  return (200 ~/ (2 * n)).clamp(3, 14);
}

String notifTitle(Occurrence o) => 'Il est l\'heure : ${o.medName}';

String notifBody(Occurrence o) {
  final b = StringBuffer(
      'Prendre ${formatQuantity(o.reminder.quantity, o.reminder.unit)}'
      ' (prévu à ${hm(o.planned)})');
  final notes = o.med?.notes.trim() ?? '';
  if (notes.isNotEmpty) b.write('. $notes');
  return b.toString();
}

List<PlannedNotification> plannedNotifications(
    AppData data, List<HistoryEntry> history, DateTime now) {
  final idx = indexHistory(history);
  final w = windowDays(data);
  final today = dayOnly(now);
  final out = <PlannedNotification>[];
  var hasDaily = false;
  for (final r in data.reminders) {
    if (!r.active) continue;
    if (r.type == ReminderType.daily) hasDaily = true;
    // On regarde aussi la veille (prise décalée après minuit).
    for (var i = -1; i < w; i++) {
      final day = today.add(Duration(days: i));
      final o = occurrenceOn(data, r, day);
      if (o == null) continue;
      final st = stateOf(o, idx, now);
      if (st.status == OccStatus.taken || st.status == OccStatus.missed) continue;
      final payload = payloadFor(r.id, o.date);
      final snooze = st.snoozedUntil;
      final effective = snooze ?? o.planned;
      final mainId =
          snooze != null ? snoozeNotifId(r.nid) : mainNotifId(r.nid, o.date);
      final relId = snooze != null
          ? snoozeRelanceNotifId(r.nid)
          : relanceNotifId(r.nid, o.date);
      if (effective.isAfter(now)) {
        out.add(PlannedNotification(
            mainId, effective, notifTitle(o), notifBody(o), payload));
      }
      final rel = effective.add(relanceAfter);
      if (rel.isAfter(now)) {
        out.add(PlannedNotification(relId, rel,
            'Rappel : ${o.medName} pas encore pris', notifBody(o), payload));
      }
    }
  }
  if (hasDaily) {
    final end = today.add(Duration(days: w));
    out.add(PlannedNotification(
      windowEndNotificationId,
      DateTime(end.year, end.month, end.day, 7, 30),
      'Ouvrez Rappel Médicaments',
      'Ouvrez l\'application pour que vos prochains rappels restent programmés.',
      '{}',
      withActions: false,
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Statistiques pour le médecin
// ---------------------------------------------------------------------------

class MedStats {
  final String medName;
  int planned = 0; // prises terminées (prises + oubliées)
  int taken = 0;
  int onTime = 0;
  int late = 0;
  int missed = 0;
  int snoozed = 0; // occurrences décalées au moins une fois
  MedStats(this.medName);
  double get rate => planned == 0 ? 0 : taken / planned;
}

class PeriodStats {
  final MedStats total = MedStats('Total');
  final Map<String, MedStats> byMed = {};
  final List<HistoryEntry> missedList = [];
  final List<HistoryEntry> lateList = [];
}

PeriodStats computeStats(List<HistoryEntry> history, DateTime from, DateTime to) {
  final fromK = dateKey(from);
  final toK = dateKey(to);
  final inPeriod = history
      .where((h) => h.date.compareTo(fromK) >= 0 && h.date.compareTo(toK) <= 0)
      .toList();
  final idx = indexHistory(inPeriod);
  final stats = PeriodStats();
  final keys = idx.keys.toList()..sort();
  for (final k in keys) {
    final entries = idx[k]!;
    final first = entries.first;
    final s = stats.byMed.putIfAbsent(first.medName, () => MedStats(first.medName));
    final taken = entries.where((e) => e.status == HistoryStatus.pris).toList();
    final missed = entries.any((e) => e.status == HistoryStatus.oublie);
    final snoozed = entries.any((e) => e.status == HistoryStatus.decale);
    if (taken.isEmpty && !missed) continue; // occurrence pas encore terminée
    for (final t in [s, stats.total]) {
      t.planned++;
      if (snoozed) t.snoozed++;
      if (taken.isNotEmpty) {
        t.taken++;
        final e = taken.first;
        final delay = (e.actual ?? e.planned).difference(e.planned);
        if (delay.abs() <= onTimeTolerance) {
          t.onTime++;
        } else {
          t.late++;
        }
      } else {
        t.missed++;
      }
    }
    if (taken.isNotEmpty) {
      final e = taken.first;
      if ((e.actual ?? e.planned).difference(e.planned).abs() > onTimeTolerance) {
        stats.lateList.add(e);
      }
    } else {
      stats.missedList.add(entries.firstWhere((e) => e.status == HistoryStatus.oublie));
    }
  }
  stats.missedList.sort((a, b) => a.planned.compareTo(b.planned));
  stats.lateList.sort((a, b) => a.planned.compareTo(b.planned));
  return stats;
}

String percent(double r) => '${(r * 100).round()} %';
