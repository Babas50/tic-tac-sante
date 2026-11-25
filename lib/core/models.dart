// Modèles de données de l'application (stockés en JSON sur le téléphone).

/// Médicament de la bibliothèque.
class Medication {
  final String id;
  String name;
  String description;
  String notes; // ex. « maximum 3 par jour »
  int colorIndex;
  int iconIndex;

  Medication({
    required this.id,
    required this.name,
    this.description = '',
    this.notes = '',
    this.colorIndex = 0,
    this.iconIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'notes': notes,
        'colorIndex': colorIndex,
        'iconIndex': iconIndex,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        colorIndex: (j['colorIndex'] ?? 0) as int,
        iconIndex: (j['iconIndex'] ?? 0) as int,
      );
}

/// daily = rappel récurrent (voir [Reminder.repeat]), once = une seule fois.
enum ReminderType { daily, once }

/// Récurrence : tous les N jours, ou certains jours de la semaine.
enum Recurrence { interval, weekdays }

/// Rappel de prise : un médicament, une heure, une quantité.
class Reminder {
  final String id;
  String medId;
  ReminderType type;
  int hour;
  int minute;

  /// Pour un rappel ponctuel : jour au format AAAA-MM-JJ.
  String? date;
  double quantity;
  String unit;
  bool active;
  DateTime createdAt;

  /// Numéro unique servant à fabriquer les identifiants de notification.
  int nid;

  /// Récurrence (rappels récurrents uniquement).
  Recurrence repeat;

  /// Tous les [intervalDays] jours (1 = tous les jours, 2 = 1 jour sur 2...).
  int intervalDays;

  /// Premier jour du cycle (AAAA-MM-JJ) pour « 1 jour sur N ».
  String? startDate;

  /// Jours de la semaine (1 = lundi ... 7 = dimanche).
  List<int> weekdays;

  Reminder({
    required this.id,
    required this.medId,
    required this.type,
    required this.hour,
    required this.minute,
    this.date,
    required this.quantity,
    required this.unit,
    this.active = true,
    required this.createdAt,
    required this.nid,
    this.repeat = Recurrence.interval,
    this.intervalDays = 1,
    this.startDate,
    List<int>? weekdays,
  }) : weekdays = weekdays ?? [];

  Map<String, dynamic> toJson() => {
        'repeat': repeat.name,
        'intervalDays': intervalDays,
        'startDate': startDate,
        'weekdays': weekdays,
        'id': id,
        'medId': medId,
        'type': type.name,
        'hour': hour,
        'minute': minute,
        'date': date,
        'quantity': quantity,
        'unit': unit,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'nid': nid,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        medId: j['medId'] as String,
        type: j['type'] == 'once' ? ReminderType.once : ReminderType.daily,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        date: j['date'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        unit: (j['unit'] ?? 'comprimé') as String,
        active: (j['active'] ?? true) as bool,
        createdAt: DateTime.parse(j['createdAt'] as String),
        nid: j['nid'] as int,
        // Valeurs par défaut = comportement de la version 1 (tous les jours).
        repeat: j['repeat'] == 'weekdays' ? Recurrence.weekdays : Recurrence.interval,
        intervalDays: ((j['intervalDays'] ?? 1) as int).clamp(1, 365),
        startDate: j['startDate'] as String?,
        weekdays: ((j['weekdays'] ?? []) as List).map((e) => e as int).toList(),
      );
}

/// Préfixe des prises ponctuelles saisies hors rappel.
const manualPrefix = 'manual-';

enum HistoryStatus { pris, decale, oublie }

/// Ligne d'historique : prise, décalage ou oubli d'une occurrence de rappel.
class HistoryEntry {
  final String id;
  final String reminderId;
  final String medId;
  final String medName;
  final double quantity;
  final String unit;

  /// Jour de l'occurrence (AAAA-MM-JJ).
  final String date;
  final DateTime planned;

  /// Heure réelle de la prise ou du décalage.
  final DateTime? actual;
  final HistoryStatus status;
  final bool once;

