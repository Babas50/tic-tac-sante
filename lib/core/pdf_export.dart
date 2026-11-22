// PDF « pour le médecin » : texte et tableaux uniquement, 1 à 2 pages.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'logic.dart';
import 'models.dart';

const _maxDetailRows = 25;

String _d(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String _dt(DateTime d) => DateFormat('dd/MM HH:mm').format(d);

Future<Uint8List> buildDoctorPdf({
  required AppData data,
  required List<HistoryEntry> history,
  required DateTime from,
  required DateTime to,
  DateTime? now,
}) async {
  final stats = computeStats(history, from, to);
  final generated = now ?? DateTime.now();
  final doc = pw.Document(
    title: 'Suivi des prises de médicaments',
    author: data.profile.name,
    creator: 'Rappel Médicaments',
  );

  const small = pw.TextStyle(fontSize: 9);
  const normal = pw.TextStyle(fontSize: 10);
  final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  final h2 = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  final headerDeco = const pw.BoxDecoration(color: PdfColors.grey300);

  pw.Widget table(List<String> headers, List<List<String>> rows,
          {Map<int, pw.TableColumnWidth>? widths}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: small,
        headerDecoration: headerDeco,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
        columnWidths: widths,
        cellAlignment: pw.Alignment.centerLeft,
      );

  // Traitement en cours : rappels actifs groupés par médicament.
  final fromK = dateKey(from);
  final toK = dateKey(to);
  final byMed = <String, List<Reminder>>{};
  for (final r in data.reminders.where((r) => r.active)) {
    if (r.type == ReminderType.once &&
        (r.date == null || r.date!.compareTo(fromK) < 0 || r.date!.compareTo(toK) > 0)) {
      continue;
    }
    byMed.putIfAbsent(r.medId, () => []).add(r);
  }
  final treatmentRows = <List<String>>[];
  for (final e in byMed.entries) {
    final med = data.med(e.key);
    final rs = e.value..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final daily = rs.where((r) => r.type == ReminderType.daily).map((r) =>
        '${formatQuantity(r.quantity, r.unit)} à ${hmOf(r.hour, r.minute)}');
    final once = rs.where((r) => r.type == ReminderType.once).map((r) =>
        '${formatQuantity(r.quantity, r.unit)} le ${_d(parseDateKey(r.date!))} à ${hmOf(r.hour, r.minute)}');
    final poso = [
      if (daily.isNotEmpty) 'Chaque jour : ${daily.join(', ')}',
      if (once.isNotEmpty) 'Ponctuel : ${once.join(', ')}',
    ].join('\n');
    final notes = [med?.description ?? '', med?.notes ?? '']
        .where((s) => s.trim().isNotEmpty)
        .join(' / ');
    treatmentRows.add([med?.name ?? 'Médicament supprimé', poso, notes]);
  }
  treatmentRows.sort((a, b) => a[0].toLowerCase().compareTo(b[0].toLowerCase()));

  final t = stats.total;
  final medRows = stats.byMed.values.toList()
    ..sort((a, b) => a.medName.toLowerCase().compareTo(b.medName.toLowerCase()));

  final detailEntries = [...stats.missedList, ...stats.lateList]
    ..sort((a, b) => a.planned.compareTo(b.planned));
  final detail = <List<String>>[
    for (final e in detailEntries)
      [
        _dt(e.planned),
        e.medName,
        formatQuantity(e.quantity, e.unit),
        e.status == HistoryStatus.oublie ? 'Oubliée' : 'Prise en décalé',
        e.actual == null ? '' : DateFormat('HH:mm').format(e.actual!),
      ],
  ];
  final detailShown = detail.take(_maxDetailRows).toList();

  final birth = data.profile.birthDate;

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
          'Rappel Médicaments - édité le ${_d(generated)} - page ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ),
    build: (ctx) => [
      pw.Text('Suivi des prises de médicaments',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(
          'Patient : ${data.profile.name.isEmpty ? '(nom non renseigné)' : data.profile.name}'
          '${birth == null ? '' : '    Né(e) le ${_d(birth)}'}',
          style: bold),
      pw.Text('Période : du ${_d(from)} au ${_d(to)}', style: normal),
      pw.SizedBox(height: 10),
      pw.Text('Traitement en cours', style: h2),
      pw.SizedBox(height: 4),
      treatmentRows.isEmpty
          ? pw.Text('Aucun rappel actif.', style: normal)
          : table(['Médicament', 'Posologie programmée', 'Description / notes'],
              treatmentRows,
              widths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(3),
                }),
      pw.SizedBox(height: 12),
      pw.Text('Respect des prises', style: h2),
      pw.SizedBox(height: 4),
      if (t.planned == 0)
        pw.Text('Aucune prise enregistrée sur cette période.', style: normal)
      else ...[
        pw.Text(
            'Taux de prises respectées : ${percent(t.rate)} '
            '(${t.taken} prises sur ${t.planned} prévues). '
            'Dont ${t.onTime} à l\'heure (à 30 min près), ${t.late} en décalé, '
            '${t.missed} oubliées. ${t.snoozed} rappels reportés au moins une fois.',
            style: normal),
        pw.SizedBox(height: 6),
        table([
          'Médicament',
          'Prévues',
          'Prises',
          'À l\'heure',
          'En décalé',
          'Oubliées',
          'Taux'
        ], [
          for (final s in medRows)
            [
              s.medName,
              '${s.planned}',
              '${s.taken}',
              '${s.onTime}',
              '${s.late}',
              '${s.missed}',
              percent(s.rate)
            ],
        ], widths: {
          0: const pw.FlexColumnWidth(3),
        }),
      ],
      if (detail.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        pw.Text('Détail des oublis et prises en décalé', style: h2),
        pw.SizedBox(height: 4),
        table(['Prévu le', 'Médicament', 'Quantité', 'Statut', 'Prise réelle'],
            detailShown,
            widths: {1: const pw.FlexColumnWidth(3)}),
        if (detail.length > detailShown.length)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
                '... et ${detail.length - detailShown.length} autres lignes (non affichées pour rester court).',
                style: small),
          ),
      ],
      pw.SizedBox(height: 10),
      pw.Text(
          'Données saisies par le patient dans l\'application. '
          'Une prise « en décalé » a eu lieu à plus de 30 minutes de l\'heure prévue. '
          'Une prise est notée « oubliée » sans réponse 3 heures après l\'heure prévue.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ],
  ));
  return doc.save();
}
