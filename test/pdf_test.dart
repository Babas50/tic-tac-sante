import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rappel_medicaments/core/logic.dart';
import 'package:rappel_medicaments/core/models.dart';
import 'package:rappel_medicaments/core/pdf_export.dart';

import 'sample.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  test('le PDF médecin est léger et fait 1 à 2 pages', () async {
    final now = DateTime(2026, 11, 22, 23, 0);
    final data = sampleData(now);
    final history = sweepMissed(data, [], now, days: 30, newId: () => '${DateTime.now().microsecondsSinceEpoch}');
    // Transforme une partie des oublis en prises (à l'heure ou en retard).
    final h = <HistoryEntry>[];
    for (var i = 0; i < history.length; i++) {
      final e = history[i];
      if (i % 5 == 0) {
        h.add(e);
      } else {
        h.add(HistoryEntry(
          id: 'p$i', reminderId: e.reminderId, medId: e.medId, medName: e.medName,
          quantity: e.quantity, unit: e.unit, date: e.date, planned: e.planned,
          actual: e.planned.add(Duration(minutes: i % 7 == 0 ? 75 : 4)),
          status: HistoryStatus.pris,
        ));
      }
    }
    final bytes = await buildDoctorPdf(
        data: data, history: h, from: now.subtract(const Duration(days: 29)), to: now, now: now);
    final dir = Directory('build/test-output')..createSync(recursive: true);
    File('${dir.path}/export-medecin.pdf').writeAsBytesSync(bytes);
    expect(bytes.length, lessThan(100 * 1024));
    final pages = RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;
    expect(pages, inInclusiveRange(1, 2));
  });
}
