import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/logic.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'med_edit_screen.dart';
import 'reminder_edit_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Enregistrer une prise ponctuelle (hors rappel), ou corriger une ligne
/// de l'historique ([entry] fourni).
class IntakeScreen extends StatefulWidget {
  final AppStore store;
  final HistoryEntry? entry;

  /// Ouvre la correction d'un oubli directement sur « Pris ».
  final bool startTaken;
  const IntakeScreen({super.key, required this.store, this.entry, this.startTaken = false});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  String? medId;
  double quantity = 1;
  String unit = 'comprimé';
  DateTime at = DateTime.now();
  HistoryStatus status = HistoryStatus.pris;
  bool earlier = false; // prise hors rappel : « Plus tôt » plutôt que maintenant

  HistoryEntry? get entry => widget.entry;
  bool get isNew => entry == null;
  bool get manual => entry == null || entry!.manual;

  @override
  void initState() {
    super.initState();
    final e = entry;
    if (e != null) {
      medId = e.medId;
      quantity = e.quantity;
      unit = units.contains(e.unit) ? e.unit : 'comprimé';
      at = e.actual ?? e.planned;
      status = widget.startTaken ? HistoryStatus.pris : e.status;
    } else if (widget.store.data.meds.length == 1) {
      medId = widget.store.data.meds.first.id;
    }
  }

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: dayOnly(at).isAfter(today) ? today : dayOnly(at),
      firstDate: today.subtract(const Duration(days: 3650)),
      lastDate: today,
      helpText: 'Jour de la prise',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (d != null) setState(() => at = DateTime(d.year, d.month, d.day, at.hour, at.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: at.hour, minute: at.minute),
      helpText: 'Heure de la prise',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => at = DateTime(at.year, at.month, at.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final store = widget.store;
    if (isNew && !earlier) at = DateTime.now();
    if (status == HistoryStatus.pris && at.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      showMessage(context, 'L\'heure de prise ne peut pas être dans le futur.');
      return;
    }
    if (isNew) {
      final med = medId == null ? null : store.data.med(medId!);
      if (med == null) {
        showMessage(context, 'Choisissez d\'abord un médicament.');
        return;
      }
      await store.addManualIntake(med, quantity, unit, at);
      if (mounted) showMessage(context, 'Prise enregistrée : ${med.name}.');
    } else {
      final e = entry!;
      final HistoryEntry updated;
      if (e.manual) {
        final med = medId == null ? null : store.data.med(medId!);
        updated = e.copyWith(
          medId: med?.id,
          medName: med?.name,
          quantity: quantity,
          unit: unit,
          date: dateKey(at),
          planned: at,
          actual: at,
        );
      } else if (status == HistoryStatus.pris) {
        updated = e.copyWith(status: HistoryStatus.pris, actual: at, quantity: quantity, unit: unit);
      } else {
        updated = HistoryEntry(
          id: e.id,
          reminderId: e.reminderId,
          medId: e.medId,
          medName: e.medName,
          quantity: quantity,
          unit: unit,
          date: e.date,
          planned: e.planned,
          status: HistoryStatus.oublie,
          once: e.once,
        );
      }
      await store.updateEntry(updated);
      if (mounted) showMessage(context, 'Correction enregistrée.');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Supprimer cette ligne ?',
        text: manual
            ? 'Cette prise ponctuelle sera retirée de l\'historique.'
            : 'Cette ligne sera retirée de l\'historique. Si la prise n\'est plus notée « prise », '
                'elle pourra de nouveau apparaître comme oubliée.',
        confirm: 'Supprimer',
        danger: true);
    if (!ok) return;
    await widget.store.deleteEntry(entry!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _newMed() async {
    final m = await Navigator.push<Medication>(
        context, MaterialPageRoute(builder: (_) => MedEditScreen(store: widget.store)));
    if (m != null) setState(() => medId = m.id);
  }

  void _setUnit(String u) => setState(() {
        unit = u;
        final step = quantityStep(u);
        quantity = (quantity / step).round() * step;
        if (quantity < step) quantity = step;
      });

  Widget _lastIntakeNote(BuildContext context) {
    final id = medId;
    if (id == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final last = lastTakenOn(widget.store.history, id, now);
    if (last == null) return const SizedBox.shrink();
    final notes = widget.store.data.med(id)?.notes.trim() ?? '';
    final ago = durationLabel(now.difference(last.actual!));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: warnSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: warnOrange, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule_rounded, color: warnOrange, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dernière prise aujourd\'hui à ${hm(last.actual!)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: warnOrange)),
                    Text(
                        'Il y a $ago.${notes.isEmpty ? '' : ' Votre consigne : $notes'}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = entry;
    final snooze = e?.status == HistoryStatus.decale;
    final title = isNew
        ? 'J\'ai pris un médicament'
        : manual
            ? 'Corriger la prise hors rappel'
            : 'Corriger une prise';
    final dateText = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(at);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ScreenHeader(title,
                  subtitle: isNew ? 'Une prise en plus, en dehors de vos rappels.' : null,
                  showBack: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!manual)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MedAvatar(widget.store.data.med(e!.medId), size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.medName, style: t.titleMedium),
                                  Text('Prévu le ${DateFormat('EEEE d MMMM', 'fr_FR').format(e.planned)} à ${hm(e.planned)}',
                                      style: t.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (snooze) ...[
                      const SizedBox(height: 16),
                      Text(
                          'Report demandé${e!.actual == null ? '' : ' à ${hm(e.actual!)}'}'
                          '${e.until == null ? '' : ', nouveau rappel à ${hm(e.until!)}'}.',
                          style: t.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Un report ne se corrige pas : vous pouvez seulement le supprimer.',
                          style: t.bodyMedium),
                    ] else ...[
                      if (manual) ...[
                        FieldLabel(isNew ? 'Lequel ?' : 'Quel médicament ?'),
                        if (widget.store.data.meds.isEmpty)
                          Text('Votre bibliothèque est vide : ajoutez un médicament.', style: t.bodyLarge),
                        for (final m in widget.store.data.meds)
                          MedChoice(med: m, selected: m.id == medId, onTap: () => setState(() => medId = m.id)),
                        BigButton('Ajouter un médicament',
                            icon: Icons.add_rounded, kind: BigButtonKind.text, onPressed: _newMed),
                        if (isNew) _lastIntakeNote(context),
                      ] else ...[
                        const FieldLabel('Statut'),
                        Segmented<HistoryStatus>(
                          options: const [
                            (HistoryStatus.pris, 'Pris', Icons.check_rounded),
                            (HistoryStatus.oublie, 'Oublié', Icons.close_rounded),
                          ],
                          value: status,
                          selectedColor: status == HistoryStatus.pris ? okGreen : dangerRed,
                          onChanged: (v) => setState(() => status = v),
                        ),
                      ],
                      if (status == HistoryStatus.pris) ...[
                        FieldLabel(isNew ? 'Quand ?' : 'Quand l\'avez-vous pris ?'),
                        if (isNew) ...[
                          Segmented<bool>(
                            options: const [
                              (false, 'Maintenant', Icons.check_rounded),
                              (true, 'Plus tôt...', Icons.schedule_rounded),
                            ],
                            value: earlier,
                            onChanged: (v) => setState(() {
                              earlier = v;
                              if (!v) at = DateTime.now();
                            }),
                          ),
                          if (!earlier)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 2),
                              child: Text('${dateText[0].toUpperCase()}${dateText.substring(1)} à ${hm(at)}',
                                  style: t.bodySmall),
                            ),
                        ],
                        if (!isNew || earlier) ...[
                          if (isNew) const SizedBox(height: 14),
                          FieldButton(
                              label: 'Date',
                              value: '${dateText[0].toUpperCase()}${dateText.substring(1)}',
                              icon: Icons.calendar_month_rounded,
                              onTap: _pickDate),
                          const SizedBox(height: 14),
                          FieldButton(
                              label: 'Heure', value: hm(at), icon: Icons.schedule_rounded, onTap: _pickTime),
                        ],
                      ],
                      FieldLabel(isNew ? 'Combien ?' : 'Quantité prise'),
                      QuantityStepper(
                          quantity: quantity, unit: unit, onChanged: (q) => setState(() => quantity = q)),
                      const SizedBox(height: 12),
                      UnitPicker(unit: unit, all: units, onChanged: _setUnit),
                      const SizedBox(height: 28),
                      BigButton(isNew ? 'Enregistrer la prise' : 'Enregistrer la correction',
                          icon: Icons.check_rounded, onPressed: _save),
                    ],
                    if (!isNew) ...[
                      const SizedBox(height: 8),
                      BigButton('Supprimer cette ligne',
                          icon: Icons.delete_outline_rounded,
                          kind: BigButtonKind.text,
                          color: dangerRed,
                          onPressed: _delete),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
