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
    final store = widget.store;
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
        createdAt: existing?.createdAt ?? DateTime.now(),
        nid: existing?.nid ?? store.takeNid(),
      );
      await store.saveReminder(r);
    }
    if (!mounted) return;
    showMessage(context,
        times.length > 1 ? '${times.length} rappels enregistrés.' : 'Rappel enregistré.');
    Navigator.pop(context);
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
                      for (final m in meds) _MedChoice(
                        med: m,
                        selected: m.id == medId,
                        onTap: () => setState(() => medId = m.id),
                      ),
                      const SizedBox(height: 4),
                      BigButton('Nouveau médicament',
                          icon: Icons.add_rounded, kind: BigButtonKind.outline, onPressed: _newMed),

                      const FieldLabel('2. Quand ?'),
                      ButtonPair(
                        _Toggle(
                          label: 'Tous les jours',
                          icon: Icons.repeat_rounded,
                          selected: type == ReminderType.daily,
                          onTap: () => setState(() => type = ReminderType.daily),
                        ),
                        _Toggle(
                          label: 'Une seule fois',
                          icon: Icons.event_rounded,
                          selected: type == ReminderType.once,
                          onTap: () => setState(() => type = ReminderType.once),
                        ),
                      ),
                      if (type == ReminderType.once) ...[
                        const SizedBox(height: 10),
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
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
                      _QuantityStepper(
                        quantity: quantity,
                        unit: unit,
                        onChanged: (q) => setState(() => quantity = q),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final u in units)
                            ChoiceChip(
                              label: Text(u, style: const TextStyle(fontSize: 18)),
                              padding: const EdgeInsets.all(8),
                              selected: unit == u,
                              onSelected: (_) => setState(() {
                                unit = u;
                                final step = quantityStep(u);
                                quantity = (quantity / step).round() * step;
                                if (quantity < step) quantity = step;
                              }),
                            ),
                        ],
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
                            kind: BigButtonKind.soft,
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

class _MedChoice extends StatelessWidget {
  final Medication med;
  final bool selected;
  final VoidCallback onTap;
  const _MedChoice({required this.med, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? const Color(0xFFEDE5FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: selected ? brand : const Color(0xFF8A8A8A), width: selected ? 3 : 1.5),
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
        icon: selected ? Icons.check_circle_rounded : icon,
        kind: selected ? BigButtonKind.primary : BigButtonKind.outline,
        onPressed: onTap,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final double quantity;
  final String unit;
  final ValueChanged<double> onChanged;
  const _QuantityStepper({required this.quantity, required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final step = quantityStep(unit);
    Widget btn(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
          width: 64,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(64, 64)),
            child: Icon(icon, size: 34, semanticLabel: tip),
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
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ),
        btn(Icons.add_rounded, 'Plus', quantity < 100 ? () => onChanged(quantity + step) : null),
      ],
    );
  }
}
