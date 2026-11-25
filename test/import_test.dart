import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/med_import.dart';
import 'package:rappel_medicaments/core/models.dart';
import 'package:rappel_medicaments/core/store.dart';

void main() {
  group('cellules', () {
    test('heures', () {
      expect(parseTimes('08:00 ; 20:00'), [(8, 0), (20, 0)]);
      expect(parseTimes('8h, 20h30'), [(8, 0), (20, 30)]);
      expect(parseTimes('20 h et 8 h 15'), [(8, 15), (20, 0)]);
      expect(parseTimes(''), isEmpty);
      expect(parseTimes('0.5'), [(12, 0)]); // cellule Excel au format heure
      expect(parseTimes('le matin'), isNull);
      expect(parseTimes('25:00'), isNull);
    });

    test('quantités', () {
      expect(parseQuantity(''), 1);
      expect(parseQuantity('0,5'), 0.5);
      expect(parseQuantity('1.5'), 1.5);
      expect(parseQuantity('1/2'), 0.5);
      expect(parseQuantity('1 ½'), 1.5);
      expect(parseQuantity('un demi'), isNull);
      expect(parseQuantity('0'), isNull);
    });

    test('fréquences', () {
      expect(parseFrequency('')!.interval, 1);
      expect(parseFrequency('Tous les jours')!.repeat, Recurrence.interval);
      expect(parseFrequency('1 jour sur 2')!.interval, 2);
      expect(parseFrequency('tous les 3 jours')!.interval, 3);
      final d = parseFrequency('Lundi, Jeudi')!;
      expect(d.repeat, Recurrence.weekdays);
      expect(d.weekdays, [1, 4]);
      expect(parseFrequency('mer et ven')!.weekdays, [3, 5]);
      expect(parseFrequency('de temps en temps'), isNull);
    });

    test('recherche sans accents', () {
      expect(normalizeText('  Lévothyrox  75 µg'), 'levothyrox 75 µg');
      expect(normalizeText('Kardégic').contains(normalizeText('karde')), isTrue);
    });
  });

  group('lecture des fichiers', () {
    test('CSV point-virgule, guillemets, Windows-1252', () {
      final text = 'Médicament;Description;Consigne;Heures de prise;Quantité;Unité;Fréquence\r\n'
          'Doliprane 1000 mg;"Douleur; fièvre";;"08:00 ; 20:00";1,5;comprimé;\r\n'
          '\r\n'
          'Kardégic 75;;Pendant le repas;12:30;1;sachet;Tous les jours\r\n';
      final rows = readTable(Uint8List.fromList(latin1.encode(text)), 'liste.csv');
      expect(rows.length, 3);
      expect(rows[1].cells[1], 'Douleur; fièvre');
      expect(rows[2].line, 4);
      final plan = buildImportPlan(rows, []);
      expect(plan.count(RowStatus.ready), 2);
      expect(plan.meds.first.reminders.length, 2);
      expect(plan.meds.first.reminders.first.quantity, 1.5);
    });

    test('CSV virgule sans ligne de titres', () {
      final rows = readCsv(Uint8List.fromList(utf8.encode('Doliprane,Douleur,,8h,1,,\n')));
      final plan = buildImportPlan(rows, []);
      expect(plan.meds.single.name, 'Doliprane');
      expect(plan.meds.single.reminders.single.hour, 8);
    });

    test('Word refusé avec une explication', () {
      expect(() => readTable(Uint8List(10), 'liste.docx'), throwsFormatException);
    });

    test('le modèle fourni : exemples ignorés', () {
      final bytes = File(importTemplateAsset).readAsBytesSync();
      final plan = buildImportPlan(readTable(bytes, importTemplateName), []);
      expect(plan.rows.length, 6);
      expect(plan.rows.every((r) => r.status == RowStatus.ignored), isTrue);
      expect(plan.toImport, isEmpty);
    });

    test('fichier Excel rempli', () {
      final bytes = File('test/fixtures/import_sample.xlsx').readAsBytesSync();
      final existing = [Medication(id: 'm1', name: 'Doliprane 1000 mg')];
      final plan = buildImportPlan(readTable(bytes, 'mes-medicaments.xlsx'), existing);
      final byLine = {for (final r in plan.rows) r.line: r};
      expect(byLine[2]!.status, RowStatus.existing);
      expect(byLine[3]!.status, RowStatus.ready);
      expect(byLine[3]!.summary, '1 comprimé à 08:00, tous les jours');
      expect(byLine[4]!.status, RowStatus.incomplete);
      expect(byLine[4]!.message, contains('un demi'));
      expect(byLine[5]!.status, RowStatus.ignored);
      expect(byLine[6]!.summary, '1 comprimé à 20:30, le lundi et jeudi');
      expect(byLine[7]!.status, RowStatus.ignored); // exemple du modèle
      expect(byLine[8]!.summary, 'Sans rappel');
      // Doliprane gardé par défaut : 4 médicaments, 3 rappels.
      expect(plan.toImport.map((m) => m.name), ['Amlodipine 5 mg', 'Lévothyrox 75 µg', 'Eliquis 5 mg', 'Spray']);
      expect(plan.reminderCount, 2);
    });
  });

  group('import dans l\'appli', () {
    test('crée les médicaments et rappels, remplace sur demande', () async {
      final dolip = Medication(id: 'm1', name: 'Doliprane 1000 mg', description: 'ancien');
      final data = AppData()
        ..meds.add(dolip)
        ..reminders.add(Reminder(
            id: 'r1', medId: 'm1', type: ReminderType.daily, hour: 9, minute: 0,
            quantity: 1, unit: 'comprimé', createdAt: DateTime(2026), nid: 1));
      final store = AppStore.memory(data, []);
      final rows = readCsv(Uint8List.fromList(utf8.encode(
          'Médicament;Description;Consigne;Heures;Quantité;Unité;Fréquence\n'
          'Doliprane 1000 mg;Paracétamol;;"08:00 ; 20:00";1;;\n'
          'Collyre;;;19:00;1;goutte;1 jour sur 2\n')));
      final plan = buildImportPlan(rows, store.data.meds);
      plan.meds.firstWhere((m) => m.existing != null).replace = true;
      final n = await store.applyImport(plan, now: DateTime(2026, 11, 25, 10));
      expect(n, 2);
      expect(store.data.meds.map((m) => m.name), ['Collyre', 'Doliprane 1000 mg']);
      expect(dolip.description, 'Paracétamol');
      final dr = store.remindersOf('m1');
      expect(dr.map((r) => hmOf(r.hour, r.minute)), ['08:00', '20:00']);
      final collyre = store.data.meds.firstWhere((m) => m.name == 'Collyre');
      final cr = store.remindersOf(collyre.id).single;
      expect(cr.intervalDays, 2);
      expect(cr.startDate, '2026-11-25');
      expect(collyre.iconIndex, 2);
      expect({for (final r in store.data.reminders) r.nid}.length, 3);
    });
  });
}
