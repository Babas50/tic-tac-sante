// Notifications locales : programmation des alarmes exactes, boutons
// « Pris / Dans 30 min / Dans 1 h », relances. Aucune connexion internet.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'logic.dart';
import 'models.dart';
import 'storage.dart';

final FlutterLocalNotificationsPlugin notifPlugin =
    FlutterLocalNotificationsPlugin();

const channelId = 'rappels_prises_v1';
const channelName = 'Rappels de prise';
const _icon = 'ic_notification';

const actionTaken = 'pris';
const actionSnooze30 = 'snooze30';
const actionSnooze60 = 'snooze60';

bool _tzReady = false;

Future<void> initTimezone() async {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));
  }
  _tzReady = true;
}

AndroidFlutterLocalNotificationsPlugin? get androidNotif =>
    notifPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

Future<void> initNotifications(
    {DidReceiveNotificationResponseCallback? onResponse}) async {
  await initTimezone();
  await notifPlugin.initialize(
    settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon)),
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
  );
  await androidNotif?.createNotificationChannel(const AndroidNotificationChannel(
    channelId,
    channelName,
    description: 'Rappels pour prendre vos médicaments',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  ));
}

NotificationDetails _details(String body, {bool actions = true}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Rappels pour prendre vos médicaments',
        icon: _icon,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        color: const Color(0xFF6A3DE8),
        styleInformation: BigTextStyleInformation(body),
        actions: actions
            ? const [
                AndroidNotificationAction(actionTaken, '✅ Pris',
                    cancelNotification: true),
                AndroidNotificationAction(actionSnooze30, 'Dans 30 min',
                    cancelNotification: true),
                AndroidNotificationAction(actionSnooze60, 'Dans 1 h',
                    cancelNotification: true),
              ]
            : null,
      ),
    );

/// Reprogramme toutes les alarmes à partir des données.
Future<void> scheduleAll(AppData data, List<HistoryEntry> history) async {
  await initTimezone();
  final android = androidNotif;
  if (android == null) return;
  var exact = true;
  try {
    exact = await android.canScheduleExactNotifications() ?? true;
  } catch (_) {}
  final mode = exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;
  await notifPlugin.cancelAllPendingNotifications();
  for (final p in plannedNotifications(data, history, DateTime.now())) {
    try {
      await notifPlugin.zonedSchedule(
        id: p.id,
        scheduledDate: tz.TZDateTime.from(p.time, tz.local),
        notificationDetails: _details(p.body, actions: p.withActions),
        androidScheduleMode: mode,
        title: p.title,
        body: p.body,
        payload: p.payload,
      );
    } catch (e) {
      debugPrint('Programmation impossible ${p.id} : $e');
    }
  }
}

Future<void> cancelOccurrence(int nid, String date) async {
  for (final id in notifIdsFor(nid, date)) {
    try {
      await notifPlugin.cancel(id: id);
    } catch (_) {}
  }
}

Future<void> showTestNotification() async {
  await notifPlugin.show(
    id: testNotificationId,
    title: 'Test : tout fonctionne',
    body: 'Les rappels s\'afficheront comme ceci, avec leurs boutons.',
    notificationDetails: _details(
        'Les rappels s\'afficheront comme ceci, avec leurs boutons.',
        actions: false),
  );
}

/// Programme une notification de test dans [minutes] minutes.
Future<void> scheduleTestNotification(int minutes) async {
  await initTimezone();
  final exact = await androidNotif?.canScheduleExactNotifications() ?? true;
  const body = 'Rappel de test programmé : les alarmes fonctionnent.';
  await notifPlugin.zonedSchedule(
    id: testNotificationId,
    scheduledDate:
        tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
    notificationDetails: _details(body, actions: false),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    title: 'Test de rappel',
    body: body,
  );
}

/// Traite un bouton de notification. Écrit dans le journal (lu ensuite par
/// l'application) puis reprogramme les alarmes. Fonctionne aussi quand
/// l'application est fermée.
Future<bool> handleNotificationAction(String? actionId, String? payload) async {
  if (actionId == null || payload == null || payload.isEmpty) return false;
  Map<String, dynamic> p;
  try {
    p = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return false;
  }
  final rid = p['rid'] as String?;
  final date = p['date'] as String?;
  if (rid == null || date == null) return false;

  final storage = Storage();
  final data = await storage.loadData();
  final history = await storage.loadHistory();
  history.addAll((await storage.readJournal()).values);
  final r = data.reminder(rid);
  if (r == null) return false;
  final med = data.med(r.medId);
  final now = DateTime.now();

  HistoryEntry entry(HistoryStatus s, {DateTime? until}) => HistoryEntry(
        id: newId(),
        reminderId: r.id,
        medId: r.medId,
        medName: med?.name ?? '',
        quantity: r.quantity,
        unit: r.unit,
        date: date,
        planned: plannedFor(r, date),
        actual: now,
        status: s,
        once: r.type == ReminderType.once,
        until: until,
      );

  HistoryEntry? e;
  switch (actionId) {
    case actionTaken:
      e = entry(HistoryStatus.pris);
    case actionSnooze30:
      e = entry(HistoryStatus.decale, until: now.add(const Duration(minutes: 30)));
    case actionSnooze60:
      e = entry(HistoryStatus.decale, until: now.add(const Duration(hours: 1)));
  }
  if (e == null) return false;
  await storage.appendJournal(e);
  history.add(e);
  await cancelOccurrence(r.nid, date);
  await scheduleAll(data, history);
  return true;
}

@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await handleNotificationAction(response.actionId, response.payload);
}
