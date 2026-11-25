import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/med_import.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'import_screen.dart';
import 'med_edit_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Liste des médicaments : une ligne courte par médicament (nom et heures des
/// rappels), recherche au-dessus. Le détail s'ouvre en touchant la ligne.
class LibraryScreen extends StatefulWidget {
  final AppStore store;
  const LibraryScreen({super.key, required this.store});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _open(Medication? m, {String? name}) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => MedEditScreen(store: widget.store, med: m, initialName: name)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, search]),
      builder: (context, _) {
        final meds = widget.store.data.meds;
        final q = normalizeText(search.text);
        final shown = q.isEmpty
            ? meds
            : meds
                .where((m) => normalizeText(m.name).contains(q) || normalizeText(m.description).contains(q))
                .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                children: [
                  Text('Mes médicaments', style: t.headlineSmall),
                  if (meds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('${meds.length} médicament${meds.length > 1 ? 's' : ''}', style: t.bodyLarge),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ButtonPair(
                BigButton('Ajouter', icon: Icons.add_rounded, onPressed: () => _open(null)),
                BigButton('Importer',
                    icon: Icons.upload_file_rounded,
                    kind: BigButtonKind.outline,
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ImportScreen(store: widget.store)))),
              ),
            ),
            if (meds.isEmpty)
              const EmptyState(
                icon: Icons.medication_rounded,
                title: 'Aucun médicament',
                text: 'Ajoutez vos médicaments un par un, ou importez toute une liste '
                    'préparée sur ordinateur (Excel).',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: search,
                  style: const TextStyle(fontSize: 20),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un médicament',
                    prefixIcon: const Icon(Icons.search_rounded, size: 28),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            iconSize: 28,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: search.clear,
                          ),
                  ),
                ),
              ),
              if (q.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                      shown.isEmpty
                          ? 'Aucun médicament ne contient « ${search.text.trim()} »'
                          : '${shown.length} résultat${shown.length > 1 ? 's' : ''}',
                      style: t.titleMedium),
                ),
              if (q.isNotEmpty && shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: BigButton('Ajouter « ${search.text.trim()} »',
                      icon: Icons.add_rounded,
                      kind: BigButtonKind.outline,
                      onPressed: () => _open(null, name: search.text.trim())),
                ),
              const SizedBox(height: 10),
              if (shown.isNotEmpty) const Divider(height: 1, indent: 16, endIndent: 16, color: lineColor),
              for (final m in shown)
                _MedRow(
                  med: m,
                  reminders: widget.store.remindersOf(m.id).where((r) => r.active).toList(),
                  query: q,
                  onTap: () => _open(m),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Minuscules sans accents, caractère par caractère (même longueur que le
/// texte d'origine), pour surligner ce qui correspond à la recherche.
String _fold(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  return s.toLowerCase().split('').map((c) {
    final i = from.indexOf(c);
    return i >= 0 ? to[i] : c;
  }).join();
}

class _MedRow extends StatelessWidget {
  final Medication med;
  final List<Reminder> reminders;
  final String query;
  final VoidCallback onTap;
  const _MedRow({required this.med, required this.reminders, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const nameStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink, height: 1.25);
    final i = query.isEmpty ? -1 : _fold(med.name).indexOf(query);
    final name = i < 0
        ? Text(med.name, style: nameStyle)
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: med.name.substring(0, i)),
              TextSpan(
                  text: med.name.substring(i, i + query.length),
                  style: const TextStyle(backgroundColor: Color(0xFFFFE7A8))),
              TextSpan(text: med.name.substring(i + query.length)),
            ]),
            style: nameStyle);
    final times = [...reminders]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final hs = <String>[];
    for (final r in times) {
      final h = hmOf(r.hour, r.minute);
      if (!hs.contains(h)) hs.add(h);
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: lineColor))),
          child: Row(
            children: [
              MedAvatar(med, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    if (hs.isEmpty)
                      const Text('Aucun rappel',
                          style: TextStyle(fontSize: 17, color: muted, fontStyle: FontStyle.italic))
                    else
                      Text.rich(
                        TextSpan(children: [
                          const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.schedule_rounded, size: 18, color: muted),
                              )),
                          TextSpan(text: hs.join(' · ')),
                        ]),
                        style: const TextStyle(
                            fontSize: 17, color: muted, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30, color: muted, semanticLabel: 'Ouvrir'),
            ],
          ),
        ),
      ),
    );
  }
}
