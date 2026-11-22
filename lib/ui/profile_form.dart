import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Nom et date de naissance (utilisés dans l'en-tête du PDF médecin).
class ProfileForm extends StatefulWidget {
  final AppStore store;
  const ProfileForm({super.key, required this.store});

  @override
  State<ProfileForm> createState() => ProfileFormState();
}

class ProfileFormState extends State<ProfileForm> {
  late final TextEditingController name =
      TextEditingController(text: widget.store.data.profile.name);
  late DateTime? birth = widget.store.data.profile.birthDate;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() => widget.store.setProfile(name.text, birth);

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: birth ?? DateTime(now.year - 70, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Date de naissance',
      fieldLabelText: 'Date (JJ/MM/AAAA)',
      fieldHintText: 'JJ/MM/AAAA',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      errorFormatText: 'Format attendu : JJ/MM/AAAA',
      errorInvalidText: 'Date invalide',
    );
    if (d != null) setState(() => birth = d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Prénom et nom'),
        TextField(
          controller: name,
          style: const TextStyle(fontSize: 22),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'ex. Marie Dupont'),
        ),
        const FieldLabel('Date de naissance'),
        BigButton(
          birth == null ? 'Choisir la date' : DateFormat('d MMMM yyyy', 'fr_FR').format(birth!),
          icon: Icons.cake_rounded,
          kind: BigButtonKind.soft,
          color: brand,
          onPressed: _pickBirth,
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final AppStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final key = GlobalKey<ProfileFormState>();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const ScreenHeader('Mon profil',
                subtitle: 'Ces informations apparaissent en haut du document pour le médecin.',
                showBack: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileForm(key: key, store: store),
                  const SizedBox(height: 28),
                  BigButton('Enregistrer',
                      icon: Icons.check_rounded,
                      kind: BigButtonKind.success,
                      onPressed: () async {
                        await key.currentState?.save();
                        if (context.mounted) Navigator.pop(context);
                      }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
