import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/store.dart';
import 'med_edit_screen.dart';
import 'reminder_edit_screen.dart';
import 'widgets.dart';

class LibraryScreen extends StatelessWidget {
  final AppStore store;
  const LibraryScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final meds = store.data.meds;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const ScreenHeader('Mes médicaments',
                subtitle: 'Votre bibliothèque sert à créer les rappels.'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: BigButton('Ajouter un médicament',
                  icon: Icons.add_rounded,
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => MedEditScreen(store: store)))),
            ),
            if (meds.isEmpty)
              const EmptyState(
                icon: Icons.medication_rounded,
                title: 'Bibliothèque vide',
                text: 'Ajoutez vos médicaments avec leur nom, un descriptif et vos consignes '
                    '(par exemple le maximum par jour).',
              ),
            for (final m in meds)
              Builder(builder: (context) {
                final rs = store.remindersOf(m.id);
                final times = rs.where((r) => r.active).map((r) =>
                    '${hmOf(r.hour, r.minute)} (${frequencyLabel(r).toLowerCase()})');
                return SoftCard(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => MedEditScreen(store: store, med: m))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MedAvatar(m, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: t.titleLarge),
                                if (m.description.isNotEmpty) Text(m.description, style: t.bodyLarge),
                                if (m.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 22),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(m.notes, style: t.bodyMedium)),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  times.isEmpty
                                      ? 'Aucun rappel'
                                      : 'Rappels : ${times.join(', ')}',
                                  style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BigButton('Créer un rappel',
                          icon: Icons.add_alarm_rounded,
                          kind: BigButtonKind.outline,
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ReminderEditScreen(store: store, medId: m.id)))),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
