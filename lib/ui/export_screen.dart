import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/logic.dart';
import '../core/pdf_export.dart';
import '../core/store.dart';
import 'profile_form.dart';
import 'theme.dart';
import 'widgets.dart';

class ExportScreen extends StatefulWidget {
  final AppStore store;
  const ExportScreen({super.key, required this.store});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int preset = 30; // 7, 30 ou 0 = dates libres
  DateTimeRange? custom;
  bool busy = false;

  DateTimeRange get range {
    final today = dayOnly(DateTime.now());
    if (preset == 0 && custom != null) return custom!;
    final days = preset == 0 ? 30 : preset;
    return DateTimeRange(start: today.subtract(Duration(days: days - 1)), end: today);
  }

  Future<void> _pickRange() async {
    final today = dayOnly(DateTime.now());
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: custom ?? range,
      helpText: 'Choisir la période',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      saveText: 'Valider',
    );
    if (r != null) {
      setState(() {
        custom = r;
        preset = 0;
      });
    }
  }

  Future<File> _buildFile() async {
    final r = range;
    final bytes = await buildDoctorPdf(
      data: widget.store.data,
      history: widget.store.history,
      from: r.start,
      to: r.end,
    );
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/suivi-medicaments-${DateFormat('yyyy-MM-dd').format(r.start)}-au-${DateFormat('yyyy-MM-dd').format(r.end)}.pdf');
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> _share() async {
    setState(() => busy = true);
    try {
      final f = await _buildFile();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/pdf')],
        subject: 'Suivi de mes prises de médicaments',
        title: 'Envoyer le document au médecin',
      ));
    } catch (e) {
      if (mounted) showMessage(context, 'Le partage a échoué : $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _print() async {
    setState(() => busy = true);
    try {
      final f = await _buildFile();
      final bytes = await f.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Suivi médicaments');
    } catch (e) {
      if (mounted) showMessage(context, 'L\'impression a échoué : $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final df = DateFormat('d MMMM yyyy', 'fr_FR');
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final r = range;
            final stats = computeStats(widget.store.history, r.start, r.end);
            final p = widget.store.data.profile;
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const ScreenHeader('Export pour le médecin',
                    subtitle: 'Un document PDF court (1 à 2 pages) avec vos médicaments et vos prises.',
                    showBack: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Période'),
                      for (final (label, d) in const [('7 derniers jours', 7), ('30 derniers jours', 30)]) ...[
                        BigButton(label,
                            icon: preset == d ? Icons.check_circle_rounded : Icons.date_range_rounded,
                            kind: preset == d ? BigButtonKind.primary : BigButtonKind.outline,
                            onPressed: () => setState(() => preset = d)),
                        const SizedBox(height: 10),
                      ],
                      BigButton(
                          preset == 0 && custom != null
                              ? 'Du ${df.format(custom!.start)} au ${df.format(custom!.end)}'
                              : 'Choisir les dates',
                          icon: preset == 0 ? Icons.check_circle_rounded : Icons.edit_calendar_rounded,
                          kind: preset == 0 ? BigButtonKind.primary : BigButtonKind.outline,
                          onPressed: _pickRange),
                      const FieldLabel('Ce qui figurera sur le document'),
                      SoftCard(
                        color: const Color(0xFFEDE5FF),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name.isEmpty ? 'Nom non renseigné' : p.name, style: t.titleMedium),
                            Text(
                                p.birthDate == null
                                    ? 'Date de naissance non renseignée'
                                    : 'Né(e) le ${df.format(p.birthDate!)}',
                                style: t.bodyMedium),
                            const SizedBox(height: 8),
                            Text('Du ${df.format(r.start)} au ${df.format(r.end)}', style: t.bodyMedium),
                            Text(
                              stats.total.planned == 0
                                  ? 'Aucune prise enregistrée sur cette période.'
                                  : 'Prises respectées : ${percent(stats.total.rate)} '
                                      '(${stats.total.taken} sur ${stats.total.planned})',
                              style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (p.name.isEmpty || p.birthDate == null) ...[
                        const SizedBox(height: 6),
                        BigButton('Compléter mon profil',
                            icon: Icons.person_rounded,
                            kind: BigButtonKind.outline,
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ProfileScreen(store: widget.store)))),
                      ],
                      const SizedBox(height: 22),
                      if (busy)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )),
                      BigButton('Envoyer ou enregistrer',
                          icon: Icons.share_rounded,
                          kind: BigButtonKind.success,
                          onPressed: busy ? null : _share),
                      const SizedBox(height: 6),
                      Text('E-mail, messagerie, Drive, Fichiers...', style: t.bodySmall, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      BigButton('Imprimer',
                          icon: Icons.print_rounded,
                          kind: BigButtonKind.soft,
                          color: brand,
                          onPressed: busy ? null : _print),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
