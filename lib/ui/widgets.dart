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
        Icon(icon, size: 26),
        const SizedBox(width: 10),
        Flexible(child: text),
      ],
    );
  }
}

enum BigButtonKind { primary, success, outline, danger, soft, text }

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
            side: BorderSide(color: color ?? brand, width: 2),
            foregroundColor: color ?? brand,
          ),
          child: child,
        );
      case BigButtonKind.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(foregroundColor: color ?? brand),
          child: child,
        );
      case BigButtonKind.success:
      case BigButtonKind.danger:
      case BigButtonKind.primary:
        final bg = color ??
            switch (kind) {
              BigButtonKind.success => brand,
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

/// Carte blanche arrondie, bordée d'un filet fin.
class SoftCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  const SoftCard(
      {super.key,
      required this.child,
      this.color,
      this.borderColor,
      this.borderWidth = 1,
      this.onTap,
      this.padding = const EdgeInsets.all(16),
      this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 5)});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: borderColor ?? lineColor, width: borderWidth),
    );
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
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
          Icon(icon, size: 72, color: brand),
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

/// Statut d'une prise : couleur, icône et libellé toujours ensemble (jamais
/// la couleur seule).
enum IntakeKind { taken, extra, snoozed, missed, due, upcoming }

({Color color, Color soft, IconData icon}) kindStyle(IntakeKind k) => switch (k) {
      IntakeKind.taken => (color: okGreen, soft: okSoft, icon: Icons.check_rounded),
      IntakeKind.extra => (color: extraInk, soft: extraSoft, icon: Icons.add_rounded),
      IntakeKind.snoozed => (color: warnOrange, soft: warnSoft, icon: Icons.schedule_rounded),
      IntakeKind.missed => (color: dangerRed, soft: dangerSoft, icon: Icons.close_rounded),
      IntakeKind.due => (color: warnOrange, soft: warnSoft, icon: Icons.notifications_active_rounded),
      IntakeKind.upcoming => (color: muted, soft: surfaceAlt, icon: Icons.schedule_rounded),
    };

/// Pastille « Pris à 08:03 », « Reporté à 13:10 »...
class StatusPill extends StatelessWidget {
  final IntakeKind kind;
  final String text;
  const StatusPill(this.kind, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final k = kindStyle(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: k.soft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(k.icon, size: 22, color: k.color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: k.color)),
          ),
        ],
      ),
    );
  }
}

/// Rond de statut (vert coché, « + », ambre, rouge...).
class StatusDot extends StatelessWidget {
  final IntakeKind kind;
  final double size;
  const StatusDot(this.kind, {super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final k = kindStyle(kind);
    final filled = kind == IntakeKind.taken;
    final extra = kind == IntakeKind.extra;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: filled ? okGreen : (extra ? Colors.white : k.soft),
          shape: BoxShape.circle,
          border: extra ? Border.all(color: extraLine, width: 1.5) : null),
      child: Icon(k.icon, size: size * 0.6, color: filled ? Colors.white : k.color),
    );
  }
}

/// Ligne compacte d'une prise : rond de statut, heure, médicament et
/// résultat. Aucun bouton : on la touche pour ouvrir le détail.
class CompactIntakeRow extends StatelessWidget {
  final IntakeKind kind;
  final String time;
  final String title;
  final String detail;
  final String? quantity;
  final VoidCallback onTap;
  const CompactIntakeRow(
      {super.key,
      required this.kind,
      required this.time,
      required this.title,
      required this.detail,
      this.quantity,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = kindStyle(kind);
    final extra = kind == IntakeKind.extra;
    // Police très grande : l'heure passe au-dessus du nom pour garder la place.
    final big = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final timeStyle = TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: extra ? extraInk : muted,
        fontFeatures: const [FontFeature.tabularFigures()]);
    return SoftCard(
      // Prise ponctuelle : fond jaune, contour doré et étiquette, pour la
      // distinguer des traitements réguliers sans dépendre de la couleur seule.
      color: extra ? extraSoft : (kind == IntakeKind.taken ? surfaceAlt : Colors.white),
      borderColor: extra ? extraLine : null,
      borderWidth: extra ? 1.5 : 1,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      child: Semantics(
        button: true,
        child: Row(
          children: [
            StatusDot(kind),
            const SizedBox(width: 12),
            if (!big) ...[Text(time, style: timeStyle), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (big) Text(time, style: timeStyle),
                  if (extra) const PonctuelTag(),
                  Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.25)),
                  Text.rich(TextSpan(children: [
                    if (quantity != null) TextSpan(text: '$quantity · '),
                    TextSpan(text: detail, style: TextStyle(color: k.color, fontWeight: FontWeight.w700)),
                  ]), style: const TextStyle(fontSize: 17, color: ink, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 30, color: extra ? extraInk : muted, semanticLabel: 'Détail'),
          ],
        ),
      ),
    );
  }
}

/// Étiquette « PONCTUELLE » d'une prise hors rappel.
class PonctuelTag extends StatelessWidget {
  const PonctuelTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: extraTag, borderRadius: BorderRadius.circular(20)),
        child: const Text('PONCTUELLE',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: extraInk, letterSpacing: 0.3)),
      );
}

/// Choix exclusif sur une ligne (ou empilé si la place manque).
class Segmented<T> extends StatelessWidget {
  final List<(T, String, IconData)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color? selectedColor;
  const Segmented(
      {super.key, required this.options, required this.value, required this.onChanged, this.selectedColor});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    Widget item((T, String, IconData) o) {
      final on = o.$1 == value;
      final c = selectedColor ?? brand;
      return Semantics(
        selected: on,
        button: true,
        child: Material(
          color: on ? c : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(o.$1),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? Icons.check_rounded : o.$3, size: 22, color: on ? Colors.white : ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(o.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: on ? Colors.white : ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final stacked = scale > 1.3 || c.maxWidth < 110.0 * options.length;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outlineColor, width: 1.5),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final o in options) item(o)],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(child: item(options[i])),
                    ],
                  ],
                ),
              ),
      );
    });
  }
}

/// Champ cliquable (date, heure) : libellé au-dessus, valeur dans un cadre.
class FieldButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const FieldButton(
      {super.key, required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: outlineColor, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 26, color: brand),
                  const SizedBox(width: 12),
                  Expanded(child: Text(value, style: const TextStyle(fontSize: 19))),
                  const Icon(Icons.edit_rounded, size: 22, color: muted, semanticLabel: 'Modifier'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unités : les plus courantes, puis « Autre... » qui déplie la liste complète.
class UnitPicker extends StatefulWidget {
  final String unit;
  final List<String> all;
  final ValueChanged<String> onChanged;
  const UnitPicker({super.key, required this.unit, required this.all, required this.onChanged});

  static const common = ['comprimé', 'gélule', 'sachet', 'goutte', 'ml'];

  @override
  State<UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<UnitPicker> {
  late bool expanded = !UnitPicker.common.contains(widget.unit);

  @override
  Widget build(BuildContext context) {
    final shown = expanded ? widget.all : UnitPicker.common.where(widget.all.contains).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final u in shown)
          ChoiceChip(
            label: Text(u),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            selected: widget.unit == u,
            onSelected: (_) => widget.onChanged(u),
          ),
        if (!expanded)
          ActionChip(
            label: const Text('Autre...'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            onPressed: () => setState(() => expanded = true),
          ),
      ],
    );
  }
}

/// Panneau du bas avec un titre libre et une liste de boutons.
Future<T?> showActionSheet<T>(BuildContext context, {required Widget header, required List<Widget> actions}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              actions[i],
            ],
          ],
        ),
      ),
    ),
  );
}
