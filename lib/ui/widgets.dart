// Composants réutilisables pensés pour une lecture facile : aucun texte
// tronqué, retour à la ligne partout, tailles qui suivent la police Android.

import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import 'theme.dart';

/// En-tête d'écran (remplace l'AppBar dont le titre peut être coupé).
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  const ScreenHeader(this.title, {super.key, this.subtitle, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 4 : 20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            IconButton(
              iconSize: 32,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              tooltip: 'Retour',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: showBack ? 10 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: t.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenu d'un bouton : icône + texte qui revient à la ligne.
class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _ButtonContent(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center, softWrap: true);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 10),
        Flexible(child: text),
      ],
    );
  }
}

enum BigButtonKind { primary, success, outline, danger, soft }

class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final BigButtonKind kind;
  final Color? color;
  const BigButton(this.label,
      {super.key, this.icon, this.onPressed, this.kind = BigButtonKind.primary, this.color});

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(label, icon);
    switch (kind) {
      case BigButtonKind.outline:
        return OutlinedButton(onPressed: onPressed, child: child);
      case BigButtonKind.soft:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: color ?? ink, width: 2),
            foregroundColor: color ?? ink,
          ),
          child: child,
        );
      case BigButtonKind.success:
      case BigButtonKind.danger:
      case BigButtonKind.primary:
        final bg = color ??
            switch (kind) {
              BigButtonKind.success => okGreen,
              BigButtonKind.danger => dangerRed,
              _ => brand,
            };
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: bg, foregroundColor: Colors.white),
          child: child,
        );
    }
  }
}

/// Deux boutons côte à côte, ou l'un sous l'autre si la police est grande
/// ou l'écran étroit.
class ButtonPair extends StatelessWidget {
  final Widget first;
  final Widget second;
  const ButtonPair(this.first, this.second, {super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final stacked = scale > 1.25 || c.maxWidth < 330;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        ),
      );
    });
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final String? help;
  const FieldLabel(this.text, {super.key, this.help});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.titleMedium),
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(help!, style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

class MedAvatar extends StatelessWidget {
  final Medication? med;
  final double size;
  const MedAvatar(this.med, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = medColors[(med?.colorIndex ?? 0) % medColors.length];
    final icon = medIcons[(med?.iconIndex ?? 0) % medIcons.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: size * 0.58),
    );
  }
}

/// Carte blanche arrondie.
class SoftCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const SoftCard(
      {super.key,
      required this.child,
      this.color,
      this.onTap,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 80, color: brand),
          const SizedBox(height: 12),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text, style: t.bodyLarge, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title,
    required String text,
    required String confirm,
    bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text, style: Theme.of(ctx).textTheme.bodyLarge)),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        BigButton('Annuler', kind: BigButtonKind.outline, onPressed: () => Navigator.pop(ctx, false)),
        BigButton(confirm,
            kind: danger ? BigButtonKind.danger : BigButtonKind.primary,
            onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return r ?? false;
}

/// Petite étiquette colorée (ex. « Ponctuel »).
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
