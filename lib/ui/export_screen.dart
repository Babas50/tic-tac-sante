import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/documents.dart';
import '../core/logic.dart';
import '../core/pdf_export.dart';
import '../core/store.dart';
import 'profile_form.dart';
import 'theme.dart';
import 'widgets.dart';

class ExportScreen extends StatefulWidget {
  final AppStore store;

  /// Document déjà créé à afficher d'emblée (utilisé par les tests).
  final SavedDoc? initialDoc;
  const ExportScreen({super.key, required this.store, this.initialDoc});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int preset = 30; // 7, 30 ou 0 = dates libres
  DateTimeRange? custom;
  bool busy = false;
  late SavedDoc? created = widget.initialDoc; // PDF qu'on vient de créer (ou rouvert depuis la liste)
  List<SavedDoc> docs = [];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    try {
      final l = await Documents.list();
      if (mounted) setState(() => docs = l);
    } catch (_) {
      // Pas de dossier disponible (tests) : liste vide.
    }
  }

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

  String get _fileName {
    final r = range;
    final f = DateFormat('yyyy-MM-dd');
    return 'tic-tac-sante-suivi-${f.format(r.start)}-au-${f.format(r.end)}.pdf';
  }

  Future<void> _create() async {
    setState(() => busy = true);
    try {
      final r = range;
      final bytes = await buildDoctorPdf(
        data: widget.store.data,
        history: widget.store.history,
        from: r.start,
        to: r.end,
      );
      final doc = await Documents.save(bytes, _fileName);
      await _loadDocs();
      if (mounted) setState(() => created = doc);
    } catch (e) {
      if (mounted) showMessage(context, 'Le PDF n\'a pas pu être créé : $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _shareOther(SavedDoc d) async {
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(d.file.path, mimeType: 'application/pdf')],
        subject: 'Suivi de mes prises de médicaments',
        title: 'Envoyer le document',
      ));
    } catch (e) {
      if (mounted) showMessage(context, 'Le partage a échoué : $e');
    }
  }

  Future<void> _email(SavedDoc d) async {
    final p = widget.store.data.profile;
    final who = p.name.isEmpty ? '' : '\n${p.name}';
    final ok = await Documents.email(d,
        to: p.doctorEmail,
        subject: 'Suivi de mes prises de médicaments',
        body: 'Bonjour,\n\nVous trouverez ci-joint le suivi de mes prises de médicaments '
            '(${d.title.replaceFirst('Suivi ', '')}).\n\nCordialement,$who');
    if (!ok) await _shareOther(d);
  }

  Future<void> _open(SavedDoc d) async {
    if (await Documents.open(d)) return;
    await _print(d); // aperçu du système, à défaut de lecteur PDF
  }

  Future<void> _print(SavedDoc d) async {
    try {
      final bytes = await d.file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: d.title);
    } catch (e) {
      if (mounted) showMessage(context, 'L\'impression a échoué : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => created == null ? _form(context) : _result(context, created!),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final df = DateFormat('d MMMM yyyy', 'fr_FR');
    final r = range;
    final stats = computeStats(widget.store.history, r.start, r.end);
    final p = widget.store.data.profile;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const ScreenHeader('Export pour le médecin',
            subtitle: 'Un PDF d\'une ou deux pages avec vos médicaments et vos prises.', showBack: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Période'),
              Segmented<int>(
                options: const [
                  (7, '7 jours', Icons.date_range_rounded),
                  (30, '30 jours', Icons.calendar_month_rounded),
                  (0, 'Dates...', Icons.edit_calendar_rounded),
                ],
                value: preset,
                onChanged: (d) => d == 0 ? _pickRange() : setState(() => preset = d),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text('Du ${df.format(r.start)} au ${df.format(r.end)}', style: t.bodySmall),
              ),
              const FieldLabel('Sur le document'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(16)),
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
                    kind: BigButtonKind.text,
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProfileScreen(store: widget.store)))),
              ],
              const SizedBox(height: 22),
              if (busy)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                )),
              BigButton('Créer le PDF', icon: Icons.picture_as_pdf_rounded, onPressed: busy ? null : _create),
              const SizedBox(height: 6),
              Text('Il sera enregistré dans Téléchargements.', style: t.bodySmall, textAlign: TextAlign.center),
              if (docs.isNotEmpty) ...[
                const FieldLabel('Documents déjà créés'),
                for (final d in docs)
                  SoftCard(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                    onTap: () => setState(() => created = d),
                    child: Row(
                      children: [
                        const Icon(Icons.description_rounded, size: 28, color: brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              Text('Créé le ${DateFormat('d MMMM', 'fr_FR').format(d.created)}', style: t.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Partager ce document',
                          iconSize: 26,
                          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                          icon: const Icon(Icons.share_rounded, color: brand),
                          onPressed: () => _shareOther(d),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, SavedDoc d) {
    final t = Theme.of(context).textTheme;
    final p = widget.store.data.profile;
    final hasMail = p.doctorEmail.isNotEmpty;
    final to = p.doctorName.isNotEmpty ? p.doctorName : p.doctorEmail;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const ScreenHeader('Export pour le médecin', showBack: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(color: okSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 40, color: okGreen),
                ),
              ),
              const SizedBox(height: 10),
              Text('Le PDF est enregistré', style: t.titleLarge, textAlign: TextAlign.center),
              Text(
                  d.downloadsUri != null
                      ? 'Dans Téléchargements, sur ce téléphone.'
                      : 'Dans l\'application, sur ce téléphone.',
                  style: t.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lineColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 34, color: brand),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(d.sizeLabel, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const FieldLabel('Et maintenant ?'),
              BigButton(hasMail ? 'Envoyer à $to' : 'Envoyer par e-mail',
                  icon: Icons.mail_rounded, onPressed: () => _email(d)),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                    hasMail
                        ? 'Votre messagerie s\'ouvre avec le PDF déjà joint.'
                        : 'Votre messagerie s\'ouvre avec le PDF joint : il reste à choisir le destinataire.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center),
              ),
              if (!hasMail)
                BigButton('Ajouter l\'e-mail du médecin',
                    icon: Icons.person_add_alt_rounded,
                    kind: BigButtonKind.text,
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProfileScreen(store: widget.store)))),
              const SizedBox(height: 6),
              BigButton('Partager autrement...',
                  icon: Icons.share_rounded, kind: BigButtonKind.outline, onPressed: () => _shareOther(d)),
              const SizedBox(height: 10),
              ButtonPair(
                BigButton('Ouvrir',
                    icon: Icons.visibility_rounded, kind: BigButtonKind.outline, onPressed: () => _open(d)),
                BigButton('Imprimer',
                    icon: Icons.print_rounded, kind: BigButtonKind.outline, onPressed: () => _print(d)),
              ),
              const SizedBox(height: 14),
              BigButton('Terminé', kind: BigButtonKind.text, onPressed: () => setState(() => created = null)),
            ],
          ),
        ),
      ],
    );
  }
}
