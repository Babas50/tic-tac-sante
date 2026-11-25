import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../core/store.dart';
import 'med_edit_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Création ou modification d'un rappel.
class ReminderEditScreen extends StatefulWidget {
  final AppStore store;
  final Reminder? reminder;
  final String? medId;
  const ReminderEditScreen({super.key, required this.store, this.reminder, this.medId});

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  String? medId;
  ReminderType type = ReminderType.daily;
  DateTime onceDate = DateTime.now();
  final List<TimeOfDay> times = [];
  double quantity = 1;
  String unit = 'comprimé';
  bool active = true;
  _Freq freq = _Freq.daily;
  int customDays = 4;
  DateTime startDate = dayOnly(DateTime.now());
  final Set<int> weekdays = {};

  bool get editing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    if (r != null) {
      medId = r.medId;
      type = r.type;
      if (r.date != null) onceDate = parseDateKey(r.date!);
      times.add(TimeOfDay(hour: r.hour, minute: r.minute));
      quantity = r.quantity;
      unit = r.unit;
      active = r.active;
      if (r.startDate != null) startDate = parseDateKey(r.startDate!);
      weekdays.addAll(r.weekdays);
      if (r.type == ReminderType.once) {
        freq = _Freq.once;
      } else if (r.repeat == Recurrence.weekdays) {
        freq = _Freq.weekdays;
      } else {
        freq = switch (r.intervalDays) {
          1 => _Freq.daily,
          2 => _Freq.every2,
          3 => _Freq.every3,
          _ => _Freq.everyN,
        };
        if (r.intervalDays > 3) customDays = r.intervalDays;
      }
    } else {
      medId = widget.medId ??
          (widget.store.data.meds.length == 1 ? widget.store.data.meds.first.id : null);
    }
  }

  Future<void> _addTime([TimeOfDay? preset]) async {
    final t = preset ??
        await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 8, minute: 0),
          helpText: 'Choisissez l\'heure',
          cancelText: 'Annuler',
          confirmText: 'Valider',
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
    if (t == null) return;
    setState(() {
      if (editing) times.clear();
      if (!times.contains(t)) times.add(t);
      times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    });
  }

  Future<void> _pickStart() async {
    final today = dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Premier jour de prise',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (d != null) setState(() => startDate = d);
  }

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: onceDate.isBefore(today) ? today : onceDate,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Choisissez le jour',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (d != null) setState(() => onceDate = d);
  }

  Future<void> _newMed() async {
    final m = await Navigator.push<Medication>(
        context, MaterialPageRoute(builder: (_) => MedEditScreen(store: widget.store)));
    if (m != null) setState(() => medId = m.id);
  }

  Future<void> _save() async {
    if (medId == null || widget.store.data.med(medId!) == null) {
      showMessage(context, 'Choisissez d\'abord un médicament.');
      return;
    }
    if (times.isEmpty) {
      showMessage(context, 'Ajoutez au moins une heure.');
      return;
    }
    if (freq == _Freq.weekdays && weekdays.isEmpty) {
      showMessage(context, 'Choisissez au moins un jour de la semaine.');
      return;
    }
    final store = widget.store;
    type = freq == _Freq.once ? ReminderType.once : ReminderType.daily;
    final interval = switch (freq) {
      _Freq.every2 => 2,
      _Freq.every3 => 3,
      _Freq.everyN => customDays,
      _ => 1,
    };
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final existing = (i == 0) ? widget.reminder : null;
      final r = Reminder(
        id: existing?.id ?? newId(),
        medId: medId!,
        type: type,
        hour: t.hour,
        minute: t.minute,
        date: type == ReminderType.once ? dateKey(onceDate) : null,
        quantity: quantity,
        unit: unit,
        active: active,
        createdAt: _createdAt(existing),
        nid: existing?.nid ?? store.takeNid(),
        repeat: freq == _Freq.weekdays ? Recurrence.weekdays : Recurrence.interval,
        intervalDays: interval,
        startDate: interval > 1 ? dateKey(startDate) : null,
        weekdays: freq == _Freq.weekdays ? (weekdays.toList()..sort()) : [],
      );
      await store.saveReminder(r);
    }
    if (!mounted) return;
    showMessage(context,
        times.length > 1 ? '${times.length} rappels enregistrés.' : 'Rappel enregistré.');
    Navigator.pop(context);
  }

  /// Un cycle « 1 jour sur N » qui démarre dans le passé doit pouvoir
  /// s'appliquer dès aujourd'hui : la création ne doit pas être postérieure
  /// au premier jour.
  DateTime _createdAt(Reminder? existing) {
    final now = DateTime.now();
    final base = existing?.createdAt ?? now;
    if (freq != _Freq.daily && freq != _Freq.once && startDate.isBefore(base)) {
      return base.isBefore(dayOnly(now)) ? base : dayOnly(now);
    }
    return base;
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Supprimer ce rappel ?',
        text: 'Le rappel ne sonnera plus. L\'historique déjà enregistré est conservé.',
        confirm: 'Supprimer',
        danger: true);
    if (!ok) return;
    await widget.store.deleteReminder(widget.reminder!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final meds = widget.store.data.meds;
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ScreenHeader(editing ? 'Modifier le rappel' : 'Nouveau rappel', showBack: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('1. Quel médicament ?'),
                      if (meds.isEmpty)
                        Text('Votre bibliothèque est vide : ajoutez un médicament.', style: t.bodyLarge),
                      for (final m in meds) MedChoice(
                        med: m,
                        selected: m.id == medId,
                        onTap: () => setState(() => medId = m.id),
                      ),
                      const SizedBox(height: 4),
                      BigButton('Ajouter un médicament',
                          icon: Icons.add_rounded, kind: BigButtonKind.text, onPressed: _newMed),

                      const FieldLabel('2. À quelle fréquence ?'),
                      _Grid(children: [
                        for (final (f, label, icon) in const [
                          (_Freq.daily, 'Tous les jours', Icons.repeat_rounded),
                          (_Freq.every2, '1 jour sur 2', Icons.looks_two_rounded),
                          (_Freq.every3, '1 jour sur 3', Icons.looks_3_rounded),
                          (_Freq.everyN, 'Tous les ... jours', Icons.more_time_rounded),
                          (_Freq.weekdays, 'Certains jours de la semaine', Icons.view_week_rounded),
                          (_Freq.once, 'Une seule fois', Icons.event_rounded),
                        ])
                          _Toggle(
                            label: label,
                            icon: icon,
                            selected: freq == f,
                            onTap: () => setState(() => freq = f),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      if (freq == _Freq.everyN) ...[
                        const SizedBox(height: 4),
                        _Stepper(
                          text: 'Tous les $customDays jours',
                          onMinus: customDays > 2 ? () => setState(() => customDays--) : null,
                          onPlus: customDays < 60 ? () => setState(() => customDays++) : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (freq == _Freq.every2 || freq == _Freq.every3 || freq == _Freq.everyN) ...[
                        const SizedBox(height: 4),
                        Text('Premier jour de prise :', style: t.bodyLarge),
                        const SizedBox(height: 6),
                        BigButton(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(startDate),
                          icon: Icons.calendar_month_rounded,
                          kind: BigButtonKind.soft,
                          color: brand,
                          onPressed: _pickStart,
                        ),
                      ],
                      if (freq == _Freq.weekdays) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var d = 1; d <= 7; d++)
                              FilterChip(
                                label: Text(weekdayLong[d - 1], style: const TextStyle(fontSize: 19)),
                                padding: const EdgeInsets.all(8),
                                selected: weekdays.contains(d),
                                onSelected: (v) => setState(() => v ? weekdays.add(d) : weekdays.remove(d)),
                              ),
                          ],
                        ),
                      ],
                      if (freq == _Freq.once) ...[
                        const SizedBox(height: 4),
                        BigButton(
                          'Le ${DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(onceDate)}',
                          icon: Icons.calendar_month_rounded,
                          kind: BigButtonKind.soft,
                          color: brand,
                          onPressed: _pickDate,
                        ),
                      ],

                      FieldLabel(editing ? '3. À quelle heure ?' : '3. À quelle(s) heure(s) ?',
                          help: editing ? null : 'Vous pouvez ajouter plusieurs heures.'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final tm in times)
                            InputChip(
                              label: Text(hmOf(tm.hour, tm.minute),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              backgroundColor: momentStyle(momentOf(tm.hour)).background,
                              deleteIcon: const Icon(Icons.close_rounded, size: 26),
                              onDeleted: () => setState(() => times.remove(tm)),
                              onPressed: editing ? () => _addTime() : null,
                            ),
                        ],
                      ),
                      if (times.isNotEmpty) const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final (label, tm) in const [
                            ('Matin 8 h', TimeOfDay(hour: 8, minute: 0)),
                            ('Midi 12 h', TimeOfDay(hour: 12, minute: 0)),
                            ('Soir 19 h', TimeOfDay(hour: 19, minute: 0)),
                            ('Coucher 22 h', TimeOfDay(hour: 22, minute: 0)),
                          ])
                            ActionChip(
                              avatar: Icon(momentStyle(momentOf(tm.hour)).icon,
                                  color: momentStyle(momentOf(tm.hour)).accent),
                              label: Text(label, style: const TextStyle(fontSize: 18)),
                              padding: const EdgeInsets.all(8),
                              backgroundColor: momentStyle(momentOf(tm.hour)).background,
                              onPressed: () => _addTime(tm),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BigButton(editing ? 'Changer l\'heure' : 'Autre heure...',
                          icon: Icons.access_time_rounded,
                          kind: BigButtonKind.outline,
                          onPressed: () => _addTime()),

                      const FieldLabel('4. Quelle quantité ?'),
                      QuantityStepper(
                        quantity: quantity,
                        unit: unit,
                        onChanged: (q) => setState(() => quantity = q),
                      ),
                      const SizedBox(height: 10),
                      UnitPicker(
                        unit: unit,
                        all: units,
                        onChanged: (u) => setState(() {
                          unit = u;
                          final step = quantityStep(u);
                          quantity = (quantity / step).round() * step;
                          if (quantity < step) quantity = step;
                        }),
                      ),
                      if (editing) ...[
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (v) => setState(() => active = v),
                          title: Text('Rappel actif', style: t.titleMedium),
                          subtitle: Text(
                              active ? 'Le rappel sonne normalement.' : 'Le rappel est en pause.',
                              style: t.bodyMedium),
                        ),
                      ],
                      const SizedBox(height: 24),
                      BigButton('Enregistrer le rappel',
                          icon: Icons.check_rounded, kind: BigButtonKind.success, onPressed: _save),
                      if (editing) ...[
                        const SizedBox(height: 12),
                        BigButton('Supprimer ce rappel',
                            icon: Icons.delete_outline_rounded,
                            kind: BigButtonKind.text,
                            color: dangerRed,
                            onPressed: _delete),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _Freq { daily, every2, every3, everyN, weekdays, once }

/// Deux colonnes de boutons, une seule si la police est grande.
class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final cols = scale > 1.25 || c.maxWidth < 340 ? 1 : 2;
      if (cols == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        );
      }
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        if (i > 0) rows.add(const SizedBox(height: 8));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// Valeur centrale avec boutons − et + (64 px).
class _Stepper extends StatelessWidget {
  final String text;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _Stepper({required this.text, this.onMinus, this.onPlus});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, VoidCallback? onTap, {bool filled = false}) => SizedBox(
          width: 60,
          child: filled
              ? ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 60)),
                  child: Icon(icon, size: 30, semanticLabel: tip),
                )
              : OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 60)),
                  child: Icon(icon, size: 30, semanticLabel: tip),
                ),
        );
    return Row(
      children: [
        btn(Icons.remove_rounded, 'Moins', onMinus),
        Expanded(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        btn(Icons.add_rounded, 'Plus', onPlus, filled: true),
      ],
    );
  }
}

