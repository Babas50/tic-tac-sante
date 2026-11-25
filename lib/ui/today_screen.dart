import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'intake_screen.dart';
import 'intake_sheet.dart';
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
        final manual = store.history.where((h) => h.manual && h.date == dateKey(now)).toList();

        // Prises prévues et prises en plus, mêlées dans l'ordre de l'heure.
        final items = <(DateTime, Widget)>[
          for (final o in occs) (o.planned, _occurrenceTile(context, o, states[o.key]!)),
          for (final h in manual)
            (
              h.actual ?? h.planned,
              CompactIntakeRow(
                kind: IntakeKind.extra,
                time: hm(h.actual ?? h.planned),
                title: h.medName,
                quantity: formatQuantity(h.quantity, h.unit),
                detail: 'Prise en plus',
                onTap: () => showEntrySheet(context, store, h),
              )
            ),
        ]..sort((a, b) => a.$1.compareTo(b.$1));

        final children = <Widget>[
          _Header(now: now, name: store.data.profile.name),
          if (occs.isNotEmpty) _PillBox(occs: occs, states: states, done: done, now: now),
        ];

        if (items.isEmpty) {
          children.add(EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Rien de prévu aujourd\'hui',
            text: store.data.reminders.isEmpty
                ? 'Ajoutez votre premier rappel avec « Mes rappels », en bas de l\'écran.'
                : 'Aucune prise n\'est programmée pour aujourd\'hui.',
          ));
        } else {
          Moment? current;
          for (final it in items) {
            final m = momentOf(it.$1.hour);
            if (m != current) {
              current = m;
              children.add(_MomentTitle(m));
            }
            children.add(it.$2);
          }
        }
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: BigButton('Mes rappels : modifier ou ajouter',
              icon: Icons.alarm_rounded,
              kind: BigButtonKind.soft,
              color: ink,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => RemindersListScreen(store: store)))),
        ));
        // Place pour le bouton flottant, qui ne doit rien cacher.
        children.add(const SizedBox(height: 110));
        return Stack(
          children: [
            ListView(children: children),
            Positioned(
              right: 16,
              bottom: 16,
              left: 16,
              child: Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton.extended(
                  heroTag: 'prise-hors-rappel',
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => IntakeScreen(store: store))),
                  icon: const Icon(Icons.add_rounded, size: 28),
                  label: const Text('J\'ai pris un médicament'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _occurrenceTile(BuildContext context, Occurrence o, OccState st) {
    if (st.status == OccStatus.taken) {
      final entry = store.history.where((h) => h.key == o.key && h.status == HistoryStatus.pris).lastOrNull;
      return CompactIntakeRow(
        kind: IntakeKind.taken,
        time: hm(o.planned),
        title: o.medName,
        quantity: formatQuantity(o.reminder.quantity, o.reminder.unit),
        detail: 'Pris à ${hm(st.takenAt ?? o.planned)}',
        onTap: () {
          if (entry != null) showEntrySheet(context, store, entry);
        },
      );
    }
    return OccurrenceCard(store: store, occ: o, state: st);
  }
}

class _Header extends StatelessWidget {
  final DateTime now;
  final String name;
  const _Header({required this.now, required this.name});

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(' ').first;
    final hello = now.hour >= 18 || now.hour < 5 ? 'Bonsoir' : 'Bonjour';
    final date = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${date[0].toUpperCase()}${date.substring(1)}',
              style: const TextStyle(fontSize: 18, color: muted)),
          Text(first.isEmpty ? hello : '$hello $first',
              style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

/// Le pilulier : une case par prise de la journée.
class _PillBox extends StatelessWidget {
  final List<Occurrence> occs;
  final Map<String, OccState> states;
  final int done;
  final DateTime now;
  const _PillBox({required this.occs, required this.states, required this.done, required this.now});

  @override
  Widget build(BuildContext context) {
    final total = occs.length;
    final next = occs.where((o) {
      final s = states[o.key]!.status;
      return s != OccStatus.taken && s != OccStatus.missed;
    }).map((o) => states[o.key]!.snoozedUntil ?? o.planned).fold<DateTime?>(
        null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final allDone = done == total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(allDone ? 'Tout est pris pour aujourd\'hui' : '$done prise${done > 1 ? 's' : ''} sur $total',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (next != null && !allDone)
                Text(next.isAfter(now) ? 'Prochaine à ${hm(next)}' : 'À prendre maintenant',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: brand)),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: '$done prise${done > 1 ? 's' : ''} faite${done > 1 ? 's' : ''} sur $total',
            excludeSemantics: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final o in occs) _Cell(time: hm(o.planned), status: states[o.key]!.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String time;
  final OccStatus status;
  const _Cell({required this.time, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, color) = switch (status) {
      OccStatus.taken => (brand, brand, Icons.check_rounded, Colors.white),
      OccStatus.snoozed || OccStatus.due => (warnSoft, warnOrange, Icons.schedule_rounded, warnOrange),
      OccStatus.missed => (dangerSoft, dangerRed, Icons.close_rounded, dangerRed),
      OccStatus.upcoming => (Colors.white, const Color(0xFFA9BDBB), null, muted),
    };
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 2),
            ),
            alignment: Alignment.center,
            child: icon == null ? null : Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(time,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Icon(s.icon, color: s.accent, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(momentLabel(m), style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}

/// Carte d'une prise pas encore faite. Les boutons n'apparaissent que
/// lorsqu'elle est à prendre (ou reportée, ou oubliée) ; sinon on touche la
/// carte pour la noter en avance.
class OccurrenceCard extends StatelessWidget {
  final AppStore store;
  final Occurrence occ;
  final OccState state;
  const OccurrenceCard({super.key, required this.store, required this.occ, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final notes = occ.med?.notes.trim() ?? '';
    final st = state.status;
    final (IntakeKind? kind, String? text) = switch (st) {
      OccStatus.missed => (IntakeKind.missed, 'Oublié'),
      OccStatus.due => (IntakeKind.due, state.snoozedUntil != null ? 'À prendre maintenant (reporté)' : 'À prendre maintenant'),
      OccStatus.snoozed => (IntakeKind.snoozed, 'Reporté à ${hm(state.snoozedUntil!)}'),
      _ => (null, null),
    };
    final active = kind != null;
    final big = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final timeStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: active ? brand : muted);
    final accent = switch (st) {
      OccStatus.missed => dangerRed,
      OccStatus.due || OccStatus.snoozed => warnOrange,
      _ => lineColor,
    };

    return SoftCard(
      borderColor: accent,
      borderWidth: active ? 2 : 1,
      onTap: () => showOccurrenceSheet(context, store, occ, state,
          onTake: () => _take(context), onSnooze: () => _askSnooze(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!big)
                SizedBox(
                  width: 66,
                  child: Text(hm(occ.planned), style: timeStyle),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (big) Text(hm(occ.planned), style: timeStyle),
                    Text(occ.medName, style: t.titleMedium),
                    Text(formatQuantity(occ.reminder.quantity, occ.reminder.unit), style: t.bodyLarge),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(notes, style: t.bodySmall),
                      ),
                  ],
                ),
              ),
              if (!active) const Icon(Icons.chevron_right_rounded, size: 30, color: muted),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: StatusPill(kind, text!)),
            const SizedBox(height: 14),
            if (st == OccStatus.missed)
              BigButton('Je l\'ai pris quand même',
                  icon: Icons.check_rounded, onPressed: () => _take(context))
            else
              ButtonPair(
                BigButton('J\'ai pris', icon: Icons.check_rounded, onPressed: () => _take(context)),
                BigButton('Plus tard',
                    icon: Icons.snooze_rounded,
                    kind: BigButtonKind.outline,
                    onPressed: () => _askSnooze(context)),
              ),
          ],
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
