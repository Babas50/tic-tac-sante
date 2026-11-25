import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/documents.dart';
import '../core/med_import.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Importer une liste de médicaments : récupérer le modèle, le remplir sur
/// ordinateur, choisir le fichier rempli.
class ImportScreen extends StatelessWidget {
  final AppStore store;
  const ImportScreen({super.key, required this.store});

  Future<SavedDoc?> _saveTemplate(BuildContext context) async {
    try {
      final data = await rootBundle.load(importTemplateAsset);
      return await Documents.save(data.buffer.asUint8List(), importTemplateName, mime: xlsxMime);
    } catch (e) {
      if (context.mounted) showMessage(context, 'Impossible de préparer le modèle : $e');
      return null;
    }
  }

  Future<void> _share(SavedDoc d) => SharePlus.instance.share(ShareParams(
        files: [XFile(d.file.path, mimeType: xlsxMime)],
        subject: 'Modèle Tic-Tac Santé à remplir',
      ));

  Future<void> _email(BuildContext context) async {
    final d = await _saveTemplate(context);
    if (d == null) return;
    final ok = await Documents.email(d,
        subject: 'Modèle Tic-Tac Santé à remplir',
        body: 'Ouvrez le fichier joint sur un ordinateur (Excel, LibreOffice ou Google Sheets), '
            'remplissez l\'onglet « Mes médicaments », puis renvoyez le fichier sur le téléphone '
            'et importez-le dans Tic-Tac Santé : Médicaments, Importer.',
        mime: xlsxMime);
    if (!ok) await _share(d);
  }

  Future<void> _download(BuildContext context) async {
    final d = await _saveTemplate(context);
    if (d == null) return;
    if (d.downloadsUri != null) {
      if (context.mounted) {
        showMessage(context, 'Modèle enregistré dans Téléchargements : $importTemplateName');
      }
    } else {
      await _share(d);
    }
  }

