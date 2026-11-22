import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/store.dart';
import 'intake_screen.dart';
import 'reminder_edit_screen.dart';
import 'reminders_list_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class TodayScreen extends StatelessWidget {
  final AppStore store;
  final DateTime Function() clock;
  const TodayScreen({super.key, required this.store, this.clock = DateTime.now});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = clock();
        final occs = occurrencesOn(store.data, now);
        final idx = indexHistory(store.history);
        final states = {for (final o in occs) o.key: stateOf(o, idx, now)};
        final done = states.values.where((s) => s.status == OccStatus.taken).length;

        final children = <Widget>[
          _Header(now: now, name: store.data.profile.name, done: done, total: occs.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: BigButton('Nouveau rappel',
                icon: Icons.add_alarm_rounded,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ReminderEditScreen(store: store)))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: BigButton('J\'ai pris un médicament hors rappel',
                icon: Icons.add_task_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => IntakeScreen(store: store)))),
          ),
        ];

        if (occs.isEmpty) {
          children.add(EmptyState(
            icon: Icons.celebration_rounded,
            title: 'Rien de prévu aujourd\'hui',
            text: store.data.reminders.isEmpty
                ? 'Ajoutez votre premier rappel avec le bouton ci-dessus.'
                : 'Aucune prise n\'est programmée pour aujourd\'hui.',
          ));
        } else {
          Moment? current;
          for (final o in occs) {
            final m = momentOf(o.reminder.hour);
            if (m != current) {
              current = m;
              children.add(_MomentTitle(m));
            }
            children.add(OccurrenceCard(
              store: store,
              occ: o,
              state: states[o.key]!,
            ));
          }
        }
        final manual = store.history
            .where((h) => h.manual && h.date == dateKey(now))
            .toList()
          ..sort((a, b) => (a.actual ?? a.planned).compareTo(b.actual ?? b.planned));
        if (manual.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('Prises ponctuelles', style: Theme.of(context).textTheme.titleLarge),
          ));
          for (final h in manual) {
            children.add(SoftCard(
              color: const Color(0xFFE6F4EA),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => IntakeScreen(store: store, entry: h))),
              child: Row(
                children: [
                  MedAvatar(store.data.med(h.medId), size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        '${hm(h.actual ?? h.planned)}  ${h.medName}\n${formatQuantity(h.quantity, h.unit)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Icon(Icons.edit_rounded, size: 26, semanticLabel: 'Corriger'),
                ],
              ),
            ));
          }
        }
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: BigButton('Voir tous mes rappels',
              icon: Icons.list_alt_rounded,
              kind: BigButtonKind.outline,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => RemindersListScreen(store: store)))),
        ));
        return ListView(children: children);
      },
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime now;
  final String name;
  final int done;
  final int total;
  const _Header({required this.now, required this.name, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(' ').first;
    final hello = now.hour >= 18 || now.hour < 5 ? 'Bonsoir' : 'Bonjour';
    final date = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    final allDone = total > 0 && done == total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B2FD6), Color(0xFF9C2FB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first.isEmpty ? '$hello !' : '$hello $first !',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('${date[0].toUpperCase()}${date.substring(1)}',
              style: const TextStyle(fontSize: 20, color: Colors.white)),
          if (total > 0) ...[
            const SizedBox(height: 14),
            Text(
              allDone
                  ? 'Bravo, tout est pris pour aujourd\'hui !'
                  : '$done prise${done > 1 ? 's' : ''} faite${done > 1 ? 's' : ''} sur $total',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 14,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD54F)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MomentTitle extends StatelessWidget {
  final Moment m;
  const _MomentTitle(this.m);

  @override
  Widget build(BuildContext context) {
    final s = momentStyle(m);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          Icon(s.icon, color: s.accent, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(momentLabel(m),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: s.accent)),
          ),
        ],
      ),
    );
  }
}

class OccurrenceCard extends StatelessWidget {
  final AppStore store;
  final Occurrence occ;
  final OccState state;
  const OccurrenceCard({super.key, required this.store, required this.occ, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = momentStyle(momentOf(occ.reminder.hour));
    final t = Theme.of(context).textTheme;
    final taken = state.status == OccStatus.taken;
    final notes = occ.med?.notes.trim() ?? '';

    final (statusText, statusColor, statusIcon) = switch (state.status) {
      OccStatus.taken => ('Pris à ${hm(state.takenAt ?? DateTime.now())}', okGreen, Icons.check_circle_rounded),
      OccStatus.missed => ('Oublié', dangerRed, Icons.cancel_rounded),
      OccStatus.due => (
          state.snoozedUntil != null ? 'À prendre maintenant (reporté)' : 'À prendre maintenant',
          dangerRed,
          Icons.notifications_active_rounded
        ),
      OccStatus.snoozed => ('Reporté à ${hm(state.snoozedUntil!)}', warnOrange, Icons.snooze_rounded),
      OccStatus.upcoming => ('Prévu à ${hm(occ.planned)}', s.accent, Icons.schedule_rounded),
    };

    return SoftCard(
      color: taken ? const Color(0xFFE6F4EA) : s.background,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReminderEditScreen(store: store, reminder: occ.reminder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MedAvatar(occ.med, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hm(occ.planned),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: s.accent)),
                    Text(occ.medName, style: t.titleLarge),
                    Text(formatQuantity(occ.reminder.quantity, occ.reminder.unit),
                        style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w600)),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(notes, style: t.bodyMedium),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(statusText,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (taken)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => store.undoTaken(occ),
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Annuler, je ne l\'ai pas pris'),
              ),
            )
          else if (state.status == OccStatus.missed)
            BigButton('Je l\'ai pris quand même',
                icon: Icons.check_rounded,
                kind: BigButtonKind.success,
                onPressed: () => _take(context))
          else
            ButtonPair(
              BigButton('J\'ai pris',
                  icon: Icons.check_rounded,
                  kind: BigButtonKind.success,
                  onPressed: () => _take(context)),
              BigButton('Plus tard',
                  icon: Icons.snooze_rounded,
                  kind: BigButtonKind.soft,
                  color: s.accent,
                  onPressed: () => _askSnooze(context)),
            ),
        ],
      ),
    );
  }

  Future<void> _take(BuildContext context) async {
    await store.markTaken(occ);
    if (context.mounted) showMessage(context, 'Bien noté : ${occ.medName} pris.');
  }

  Future<void> _askSnooze(BuildContext context) async {
    final d = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Me le rappeler dans...', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final (label, dur) in const [
                ('15 minutes', Duration(minutes: 15)),
                ('30 minutes', Duration(minutes: 30)),
                ('1 heure', Duration(hours: 1)),
                ('2 heures', Duration(hours: 2)),
              ]) ...[
                BigButton(label,
                    icon: Icons.snooze_rounded,
                    kind: BigButtonKind.outline,
                    onPressed: () => Navigator.pop(ctx, dur)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
    if (d == null) return;
    await store.snooze(occ, d);
    if (context.mounted) {
      showMessage(context, 'D\'accord, nouveau rappel à ${hm(DateTime.now().add(d))}.');
    }
  }
}
