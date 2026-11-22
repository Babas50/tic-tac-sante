import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'intake_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  final AppStore store;
  const HistoryScreen({super.key, required this.store});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int days = 7; // 0 = tout

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final now = DateTime.now();
        final from = days == 0
            ? DateTime(2000)
            : dayOnly(now).subtract(Duration(days: days - 1));
        final fromK = dateKey(from);
        final list = widget.store.history.where((h) => h.date.compareTo(fromK) >= 0).toList()
          ..sort((a, b) {
            final c = b.date.compareTo(a.date);
            if (c != 0) return c;
            return (b.actual ?? b.planned).compareTo(a.actual ?? a.planned);
          });
        final stats = computeStats(widget.store.history, from, now);

        final children = <Widget>[
          const ScreenHeader('Historique',
              subtitle: 'Toutes vos prises, reports et oublis. Touchez une ligne pour la corriger.'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: BigButton('Ajouter une prise ponctuelle',
                icon: Icons.add_task_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => IntakeScreen(store: widget.store)))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, d) in const [('7 jours', 7), ('30 jours', 30), ('Tout', 0)])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 19)),
                    padding: const EdgeInsets.all(10),
                    selected: days == d,
                    onSelected: (_) => setState(() => days = d),
                  ),
              ],
            ),
          ),
          if (stats.total.planned > 0)
            SoftCard(
              color: const Color(0xFFEDE5FF),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 40, color: brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Prises respectées : ${percent(stats.total.rate)}\n'
                      '${stats.total.taken} sur ${stats.total.planned}, ${stats.total.missed} oubli${stats.total.missed > 1 ? 's' : ''}',
                      style: t.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
        ];

        if (list.isEmpty) {
          children.add(const EmptyState(
            icon: Icons.history_rounded,
            title: 'Pas encore d\'historique',
            text: 'Chaque prise, report ou oubli s\'affichera ici.',
          ));
        }
        String? currentDay;
        for (final h in list) {
          if (h.date != currentDay) {
            currentDay = h.date;
            final label = DateFormat('EEEE d MMMM', 'fr_FR').format(parseDateKey(h.date));
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('${label[0].toUpperCase()}${label.substring(1)}', style: t.titleLarge),
            ));
          }
          children.add(_HistoryTile(widget.store, h));
        }
        children.add(const SizedBox(height: 24));
        return ListView(children: children);
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AppStore store;
  final HistoryEntry h;
  const _HistoryTile(this.store, this.h);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = h.actual;
    final otherDay = a != null && dateKey(a) != h.date;
    final (icon, color, label) = switch (h.status) {
      HistoryStatus.pris when h.manual => (Icons.add_task_rounded, okGreen, 'Prise ponctuelle'),
      HistoryStatus.pris => (Icons.check_circle_rounded, okGreen,
          'Pris ${a == null ? '' : otherDay ? 'le ${DateFormat('d/MM', 'fr_FR').format(a)} à ${hm(a)}' : 'à ${hm(a)}'}'),
      HistoryStatus.decale => (Icons.snooze_rounded, warnOrange,
          'Reporté à ${h.until == null ? '?' : hm(h.until!)}${h.actual == null ? '' : ' (demandé à ${hm(h.actual!)})'}'),
      HistoryStatus.oublie => (Icons.cancel_rounded, dangerRed, 'Oublié'),
    };
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => IntakeScreen(store: store, entry: h))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${hm(h.manual ? (a ?? h.planned) : h.planned)}  ${h.medName}', style: t.titleMedium),
                Text(formatQuantity(h.quantity, h.unit), style: t.bodyMedium),
                Text(label, style: t.bodyLarge!.copyWith(color: color, fontWeight: FontWeight.w800)),
                if (h.once)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Tag('Ponctuel'),
                  ),
              ],
            ),
          ),
          const Icon(Icons.edit_rounded, size: 26, semanticLabel: 'Corriger'),
        ],
      ),
    );
  }
}
