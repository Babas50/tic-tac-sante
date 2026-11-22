import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/notifications.dart';
import 'theme.dart';
import 'widgets.dart';

/// Les trois réglages Android indispensables pour des rappels fiables.
class PermissionsPanel extends StatefulWidget {
  const PermissionsPanel({super.key});

  @override
  State<PermissionsPanel> createState() => _PermissionsPanelState();
}

class _PermissionsPanelState extends State<PermissionsPanel> with WidgetsBindingObserver {
  bool? notifications;
  bool? exactAlarms;
  bool? battery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    bool? n, e, b;
    try {
      n = await androidNotif?.areNotificationsEnabled();
      e = await androidNotif?.canScheduleExactNotifications();
      b = await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {}
    if (mounted) {
      setState(() {
        notifications = n;
        exactAlarms = e;
        battery = b;
      });
    }
  }

  Future<void> _run(Future<Object?> Function() f) async {
    try {
      await f();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermCard(
          icon: Icons.notifications_active_rounded,
          title: '1. Afficher les notifications',
          text: 'Pour voir les rappels et leurs boutons « Pris », « Dans 30 min », « Dans 1 h ».',
          granted: notifications,
          onTap: () => _run(() async => androidNotif?.requestNotificationsPermission()),
        ),
        _PermCard(
          icon: Icons.alarm_on_rounded,
          title: '2. Alarmes à l\'heure exacte',
          text: 'Pour que le rappel sonne à la minute près, même téléphone en veille.',
          granted: exactAlarms,
          onTap: () => _run(() async => androidNotif?.requestExactAlarmsPermission()),
        ),
        _PermCard(
          icon: Icons.battery_charging_full_rounded,
          title: '3. Ne pas endormir l\'application',
          text: 'Pour qu\'Android ne bloque pas les rappels afin d\'économiser la batterie. '
              'Répondez « Autoriser » dans la fenêtre qui s\'ouvre.',
          granted: battery,
          onTap: () => _run(() => Permission.ignoreBatteryOptimizations.request()),
        ),
        SoftCard(
          color: const Color(0xFFFFF1C2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 32, color: Color(0xFF8A4B00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sur certains téléphones (Xiaomi, Huawei, Oppo, Samsung...), il faut aussi '
                      'autoriser le « démarrage automatique » ou mettre la batterie sur « Sans restriction » '
                      'dans les réglages de l\'application.',
                      style: t.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BigButton('Ouvrir les réglages de l\'application',
                  icon: Icons.open_in_new_rounded,
                  kind: BigButtonKind.outline,
                  onPressed: () => openAppSettings()),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool? granted;
  final VoidCallback onTap;
  const _PermCard(
      {required this.icon, required this.title, required this.text, required this.granted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ok = granted == true;
    return SoftCard(
      color: ok ? const Color(0xFFE6F4EA) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: ok ? okGreen : brand),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: t.bodyMedium),
          const SizedBox(height: 10),
          if (ok)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: okGreen, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('C\'est fait',
                      style: t.titleMedium!.copyWith(color: okGreen)),
                ),
              ],
            )
          else
            BigButton('Autoriser', icon: Icons.touch_app_rounded, onPressed: onTap),
        ],
      ),
    );
  }
}