  /// Pour un décalage : nouvelle heure de rappel.
  final DateTime? until;

  HistoryEntry({
    required this.id,
    required this.reminderId,
    required this.medId,
    required this.medName,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.planned,
    this.actual,
    required this.status,
    this.once = false,
    this.until,
  });

  String get key => occurrenceKey(reminderId, date);

  /// Prise ponctuelle saisie à la main, hors rappel programmé.
  bool get manual => reminderId.startsWith(manualPrefix);

  HistoryEntry copyWith({
    double? quantity,
    String? unit,
    String? date,
    DateTime? planned,
    DateTime? actual,
    HistoryStatus? status,
    String? medId,
    String? medName,
  }) =>
      HistoryEntry(
        id: id,
        reminderId: reminderId,
        medId: medId ?? this.medId,
        medName: medName ?? this.medName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        date: date ?? this.date,
        planned: planned ?? this.planned,
        actual: actual ?? this.actual,
        status: status ?? this.status,
        once: once,
        until: until,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reminderId': reminderId,
        'medId': medId,
        'medName': medName,
        'quantity': quantity,
        'unit': unit,
        'date': date,
        'planned': planned.toIso8601String(),
        'actual': actual?.toIso8601String(),
        'status': status.name,
        'once': once,
        'until': until?.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        reminderId: j['reminderId'] as String,
        medId: (j['medId'] ?? '') as String,
        medName: (j['medName'] ?? '') as String,
        quantity: ((j['quantity'] ?? 1) as num).toDouble(),
        unit: (j['unit'] ?? '') as String,
        date: j['date'] as String,
        planned: DateTime.parse(j['planned'] as String),
        actual: j['actual'] == null ? null : DateTime.parse(j['actual'] as String),
        status: HistoryStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => HistoryStatus.pris),
        once: (j['once'] ?? false) as bool,
        until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
      );
}

String occurrenceKey(String reminderId, String date) => '$reminderId|$date';

/// Profil affiché en en-tête du PDF pour le médecin, et coordonnées du
/// médecin pour lui envoyer ce PDF par e-mail.
class Profile {
  String name;
  DateTime? birthDate;
  String doctorName;
  String doctorEmail;
  Profile({this.name = '', this.birthDate, this.doctorName = '', this.doctorEmail = ''});

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': birthDate?.toIso8601String(),
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
      };

  factory Profile.fromJson(Map<String, dynamic>? j) => j == null
      ? Profile()
      : Profile(
          name: (j['name'] ?? '') as String,
          birthDate: j['birthDate'] == null
              ? null
              : DateTime.parse(j['birthDate'] as String),
          doctorName: (j['doctorName'] ?? '') as String,
          doctorEmail: (j['doctorEmail'] ?? '') as String,
        );
}

/// Toutes les données hors historique.
class AppData {
  List<Medication> meds;
  List<Reminder> reminders;
  Profile profile;
  bool onboardingDone;
  int nextNid;

  AppData({
    List<Medication>? meds,
    List<Reminder>? reminders,
    Profile? profile,
    this.onboardingDone = false,
    this.nextNid = 1,
  })  : meds = meds ?? [],
        reminders = reminders ?? [],
        profile = profile ?? Profile();

  Medication? med(String id) {
    for (final m in meds) {
      if (m.id == id) return m;
    }
    return null;
  }

  Reminder? reminder(String id) {
    for (final r in reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'meds': meds.map((m) => m.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'profile': profile.toJson(),
        'onboardingDone': onboardingDone,
        'nextNid': nextNid,
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        meds: ((j['meds'] ?? []) as List)
            .map((e) => Medication.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        reminders: ((j['reminders'] ?? []) as List)
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        profile: Profile.fromJson(j['profile'] == null
            ? null
            : Map<String, dynamic>.from(j['profile'])),
        onboardingDone: (j['onboardingDone'] ?? false) as bool,
        nextNid: (j['nextNid'] ?? 1) as int,
      );
}
