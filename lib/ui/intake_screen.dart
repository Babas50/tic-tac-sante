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
  const IntakeScreen({super.key, required this.store, this.entry});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  String? medId;
  double quantity = 1;
  String unit = 'comprimé';
  DateTime at = DateTime.now();
  HistoryStatus status = HistoryStatus.pris;

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
      status = e.status;
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
      if (mounted) showMessage(context, 'Prise ponctuelle enregistrée : ${med.name}.');
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = entry;
    final snooze = e?.status == HistoryStatus.decale;
    final title = isNew
        ? 'Prise ponctuelle'
        : manual
            ? 'Corriger la prise ponctuelle'
            : 'Corriger une prise';
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ScreenHeader(title,
                  subtitle: isNew
                      ? 'Un médicament pris en dehors des rappels, par exemple contre une douleur.'
                      : null,
                  showBack: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!manual) ...[
                      SoftCard(
                        color: const Color(0xFFEDE5FF),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e!.medName, style: t.titleLarge),
                            Text('Prévu le ${DateFormat('EEEE d MMMM', 'fr_FR').format(e.planned)} à ${hm(e.planned)}',
                                style: t.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                    if (snooze) ...[
                      const SizedBox(height: 12),
                      Text(
                          'Report demandé${e!.actual == null ? '' : ' à ${hm(e.actual!)}'}'
                          '${e.until == null ? '' : ', nouveau rappel à ${hm(e.until!)}'}.',
                          style: t.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Un report ne se corrige pas : vous pouvez seulement le supprimer.',
                          style: t.bodyMedium),
                    ] else ...[
                      if (manual) ...[
                        const FieldLabel('Quel médicament ?'),
                        if (widget.store.data.meds.isEmpty)
                          Text('Votre bibliothèque est vide : ajoutez un médicament.', style: t.bodyLarge),
                        for (final m in widget.store.data.meds)
                          MedChoice(med: m, selected: m.id == medId, onTap: () => setState(() => medId = m.id)),
                        BigButton('Nouveau médicament',
                            icon: Icons.add_rounded, kind: BigButtonKind.outline, onPressed: _newMed),
                      ] else ...[
                        const FieldLabel('Statut'),
                        ButtonPair(
                          BigButton('Pris',
                              icon: status == HistoryStatus.pris ? Icons.check_circle_rounded : Icons.check_rounded,
                              kind: status == HistoryStatus.pris ? BigButtonKind.success : BigButtonKind.outline,
                              onPressed: () => setState(() => status = HistoryStatus.pris)),
                          BigButton('Oublié',
                              icon: status == HistoryStatus.oublie ? Icons.check_circle_rounded : Icons.close_rounded,
                              kind: status == HistoryStatus.oublie ? BigButtonKind.danger : BigButtonKind.outline,
                              onPressed: () => setState(() => status = HistoryStatus.oublie)),
                        ),
                      ],
                      if (status == HistoryStatus.pris) ...[
                        const FieldLabel('Quand l\'avez-vous pris ?'),
                        BigButton('Le ${DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(at)}',
                            icon: Icons.calendar_month_rounded,
                            kind: BigButtonKind.soft,
                            color: brand,
                            onPressed: _pickDate),
                        const SizedBox(height: 10),
                        BigButton('À ${hm(at)}',
                            icon: Icons.access_time_rounded,
                            kind: BigButtonKind.soft,
                            color: brand,
                            onPressed: _pickTime),
                      ],
                      const FieldLabel('Quelle quantité ?'),
                      QuantityStepper(
                          quantity: quantity, unit: unit, onChanged: (q) => setState(() => quantity = q)),
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
                      const SizedBox(height: 24),
                      BigButton(isNew ? 'Enregistrer la prise' : 'Enregistrer la correction',
                          icon: Icons.check_rounded, kind: BigButtonKind.success, onPressed: _save),
                    ],
                    if (!isNew) ...[
                      const SizedBox(height: 12),
                      BigButton('Supprimer cette ligne',
                          icon: Icons.delete_outline_rounded,
                          kind: BigButtonKind.soft,
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