class MedChoice extends StatelessWidget {
  final Medication med;
  final bool selected;
  final VoidCallback onTap;
  const MedChoice({super.key, required this.med, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? surfaceAlt : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: selected ? brand : lineColor, width: selected ? 2.5 : 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  MedAvatar(med, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name, style: t.titleMedium),
                        if (med.notes.trim().isNotEmpty) Text(med.notes, style: t.bodySmall),
                      ],
                    ),
                  ),
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: selected ? brand : ink, size: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Toggle({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: BigButton(
        label,
        icon: selected ? Icons.check_rounded : icon,
        kind: selected ? BigButtonKind.primary : BigButtonKind.soft,
        color: selected ? null : ink,
        onPressed: onTap,
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  const QuantityStepper({super.key, required this.quantity, required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final step = quantityStep(unit);
    Widget btn(IconData icon, String tip, VoidCallback? onTap, {bool filled = false}) => SizedBox(
          width: 60,
          child: filled
              ? ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 60)),
                  child: Icon(icon, size: 30, semanticLabel: tip),
                )
              : OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 60)),
                  child: Icon(icon, size: 30, semanticLabel: tip),
                ),
        );
    return Row(
      children: [
        btn(Icons.remove_rounded, 'Moins',
            quantity - step >= step - 0.001 ? () => onChanged(quantity - step) : null),
        Expanded(
          child: Text(
            formatQuantity(quantity, unit),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        btn(Icons.add_rounded, 'Plus', quantity < 100 ? () => onChanged(quantity + step) : null, filled: true),
      ],
    );
  }
}
