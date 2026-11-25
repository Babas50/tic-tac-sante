import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Nom et date de naissance (utilisés dans l'en-tête du PDF médecin), et
/// coordonnées du médecin pour lui envoyer ce PDF.
class ProfileForm extends StatefulWidget {
  final AppStore store;
  final bool showDoctor;
  const ProfileForm({super.key, required this.store, this.showDoctor = false});

  @override
  State<ProfileForm> createState() => ProfileFormState();
}

class ProfileFormState extends State<ProfileForm> {
  late final TextEditingController name =
      TextEditingController(text: widget.store.data.profile.name);
  late DateTime? birth = widget.store.data.profile.birthDate;
  late final TextEditingController doctorName =
      TextEditingController(text: widget.store.data.profile.doctorName);
  late final TextEditingController doctorEmail =
      TextEditingController(text: widget.store.data.profile.doctorEmail);

  @override
  void dispose() {
    name.dispose();
    doctorName.dispose();
    doctorEmail.dispose();
    super.dispose();
  }

  /// Faux si l'e-mail du médecin est mal écrit.
  bool get emailOk {
    final e = doctorEmail.text.trim();
    return e.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  Future<void> save() => widget.store.setProfile(name.text, birth,
      doctorName: widget.showDoctor ? doctorName.text : null,
      doctorEmail: widget.showDoctor ? doctorEmail.text : null);

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
        if (widget.showDoctor) ...[
          const SizedBox(height: 10),
          const FieldLabel('Votre médecin (facultatif)',
              help: 'Pour lui envoyer le PDF de suivi par e-mail en un geste.'),
          TextField(
            controller: doctorName,
            style: const TextStyle(fontSize: 20),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom', hintText: 'ex. Dr Martin'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: doctorEmail,
            style: const TextStyle(fontSize: 20),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-mail', hintText: 'ex. cabinet@exemple.fr'),
          ),
        ],
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
                subtitle: 'Votre nom et votre date de naissance apparaissent en haut du document pour le médecin.',
                showBack: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileForm(key: key, store: store, showDoctor: true),
                  const SizedBox(height: 28),
                  BigButton('Enregistrer',
                      icon: Icons.check_rounded,
                      kind: BigButtonKind.success,
                      onPressed: () async {
                        final f = key.currentState;
                        if (f != null && !f.emailOk) {
                          showMessage(context, 'L\'e-mail du médecin semble incomplet.');
                          return;
                        }
                        await f?.save();
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