  Future<void> _pick(BuildContext context) async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Choisir la liste remplie');
    if (files.isEmpty || !context.mounted) return;
    final f = files.first.xFile;
    ImportPlan plan;
    try {
      final rows = readTable(await f.readAsBytes(), f.name);
      plan = buildImportPlan(rows, store.data.meds);
    } on FormatException catch (e) {
      if (context.mounted) showMessage(context, e.message);
      return;
    } catch (_) {
      if (context.mounted) showMessage(context, 'Impossible de lire ce fichier.');
      return;
    }
    if (!context.mounted) return;
    if (plan.rows.isEmpty) {
      showMessage(context, 'Aucun médicament trouvé dans ce fichier.');
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ImportPreviewScreen(store: store, plan: plan, fileName: f.name)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const ScreenHeader('Importer une liste',
                subtitle: 'Ajoutez plusieurs médicaments d\'un coup.', showBack: true),
            _Step(1, 'Récupérer le modèle', [
              Text('Un tableau Excel prêt à remplir, avec un mode d\'emploi et des exemples.', style: t.bodyLarge),
              BigButton('M\'envoyer par e-mail', icon: Icons.mail_outline_rounded, onPressed: () => _email(context)),
              BigButton('Télécharger le modèle',
                  icon: Icons.download_rounded, kind: BigButtonKind.outline, onPressed: () => _download(context)),
            ]),
            _Step(2, 'Le remplir sur un ordinateur', [
              Text('Avec Excel, LibreOffice ou Google Sheets. Une ligne par médicament.', style: t.bodyLarge),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: brand, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Votre liste est dans Word ? Sélectionnez le tableau, copiez-le, puis collez-le '
                          'dans le modèle à partir de la case A2.',
                          style: t.bodyMedium),
                    ),
                  ],
                ),
              ),
            ]),
            _Step(3, 'Choisir le fichier rempli', [
              Text('Envoyez-le sur ce téléphone (e-mail, Drive…), puis :', style: t.bodyLarge),
              BigButton('Choisir le fichier', icon: Icons.description_outlined, onPressed: () => _pick(context)),
              Text('Formats acceptés : Excel (.xlsx) ou CSV.', style: t.bodyMedium!.copyWith(color: muted)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final List<Widget> children;
  const _Step(this.n, this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: brand, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 6),
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vérifier avant d'importer : rien n'est enregistré avant « Importer ».
class ImportPreviewScreen extends StatefulWidget {
  final AppStore store;
  final ImportPlan plan;
  final String fileName;
  const ImportPreviewScreen({super.key, required this.store, required this.plan, required this.fileName});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool showAll = false;
  bool busy = false;

  Future<void> _import() async {
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    // Sauvegarde de sécurité juste avant l'import.
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/sauvegarde-avant-import.json').writeAsString(widget.store.exportBackup());
    } catch (_) {}
    final n = await widget.store.applyImport(widget.plan);
    nav.popUntil((r) => r.isFirst);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$n médicament${n > 1 ? 's' : ''} importé${n > 1 ? 's' : ''}.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plan = widget.plan;
    final ready = plan.rows.where((r) => r.status == RowStatus.ready).toList();
    final problems = plan.rows.where((r) => r.status == RowStatus.ignored || r.status == RowStatus.incomplete);
    final dups = plan.meds.where((m) => m.existing != null).toList();
    final nMeds = plan.toImport.length;
    final nRem = plan.reminderCount;
    final shownReady = showAll ? ready : ready.take(3).toList();

    Widget count(int n, String one, String many, Color c) => Text(n > 1 ? '$n $many' : '$n $one',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ScreenHeader('Vérifier avant d\'importer', subtitle: 'Fichier : ${widget.fileName}', showBack: true),
            SoftCard(
              color: surfaceAlt,
              borderColor: surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${plan.rows.length} ligne${plan.rows.length > 1 ? 's' : ''} lue${plan.rows.length > 1 ? 's' : ''}',
                      style: t.titleLarge),
                  const SizedBox(height: 6),
                  Wrap(spacing: 18, runSpacing: 4, children: [
                    count(plan.count(RowStatus.ready), 'prête', 'prêtes', okGreen),
                    if (plan.count(RowStatus.incomplete) > 0)
                      count(plan.count(RowStatus.incomplete), 'à compléter', 'à compléter', warnOrange),
                    if (plan.count(RowStatus.ignored) > 0)
                      count(plan.count(RowStatus.ignored), 'ignorée', 'ignorées', dangerRed),
                    if (dups.isNotEmpty) count(dups.length, 'déjà présente', 'déjà présentes', brand),
                  ]),
                ],
              ),
            ),
            if (problems.isNotEmpty || dups.isNotEmpty) ...[
              _Title('À regarder (${problems.length + dups.length})'),
              for (final r in problems)
                _Issue(
                  kind: r.status == RowStatus.ignored ? _IssueKind.error : _IssueKind.warning,
                  line: 'Ligne ${r.line}',
                  name: r.name,
                  message: r.message,
                ),
              for (final m in dups)
                _Issue(
                  kind: _IssueKind.duplicate,
                  line: m.rows.length == 1 ? 'Ligne ${m.rows.first.line}' : 'Lignes ${m.rows.map((r) => r.line).join(', ')}',
                  name: m.name,
                  message: 'Déjà dans vos médicaments${_withReminders(widget.store.remindersOf(m.existing!.id).length)}. '
                      'Remplacer : la description, la consigne et les rappels du fichier remplacent les actuels.'
                      '${m.rows.any((r) => r.message.isNotEmpty) ? ' ${m.rows.firstWhere((r) => r.message.isNotEmpty).message}' : ''}',
                  action: Segmented<bool>(
                    options: const [(false, 'Garder', Icons.check_rounded), (true, 'Remplacer', Icons.swap_horiz_rounded)],
                    value: m.replace,
                    onChanged: (v) => setState(() => m.replace = v),
                  ),
                ),
            ],
            if (ready.isNotEmpty) ...[
              _Title('Prêtes à importer (${ready.length})'),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in shownReady)
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: lineColor))),
                        child: Row(
                          children: [
                            const StatusDot(IntakeKind.taken, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  Text(r.summary, style: t.bodyMedium!.copyWith(color: muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (ready.length > 3)
                      BigButton(showAll ? 'Réduire' : 'Voir les ${ready.length - 3} autres',
                          kind: BigButtonKind.text, onPressed: () => setState(() => showAll = !showAll)),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      nMeds == 0
                          ? 'Aucun médicament à importer.'
                          : '$nMeds médicament${nMeds > 1 ? 's' : ''} et $nRem rappel${nRem > 1 ? 's' : ''} '
                              'seront ajoutés.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge!.copyWith(color: muted)),
                  const SizedBox(height: 10),
                  BigButton(nMeds > 1 ? 'Importer $nMeds médicaments' : 'Importer $nMeds médicament',
                      icon: Icons.check_rounded, onPressed: nMeds == 0 || busy ? null : _import),
                  const SizedBox(height: 6),
                  BigButton('Annuler', kind: BigButtonKind.text, onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _withReminders(int n) => n == 0 ? ', sans rappel' : ', avec $n rappel${n > 1 ? 's' : ''}';

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

enum _IssueKind { error, warning, duplicate }

class _Issue extends StatelessWidget {
  final _IssueKind kind;
  final String line;
  final String name;
  final String message;
  final Widget? action;
  const _Issue({required this.kind, required this.line, required this.name, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final (c, soft, icon) = switch (kind) {
      _IssueKind.error => (dangerRed, dangerSoft, Icons.close_rounded),
      _IssueKind.warning => (warnOrange, warnSoft, Icons.warning_amber_rounded),
      _IssueKind.duplicate => (brand, brandSoft, Icons.info_outline_rounded),
    };
    return SoftCard(
      padding: EdgeInsets.zero,
      borderColor: c,
      borderWidth: 1.5,
      color: soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: c, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c)),
                      Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 2),
                      Text(message, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(15))),
                padding: const EdgeInsets.all(8),
                child: action),
        ],
      ),
    );
  }
}
