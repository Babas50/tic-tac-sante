import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import '../core/storage.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Ajout ou modification d'un médicament de la bibliothèque.
/// Renvoie le médicament enregistré.
class MedEditScreen extends StatefulWidget {
  final AppStore store;
  final Medication? med;
  const MedEditScreen({super.key, required this.store, this.med});

  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController notes;
  late int colorIndex;
  late int iconIndex;

  @override
  void initState() {
    super.initState();
    final m = widget.med;
    name = TextEditingController(text: m?.name ?? '');
    description = TextEditingController(text: m?.description ?? '');
    notes = TextEditingController(text: m?.notes ?? '');
    colorIndex = m?.colorIndex ?? widget.store.data.meds.length % medColors.length;
    iconIndex = m?.iconIndex ?? 0;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      showMessage(context, 'Indiquez le nom du médicament.');
      return;
    }
    final m = Medication(
      id: widget.med?.id ?? newId(),
      name: name.text.trim(),
      description: description.text.trim(),
      notes: notes.text.trim(),
      colorIndex: colorIndex,
      iconIndex: iconIndex,
    );
    await widget.store.saveMed(m);
    if (mounted) Navigator.pop(context, m);
  }

  Future<void> _delete() async {
    final n = widget.store.remindersOf(widget.med!.id).length;
    final ok = await confirmDialog(context,
        title: 'Supprimer ${widget.med!.name} ?',
        text: n == 0
            ? 'Le médicament sera retiré de la bibliothèque.'
            : 'Le médicament et ses $n rappel${n > 1 ? 's' : ''} seront supprimés. L\'historique est conservé.',
        confirm: 'Supprimer',
        danger: true);
    if (!ok) return;
    await widget.store.deleteMed(widget.med!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = Medication(id: '', name: '', colorIndex: colorIndex, iconIndex: iconIndex);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ScreenHeader(widget.med == null ? 'Nouveau médicament' : 'Modifier le médicament',
                showBack: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: MedAvatar(preview, size: 88)),
                  const FieldLabel('Nom du médicament'),
                  TextField(
                    controller: name,
                    style: const TextStyle(fontSize: 22),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'ex. Doliprane 1000 mg'),
                  ),
                  const FieldLabel('Descriptif', help: 'À quoi il sert, sa forme... (facultatif)'),
                  TextField(
                    controller: description,
                    style: const TextStyle(fontSize: 20),
                    minLines: 1,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'ex. Contre la douleur, comprimé blanc'),
                  ),
                  const FieldLabel('Notes', help: 'Consignes importantes (facultatif)'),
                  TextField(
                    controller: notes,
                    style: const TextStyle(fontSize: 20),
                    minLines: 1,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'ex. 3 maximum par jour, pendant le repas'),
                  ),
                  const FieldLabel('Couleur'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < medColors.length; i++)
                        Semantics(
                          label: 'Couleur ${i + 1}',
                          selected: i == colorIndex,
                          button: true,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setState(() => colorIndex = i),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: medColors[i],
                                shape: BoxShape.circle,
                                border: Border.all(color: i == colorIndex ? ink : Colors.transparent, width: 4),
                              ),
                              child: i == colorIndex
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 32)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const FieldLabel('Forme'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < medIcons.length; i++)
                        Semantics(
                          label: 'Forme ${i + 1}',
                          selected: i == iconIndex,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => iconIndex = i),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: i == iconIndex ? const Color(0xFFEDE5FF) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: i == iconIndex ? brand : const Color(0xFF8A8A8A),
                                    width: i == iconIndex ? 3 : 1.5),
                              ),
                              child: Icon(medIcons[i], size: 34, color: medColors[colorIndex]),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BigButton('Enregistrer', icon: Icons.check_rounded, kind: BigButtonKind.success, onPressed: _save),
                  if (widget.med != null) ...[
                    const SizedBox(height: 12),
                    BigButton('Supprimer ce médicament',
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
    );
  }
}
