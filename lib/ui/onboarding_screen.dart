import 'package:material_ui/material_ui.dart';

import '../core/store.dart';
import 'permissions_panel.dart';
import 'profile_form.dart';
import 'theme.dart';
import 'widgets.dart';

/// Écran d'aide au premier lancement : bienvenue, profil, autorisations.
class OnboardingScreen extends StatefulWidget {
  final AppStore store;
  const OnboardingScreen({super.key, required this.store});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  final profileKey = GlobalKey<ProfileFormState>();

  Future<void> _next() async {
    if (step == 1) await profileKey.currentState?.save();
    if (step < 2) {
      setState(() => step++);
    } else {
      await widget.store.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final Widget content = switch (step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: brand,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.medication_rounded, size: 90, color: Colors.white),
                  SizedBox(height: 8),
                  Text('Bienvenue dans Tic-Tac Santé !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Cette application vous rappelle de prendre vos médicaments, à l\'heure.',
                style: t.titleMedium),
            const SizedBox(height: 14),
            for (final (icon, text) in const [
              (Icons.alarm_rounded, 'Une alarme sonne à l\'heure choisie, même téléphone en veille.'),
              (Icons.touch_app_rounded, 'Un seul bouton pour dire « J\'ai pris ».'),
              (Icons.snooze_rounded, 'Pas le moment ? Reportez de 15 min à 2 h.'),
              (Icons.description_rounded, 'Un résumé à envoyer à votre médecin.'),
              (Icons.lock_rounded, 'Tout reste sur votre téléphone, sans internet.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 32, color: brand),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: t.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Qui prend les médicaments ?', style: t.titleLarge),
            const SizedBox(height: 6),
            Text('Le nom et la date de naissance figureront sur le document pour le médecin. '
                'Vous pourrez les modifier plus tard.', style: t.bodyLarge),
            ProfileForm(key: profileKey, store: widget.store),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trois réglages pour des rappels fiables', style: t.titleLarge),
            const SizedBox(height: 6),
            Text('Appuyez sur chaque bouton « Autoriser » et acceptez. '
                'C\'est à faire une seule fois.', style: t.bodyLarge),
            const SizedBox(height: 8),
          ],
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Étape ${step + 1} sur 3',
                  style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: brand)),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: content),
            if (step == 2) const PermissionsPanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BigButton(step == 2 ? 'C\'est parti !' : 'Suivant',
                      icon: step == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                      kind: BigButtonKind.success,
                      onPressed: _next),
                  if (step > 0) ...[
                    const SizedBox(height: 10),
                    BigButton('Retour',
                        icon: Icons.arrow_back_rounded,
                        kind: BigButtonKind.outline,
                        onPressed: () => setState(() => step--)),
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
