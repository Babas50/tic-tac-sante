import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'reminder_edit_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class RemindersListScreen extends StatelessWidget {
  final AppStore store;
  const RemindersListScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final rs = store.data.reminders;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const ScreenHeader('Tous mes rappels', showBack: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: BigButton('Nouveau rappel',
                      icon: Icons.add_alarm_rounded,
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ReminderEditScreen(store: store)))),
                ),
                if (rs.isEmpty)
                  const EmptyState(
                      icon: Icons.alarm_off_rounded,
                      title: 'Aucun rappel',
                      text: 'Créez un rappel pour être prévenu à l\'heure de vos médicaments.'),
                for (final r in rs)
                  Builder(builder: (context) {
                    final med = store.data.med(r.medId);
                    final s = momentStyle(momentOf(r.hour));
                    final when = r.type == ReminderType.daily
                        ? 'Tous les jours'
                        : 'Le ${DateFormat('d MMMM yyyy', 'fr_FR').format(parseDateKey(r.date!))}';
                    return SoftCard(
                      color: r.active ? s.background : const Color(0xFFEDEDED),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReminderEditScreen(store: store, reminder: r))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MedAvatar(med, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hmOf(r.hour, r.minute),
                                    style: TextStyle(
                                        fontSize: 26, fontWeight: FontWeight.w900, color: s.accent)),
                                Text(med?.name ?? 'Médicament supprimé', style: t.titleLarge),
                                Text('${formatQuantity(r.quantity, r.unit)} · $when', style: t.bodyLarge),
                                if (!r.active)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: Tag('En pause', color: ink),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_rounded, size: 28),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
