import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/models.dart';

import 'sample.dart';

var _n = 0;
String _id() => 'id${_n++}';

HistoryEntry entry(Occurrence o, HistoryStatus s, {DateTime? actual, DateTime? until}) => HistoryEntry(
      id: _id(),
      reminderId: o.reminder.id,
      medId: o.reminder.medId,
      medName: o.medName,
      quantity: o.reminder.quantity,
      unit: o.reminder.unit,
      date: o.date,
      planned: o.planned,
      actual: actual,
      status: s,
      until: until,
    );

void main() {
  test('format des quantités', () {
    expect(formatQuantity(1, 'comprimé'), '1 comprimé');
    expect(formatQuantity(0.5, 'comprimé'), '½ comprimé');
    expect(formatQuantity(1.5, 'comprimé'), '1 ½ comprimés');
    expect(formatQuantity(2, 'goutte'), '2 gouttes');
    expect(formatQuantity(10, 'ml'), '10 ml');
    expect(formatQuantity(0.25, 'comprimé'), '¼ comprimé');
  });

  test('moments de la journée', () {
    expect(momentOf(8), Moment.matin);
    expect(momentOf(12), Moment.midi);
    expect(momentOf(15), Moment.apresMidi);
    expect(momentOf(20), Moment.soir);
    expect(momentOf(23), Moment.nuit);
    expect(momentOf(3), Moment.nuit);
  });

  test('occurrences du jour, ponctuel inclus, triées', () {
    final now = DateTime(2026, 11, 22, 10, 0);
    final data = sampleData(now);
    final occ = occurrencesOn(data, now);
    expect(occ.map((o) => o.reminder.id), ['r1', 'r2', 'r5', 'r3', 'r4']);
    final tomorrow = occurrencesOn(data, now.add(const Duration(days: 1)));
    expect(tomorrow.length, 4);
  });

  test('un rappel quotidien commence à sa création', () {
    final now = DateTime(2026, 11, 22, 10, 0);
    final data = sampleData(now);
    data.reminders.first.createdAt = DateTime(2026, 11, 22, 9, 0); // 8 h déjà passée
    expect(occurrencesOn(data, now).any((o) => o.reminder.id == 'r1'), isFalse);
    expect(occurrencesOn(data, now.add(const Duration(days: 1))).any((o) => o.reminder.id == 'r1'), isTrue);
  });

  test('statuts : à venir, à prendre, reporté, pris, oublié', () {
    final now = DateTime(2026, 11, 22, 12, 40);
    final data = sampleData(now);
    final occ = occurrencesOn(data, now);
    final o8 = occ.firstWhere((o) => o.reminder.id == 'r1');
    final o1230 = occ.firstWhere((o) => o.reminder.id == 'r2');
    final o20 = occ.firstWhere((o) => o.reminder.id == 'r3');
    final history = <HistoryEntry>[];
    var idx = indexHistory(history);
    expect(stateOf(o20, idx, now).status, OccStatus.upcoming);
    expect(stateOf(o1230, idx, now).status, OccStatus.due);
    expect(stateOf(o8, idx, now).status, OccStatus.missed); // > 3 h

    history.add(entry(o1230, HistoryStatus.decale,
        actual: now, until: now.add(const Duration(minutes: 30))));
    idx = indexHistory(history);
    final s = stateOf(o1230, idx, now);
    expect(s.status, OccStatus.snoozed);
    expect(s.snoozedUntil, now.add(const Duration(minutes: 30)));

    history.add(entry(o1230, HistoryStatus.pris, actual: now));
    idx = indexHistory(history);
    expect(stateOf(o1230, idx, now).status, OccStatus.taken);
  });

  test('balayage des oublis idempotent', () {
    final now = DateTime(2026, 11, 22, 12, 0);
    final data = sampleData(now);
    final history = <HistoryEntry>[];
    final missed = sweepMissed(data, history, now, days: 2, newId: _id);
    // J-2 et J-1 : 4 quotidiens chacun ; aujourd'hui : 8 h n'est pas encore oublié (< 3 h ? non, 4 h) 
    // 8 h + 3 h = 11 h < 12 h -> oublié aussi.
    expect(missed.length, 4 + 4 + 1);
    history.addAll(missed);
    expect(sweepMissed(data, history, now, days: 2, newId: _id), isEmpty);
  });

  test('notifications planifiées : principale + relance, rien si pris', () {
    final now = DateTime(2026, 11, 22, 7, 0);
    final data = sampleData(now);
    final plan = plannedNotifications(data, [], now);
    final w = windowDays(data);
    final todayKey = dateKey(now);
    final main8 = plan.where((p) => p.id == mainNotifId(1, todayKey)).single;
    expect(main8.time, DateTime(2026, 11, 22, 8, 0));
    final rel8 = plan.where((p) => p.id == relanceNotifId(1, todayKey)).single;
    expect(rel8.time, DateTime(2026, 11, 22, 8, 15));
    // 4 quotidiens x w jours x 2 + ponctuel x 2 + fin de fenêtre
    expect(plan.length, 4 * w * 2 + 2 + 1);
    // identifiants uniques
    expect(plan.map((p) => p.id).toSet().length, plan.length);

    final o8 = occurrencesOn(data, now).first;
    final plan2 = plannedNotifications(data, [entry(o8, HistoryStatus.pris, actual: now)], now);
    expect(plan2.any((p) => p.id == mainNotifId(1, todayKey)), isFalse);
    expect(plan2.any((p) => p.id == relanceNotifId(1, todayKey)), isFalse);
  });

  test('report : notification de report et sa relance', () {
    final now = DateTime(2026, 11, 22, 8, 5);
    final data = sampleData(now);
    final o8 = occurrencesOn(data, now).first;
    final until = now.add(const Duration(minutes: 30));
    final plan = plannedNotifications(
        data, [entry(o8, HistoryStatus.decale, actual: now, until: until)], now);
    expect(plan.where((p) => p.id == snoozeNotifId(1)).single.time, until);
    expect(plan.where((p) => p.id == snoozeRelanceNotifId(1)).single.time,
        until.add(const Duration(minutes: 15)));
    expect(plan.any((p) => p.id == relanceNotifId(1, dateKey(now))), isFalse);
  });

  test('statistiques de la période', () {
    final now = DateTime(2026, 11, 22, 23, 59);
    final data = sampleData(now);
    final occ = occurrencesOn(data, now);
    final h = <HistoryEntry>[
      entry(occ[0], HistoryStatus.pris, actual: occ[0].planned.add(const Duration(minutes: 5))),
      entry(occ[1], HistoryStatus.decale, actual: occ[1].planned, until: occ[1].planned.add(const Duration(hours: 1))),
      entry(occ[1], HistoryStatus.pris, actual: occ[1].planned.add(const Duration(hours: 1))),
      entry(occ[2], HistoryStatus.oublie),
    ];
    final s = computeStats(h, now, now);
    expect(s.total.planned, 3);
    expect(s.total.taken, 2);
    expect(s.total.onTime, 1);
    expect(s.total.late, 1);
    expect(s.total.missed, 1);
    expect(s.total.snoozed, 1);
    expect(percent(s.total.rate), '67 %');
  });

  test('migration : un ancien rappel sans fréquence reste quotidien', () {
    final r = Reminder.fromJson({
      'id': 'x', 'medId': 'm', 'type': 'daily', 'hour': 8, 'minute': 0,
      'quantity': 1, 'unit': 'comprimé', 'createdAt': '2026-01-01T00:00:00.000', 'nid': 9,
    });
    expect(r.repeat, Recurrence.interval);
    expect(r.intervalDays, 1);
    expect(frequencyLabel(r), 'Tous les jours');
    expect(repeatsOn(r, DateTime(2026, 11, 22)), isTrue);
  });

  test('1 jour sur 2 et 1 jour sur 3 à partir du premier jour', () {
    final now = DateTime(2026, 11, 22, 7, 0);
    final data = sampleData(now);
    final r = data.reminders.first
      ..intervalDays = 2
      ..startDate = '2026-11-20';
    expect(frequencyLabel(r), '1 jour sur 2');
    expect(repeatsOn(r, DateTime(2026, 11, 20)), isTrue);
    expect(repeatsOn(r, DateTime(2026, 11, 21)), isFalse);
    expect(repeatsOn(r, DateTime(2026, 11, 22)), isTrue);
    expect(repeatsOn(r, DateTime(2026, 11, 19)), isFalse); // avant le début
    r.intervalDays = 3;
    expect(repeatsOn(r, DateTime(2026, 11, 23)), isTrue);
    expect(repeatsOn(r, DateTime(2026, 11, 22)), isFalse);
    // Pas de notification ni d'oubli les jours sans prise.
    final plan = plannedNotifications(data, [], now);
    expect(plan.any((p) => p.id == mainNotifId(1, '2026-11-22')), isFalse);
    expect(plan.any((p) => p.id == mainNotifId(1, '2026-11-23')), isTrue);
    final missed = sweepMissed(data, [], DateTime(2026, 11, 24, 23), days: 4, newId: _id)
        .where((e) => e.reminderId == r.id)
        .map((e) => e.date);
    expect(missed, ['2026-11-20', '2026-11-23']);
  });

  test('certains jours de la semaine', () {
    final data = sampleData(DateTime(2026, 11, 22));
    final r = data.reminders.first
      ..repeat = Recurrence.weekdays
      ..weekdays = [1, 3, 5];
    expect(frequencyLabel(r), 'Chaque lundi, mercredi et vendredi');
    expect(repeatsOn(r, DateTime(2026, 11, 23)), isTrue); // lundi
    expect(repeatsOn(r, DateTime(2026, 11, 24)), isFalse); // mardi
    expect(repeatsOn(r, DateTime(2026, 11, 22)), isFalse); // dimanche
  });

  test('les prises ponctuelles sont listées mais hors taux', () {
    final now = DateTime(2026, 11, 22, 23, 0);
    final data = sampleData(now);
    final occ = occurrencesOn(data, now);
    final h = [
      entry(occ[0], HistoryStatus.pris, actual: occ[0].planned),
      HistoryEntry(id: 'man', reminderId: '${manualPrefix}man', medId: 'm1', medName: 'Doliprane',
          quantity: 1, unit: 'comprimé', date: dateKey(now), planned: now, actual: now,
          status: HistoryStatus.pris, once: true),
    ];
    final s = computeStats(h, now, now);
    expect(s.total.planned, 1);
    expect(s.manualList.length, 1);
    expect(h[1].manual, isTrue);
  });
}
