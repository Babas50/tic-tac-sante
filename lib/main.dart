import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'core/notifications.dart';
import 'core/store.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

final store = AppStore();
final homeKey = GlobalKey<HomeShellState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');
  try {
    await initNotifications(onResponse: _onNotificationResponse);
  } catch (e) {
    debugPrint('Notifications indisponibles : $e');
  }
  await store.load();
  runApp(RappelApp(store: store));
}

Future<void> _onNotificationResponse(NotificationResponse r) async {
  if (r.actionId != null) {
    await handleNotificationAction(r.actionId, r.payload);
  }
  await store.refresh();
  homeKey.currentState?.goToday();
}

class RappelApp extends StatefulWidget {
  final AppStore store;
  const RappelApp({super.key, required this.store});

  @override
  State<RappelApp> createState() => _RappelAppState();
}

class _RappelAppState extends State<RappelApp> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Met à jour les statuts (« à prendre », « oublié »...) régulièrement.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => widget.store.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.refresh(forceReschedule: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rappel Médicaments',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => widget.store.data.onboardingDone
            ? HomeShell(key: homeKey, store: widget.store)
            : OnboardingScreen(store: widget.store),
      ),
    );
  }
}
