// Panneau ouvert en touchant une prise (écran Aujourd'hui ou Historique).
// Toute correction demande deux gestes volontaires : ouvrir le panneau, puis
// choisir l'action. Aucune annulation possible d'un seul appui.

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'intake_screen.dart';
import 'reminder_edit_screen.dart';
import 'theme.dart';
import 'widgets.dart';

IntakeKind entryKind(HistoryEntry h) => switch (h.status) {
      HistoryStatus.pris => h.manual ? IntakeKind.extra : IntakeKind.taken,
      HistoryStatus.decale => IntakeKind.snoozed,
      HistoryStatus.oublie => IntakeKind.missed,
    };

/// Libellé du résultat d'une ligne d'historique.
String entryLabel(HistoryEntry h) {
  final a = h.actual;
  final otherDay = a != null && dateKey(a) != h.date;
  return switch (h.status) {
    HistoryStatus.pris when h.manual => 'Prise en plus',
    HistoryStatus.pris => a == null
        ? 'Pris'
        : otherDay
            ? 'Pris le ${DateFormat('d/MM', 'fr_FR').format(a)} à ${hm(a)}'
            : 'Pris à ${hm(a)}',
    HistoryStatus.decale => 'Reporté à ${h.until == null ? '?' : hm(h.until!)}',
    HistoryStatus.oublie => 'Oublié',
  };
}

class _SheetHeader extends StatelessWidget {
  final String context_;
  final Medication? med;
  final String name;
  final String quantity;
  final IntakeKind kind;
  final String status;
  const _SheetHeader(
      {required this.context_,
      required this.med,
      required this.name,
      required this.quantity,
      required this.kind,
      required this.status});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context_, style: t.bodySmall),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MedAvatar(med, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.titleLarge),
                  Text(quantity, style: t.bodyLarge),
                  const SizedBox(height: 8),
                  StatusPill(kind, status),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _dayLabel(DateTime d) {
  final s = DateFormat('EEEE d MMMM', 'fr_FR').format(d);
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Panneau d'une ligne d'historique (prise, prise en plus, report, oubli).
Future<void> showEntrySheet(BuildContext context, AppStore store, HistoryEntry h) {
  final kind = entryKind(h);
  final where = h.manual
      ? 'Prise hors rappel, ${_dayLabel(h.actual ?? h.planned).toLowerCase()}'
      : '${_dayLabel(h.planned)}, prévu à ${hm(h.planned)}';
  void open(BuildContext ctx, {bool taken = false}) {
    Navigator.pop(ctx);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => IntakeScreen(store: store, entry: h, startTaken: taken)));
  }

  Future<void> remove(BuildContext ctx, String message) async {
    Navigator.pop(ctx);
    await store.deleteEntry(h);
    if (context.mounted) showMessage(context, message);
  }

  return showActionSheet(
    context,
    header: _SheetHeader(
      context_: where,
      med: store.data.med(h.medId),
      name: h.medName,
      quantity: formatQuantity(h.quantity, h.unit),
      kind: kind,
      status: entryLabel(h),
    ),
    actions: [
      Builder(builder: (ctx) {
        return switch (h.status) {
          HistoryStatus.oublie => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BigButton('En fait, je l\'ai pris',
                    icon: Icons.check_rounded, onPressed: () => open(ctx, taken: true)),
                const SizedBox(height: 10),
                BigButton('Supprimer cette ligne',
                    icon: Icons.delete_outline_rounded,
                    kind: BigButtonKind.text,
                    color: dangerRed,
                    onPressed: () => remove(ctx, 'Ligne supprimée.')),
              ],
            ),
          HistoryStatus.decale => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Un report ne se corrige pas : vous pouvez seulement le supprimer.',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 10),
                BigButton('Supprimer ce report',
                    icon: Icons.delete_outline_rounded,
                    kind: BigButtonKind.soft,
                    color: dangerRed,
                    onPressed: () => remove(ctx, 'Report supprimé.')),
              ],
            ),
          HistoryStatus.pris => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BigButton('Corriger l\'heure ou la quantité',
                    icon: Icons.edit_rounded, kind: BigButtonKind.outline, onPressed: () => open(ctx)),
                const SizedBox(height: 10),
                BigButton(h.manual ? 'Supprimer cette prise' : 'Je ne l\'ai pas pris',
                    icon: h.manual ? Icons.delete_outline_rounded : Icons.undo_rounded,
                    kind: BigButtonKind.soft,
                    color: dangerRed,
                    onPressed: () => remove(
                        ctx, h.manual ? 'Prise supprimée.' : 'C\'est noté : ${h.medName} n\'est plus marqué pris.')),
              ],
            ),
        };
      }),
      Builder(
          builder: (ctx) => BigButton('Fermer', kind: BigButtonKind.text, onPressed: () => Navigator.pop(ctx))),
    ],
  );
}

/// Panneau d'une prise prévue pas encore faite (pour la noter en avance,
/// la reporter ou modifier le rappel).
Future<void> showOccurrenceSheet(BuildContext context, AppStore store, Occurrence o, OccState st,
    {required Future<void> Function() onTake, required Future<void> Function() onSnooze}) {
  final (kind, status) = switch (st.status) {
    OccStatus.snoozed => (IntakeKind.snoozed, 'Reporté à ${hm(st.snoozedUntil!)}'),
    OccStatus.due => (IntakeKind.due, 'À prendre maintenant'),
    OccStatus.missed => (IntakeKind.missed, 'Oublié'),
    _ => (IntakeKind.upcoming, 'Prévu à ${hm(o.planned)}'),
  };
  return showActionSheet(
    context,
    header: _SheetHeader(
      context_: '${_dayLabel(o.planned)}, prévu à ${hm(o.planned)}',
      med: o.med,
      name: o.medName,
      quantity: formatQuantity(o.reminder.quantity, o.reminder.unit),
      kind: kind,
      status: status,
    ),
    actions: [
      Builder(
          builder: (ctx) => BigButton(st.status == OccStatus.missed ? 'Je l\'ai pris quand même' : 'J\'ai pris',
              icon: Icons.check_rounded, onPressed: () {
            Navigator.pop(ctx);
            onTake();
          })),
      if (st.status != OccStatus.missed)
        Builder(
            builder: (ctx) => BigButton('Plus tard',
                icon: Icons.snooze_rounded, kind: BigButtonKind.outline, onPressed: () {
              Navigator.pop(ctx);
              onSnooze();
            })),
      Builder(
          builder: (ctx) => BigButton('Modifier ce rappel',
              icon: Icons.edit_rounded, kind: BigButtonKind.text, onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ReminderEditScreen(store: store, reminder: o.reminder)));
          })),
      Builder(
          builder: (ctx) => BigButton('Fermer', kind: BigButtonKind.text, onPressed: () => Navigator.pop(ctx))),
    ],
  );
}
