import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/notifications.dart';
import '../core/store.dart';
import 'export_screen.dart';
import 'permissions_panel.dart';
import 'profile_form.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  Future<void> _backup(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final name = 'tic-tac-sante-sauvegarde-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final f = File('${dir.path}/$name');
      await f.writeAsString(store.exportBackup());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/json', name: name)],
        subject: 'Sauvegarde Tic-Tac Santé',
        title: 'Enregistrer la sauvegarde',
      ));
    } catch (e) {
      if (context.mounted) showMessage(context, 'La sauvegarde a échoué : $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Choisir la sauvegarde');
    if (files.isEmpty) return;
    String content;
    try {
      content = await files.first.xFile.readAsString();
    } catch (e) {
      if (context.mounted) showMessage(context, 'Impossible de lire ce fichier.');
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmDialog(context,
        title: 'Restaurer cette sauvegarde ?',
        text: 'Les médicaments, rappels et l\'historique actuels seront remplacés '
            'par ceux de la sauvegarde.',
        confirm: 'Restaurer',
        danger: true);
    if (!ok) return;
    try {
      await store.restoreBackup(content);
      if (context.mounted) showMessage(context, 'Sauvegarde restaurée.');
    } on FormatException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.data.profile;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const ScreenHeader('Réglages'),
            SoftCard(
              onTap: () => go(ProfileScreen(store: store)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFEDE5FF),
                    child: Icon(Icons.person_rounded, size: 34, color: brand),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name.isEmpty ? 'Mon profil' : p.name, style: t.titleLarge),
                        Text(
                          p.birthDate == null
                              ? 'Date de naissance non renseignée'
                              : 'Né(e) le ${DateFormat('d MMMM yyyy', 'fr_FR').format(p.birthDate!)}',
                          style: t.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_rounded, size: 28),
                ],
              ),
            ),
            _Section('Pour le médecin'),
            _Pad(BigButton('Export pour le médecin (PDF)',
                icon: Icons.picture_as_pdf_rounded,
                onPressed: () => go(ExportScreen(store: store)))),
            _Section('Mes données'),
            _Pad(Text(
                'Vos données restent sur ce téléphone. Faites une sauvegarde de temps en temps '
                '(par e-mail ou dans vos fichiers) pour ne rien perdre en cas de changement de téléphone.',
                style: t.bodyMedium)),
            _Pad(BigButton('Sauvegarder mes données',
                icon: Icons.save_alt_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => _backup(context))),
            _Pad(BigButton('Restaurer une sauvegarde',
                icon: Icons.restore_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => _restore(context))),
            _Section('Fiabilité des rappels'),
            _Pad(BigButton('Vérifier les autorisations',
                icon: Icons.verified_user_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => go(const _PermissionsScreen()))),
            _Pad(BigButton('Tester une notification',
                icon: Icons.notifications_rounded,
                kind: BigButtonKind.outline,
                onPressed: () async {
                  await showTestNotification();
                  await scheduleTestNotification(1);
                  if (context.mounted) {
                    showMessage(context,
                        'Une notification vient d\'arriver. Une autre arrivera dans 1 minute : '
                        'vous pouvez verrouiller le téléphone pour vérifier.');
                  }
                })),
            const SizedBox(height: 16),
            _Pad(Text('Tic-Tac Santé, application locale sans compte ni serveur.',
                style: t.bodySmall, textAlign: TextAlign.center)),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _Pad extends StatelessWidget {
  final Widget child;
  const _Pad(this.child);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 6), child: child);
}

class _PermissionsScreen extends StatelessWidget {
  const _PermissionsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: const [
            ScreenHeader('Autorisations',
                subtitle: 'Les trois cases doivent indiquer « C\'est fait ».', showBack: true),
            PermissionsPanel(),
          ],
        ),
      ),
    );
  }
}
