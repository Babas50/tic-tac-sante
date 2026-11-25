import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/store.dart';
import 'intake_screen.dart';
import 'intake_sheet.dart';
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
        final list = visibleHistory(widget.store.history).where((h) => h.date.compareTo(fromK) >= 0).toList()
          ..sort((a, b) {
            final c = b.date.compareTo(a.date);
            if (c != 0) return c;
            return (b.actual ?? b.planned).compareTo(a.actual ?? a.planned);
          });
        final stats = computeStats(widget.store.history, from, now);

        final children = <Widget>[
          const ScreenHeader('Historique', subtitle: 'Touchez une ligne pour la corriger.'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Segmented<int>(
              options: const [
                (7, '7 jours', Icons.date_range_rounded),
                (30, '30 jours', Icons.calendar_month_rounded),
                (0, 'Tout', Icons.history_rounded),
              ],
              value: days,
              onChanged: (d) => setState(() => days = d),
            ),
          ),
          if (stats.total.planned > 0) _StatsCard(stats.total),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: BigButton('Ajouter une prise hors rappel',
                icon: Icons.add_rounded,
                kind: BigButtonKind.outline,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => IntakeScreen(store: widget.store)))),
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
        final todayK = dateKey(now);
        final yesterdayK = dateKey(dayOnly(now).subtract(const Duration(days: 1)));
        for (final h in list) {
          if (h.date != currentDay) {
            currentDay = h.date;
            final label = DateFormat('EEEE d MMMM', 'fr_FR').format(parseDateKey(h.date));
            final prefix = h.date == todayK
                ? 'Aujourd\'hui, '
                : h.date == yesterdayK
                    ? 'Hier, '
                    : '';
            final text = prefix.isEmpty ? '${label[0].toUpperCase()}${label.substring(1)}' : '$prefix$label';
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Text(text, style: t.titleMedium),
            ));
          }
          children.add(CompactIntakeRow(
            kind: entryKind(h),
            time: hm(h.manual ? (h.actual ?? h.planned) : h.planned),
            title: h.medName,
            quantity: formatQuantity(h.quantity, h.unit),
            detail: entryLabel(h),
            onTap: () => showEntrySheet(context, widget.store, h),
          ));
        }
        children.add(const SizedBox(height: 24));
        return ListView(children: children);
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final MedStats total;
  const _StatsCard(this.total);

  @override
  Widget build(BuildContext context) {
    final planned = total.planned;
    final taken = total.taken;
    final missed = total.missed;
    final rate = total.rate;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(percent(rate),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: brand, height: 1.1)),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('des prises respectées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(brand),
            ),
          ),
          const SizedBox(height: 10),
          Text(
              '$taken prise${taken > 1 ? 's' : ''} sur $planned · $missed oubli${missed > 1 ? 's' : ''}'
              '${total.snoozed == 0 ? '' : ' (dont ${total.snoozed} après report)'}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
