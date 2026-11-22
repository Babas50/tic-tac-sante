import 'package:rappel_medicaments/core/models.dart';

/// Données d'exemple utilisées par les tests.
AppData sampleData(DateTime now) {
  final created = now.subtract(const Duration(days: 40));
  return AppData(
    onboardingDone: true,
    nextNid: 10,
    profile: Profile(name: 'Jean-Baptiste Delacroix-Montaigne', birthDate: DateTime(1948, 3, 12)),
    meds: [
      Medication(
          id: 'm1',
          name: 'Doliprane 1000 mg avec un nom très très long pour tester le retour à la ligne',
          description: 'Contre la douleur, comprimé blanc sécable',
          notes: '3 maximum par jour, espacer de 6 heures',
          colorIndex: 0),
      Medication(id: 'm2', name: 'Kardégic 75', notes: 'Pendant le repas', colorIndex: 5, iconIndex: 2),
      Medication(id: 'm3', name: 'Collyre', colorIndex: 3, iconIndex: 2),
    ],
    reminders: [
      Reminder(id: 'r1', medId: 'm1', type: ReminderType.daily, hour: 8, minute: 0,
          quantity: 1.5, unit: 'comprimé', createdAt: created, nid: 1),
      Reminder(id: 'r2', medId: 'm2', type: ReminderType.daily, hour: 12, minute: 30,
          quantity: 1, unit: 'gélule', createdAt: created, nid: 2),
      Reminder(id: 'r3', medId: 'm1', type: ReminderType.daily, hour: 20, minute: 0,
          quantity: 2, unit: 'comprimé', createdAt: created, nid: 3),
      Reminder(id: 'r4', medId: 'm3', type: ReminderType.daily, hour: 22, minute: 30,
          quantity: 2, unit: 'goutte', createdAt: created, nid: 4),
      Reminder(id: 'r5', medId: 'm2', type: ReminderType.once, hour: 15, minute: 0,
          date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          quantity: 1, unit: 'gélule', createdAt: created, nid: 5),
    ],
  );
}
