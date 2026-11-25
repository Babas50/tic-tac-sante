# Tic-Tac Santé

Application Android simple et sobre qui rappelle l'heure des médicaments. Elle fonctionne **sans internet, sans compte et sans serveur** : tout reste sur le téléphone.

- Rappels **tous les jours**, **1 jour sur 2**, **1 jour sur 3**, **tous les N jours**, **certains jours de la semaine** ou **une seule fois**, à une ou plusieurs heures, avec la quantité de votre choix (½ comprimé, 2 gouttes...).
- Notification avec trois boutons : **Pris**, **Dans 30 min**, **Dans 1 h**. Dans l'application, on peut aussi reporter de 15 min ou 2 h.
- **Relance automatique** 15 minutes plus tard si personne n'a répondu.
- Alarmes à l'heure exacte, même téléphone en veille, et **reprogrammées après un redémarrage**.
- **Bibliothèque** de médicaments (nom, descriptif, consignes comme le maximum par jour).
- **Écran Aujourd'hui** : un « pilulier » montre d'un coup d'œil les prises de la journée (une case par prise). Une prise validée devient une ligne compacte, sans bouton : impossible de l'annuler par erreur.
- **J'ai pris un médicament** (bouton en bas de l'écran Aujourd'hui) : une prise en plus, hors rappel (par exemple contre une douleur). L'appli rappelle l'heure de la dernière prise du jour et la consigne du médicament (« espacer de 6 heures »...).
- **Corriger en deux gestes** : touchez une prise (sur Aujourd'hui ou dans l'Historique) pour ouvrir son détail, puis « Corriger l'heure ou la quantité », « Je ne l'ai pas pris » ou, pour un oubli, « En fait, je l'ai pris ».
- **Historique** : pris, prise en plus, reporté, oublié, avec heure prévue et heure réelle, taux de prises respectées sur 7 jours, 30 jours ou depuis le début.
- **Export pour le médecin** : « Créer le PDF » enregistre un document d'une à deux pages (nom, date de naissance, traitement en cours, taux de prises respectées) dans **Téléchargements**. Ensuite : **envoyer au médecin par e-mail** (PDF déjà joint), partager autrement, ouvrir ou imprimer. Les documents déjà créés restent listés.
- **Sauvegarde / restauration** de toutes les données dans un fichier.
- Pensée pour les seniors : gros boutons (56 px), gros textes qui suivent la taille de police d'Android sans jamais être coupés, fort contraste, police **Atkinson Hyperlegible** (conçue pour les personnes malvoyantes, intégrée à l'appli), une seule couleur principale et un code couleur constant pour les statuts : vert = pris, ambre = reporté, rouge = oublié, toujours accompagné d'une icône et d'un texte.

## Installer l'application sur le téléphone

1. Sur le téléphone Android, ouvrez cette page :
   **https://github.com/Babas50/tic-tac-sante/releases/latest**
2. Dans la partie **Assets**, touchez **tic-tac-sante.apk**. Le téléchargement démarre.
3. Ouvrez le fichier téléchargé (notification « Téléchargement terminé » ou application **Fichiers** > **Téléchargements**).
4. Android affiche « Pour votre sécurité, l'installation d'applications inconnues est bloquée » :
   - touchez **Paramètres** ;
   - activez **Autoriser cette source** (pour Chrome ou pour l'application Fichiers) ;
   - revenez en arrière et touchez **Installer**.
5. Si Google Play Protect affiche un avertissement (« application non vérifiée »), touchez **Plus de détails** puis **Installer quand même**. C'est normal : l'application ne passe pas par le Play Store.
6. Ouvrez **Tic-Tac Santé** et suivez les 3 étapes du premier lancement.

> Après l'installation, vous pouvez désactiver « Autoriser cette source » dans les paramètres : cela ne supprime pas l'application.

### Le premier lancement

L'application demande trois autorisations. Touchez chaque bouton **Autoriser** et acceptez :

1. **Notifications** : pour afficher les rappels.
2. **Alarmes exactes** : pour sonner à la minute près (souvent déjà accordée).
3. **Batterie / ne pas optimiser** : pour qu'Android ne bloque pas les rappels.

Sur certains téléphones (Xiaomi, Huawei, Oppo, OnePlus, certains Samsung), il faut aussi aller dans **Paramètres > Applications > Tic-Tac Santé > Batterie** et choisir **Sans restriction**, et activer le **démarrage automatique** s'il existe. Le site https://dontkillmyapp.com donne la marche à suivre par marque.

Pour vérifier : **Réglages > Tester une notification**, puis verrouillez le téléphone et attendez une minute.

### Envoyer le PDF à votre médecin par e-mail

Dans **Réglages > Mon profil**, renseignez le nom et l'e-mail de votre médecin (facultatif). Après **Export pour le médecin > Créer le PDF**, le bouton **Envoyer au Dr ...** ouvre votre messagerie avec le destinataire, l'objet et le PDF déjà remplis : il ne reste qu'à appuyer sur Envoyer. Sans e-mail enregistré, la messagerie s'ouvre avec le PDF joint et vous choisissez le destinataire.

Sur Android 9 ou plus ancien, le PDF reste dans l'application (pas de copie dans Téléchargements) et l'envoi passe par le menu de partage.

### Mettre à jour

Téléchargez le nouvel APK depuis la même page et installez-le par-dessus : les données sont conservées. Par précaution, faites d'abord **Réglages > Sauvegarder mes données**.

## Changer de téléphone

1. Sur l'ancien téléphone : **Réglages > Sauvegarder mes données**, puis envoyez le fichier par e-mail ou enregistrez-le sur Drive.
2. Sur le nouveau : installez l'application, puis **Réglages > Restaurer une sauvegarde** et choisissez le fichier.

## Pour les développeurs

Application Flutter (Android uniquement).

```bash
flutter pub get
flutter test                    # logique, PDF, et aucun texte coupé jusqu'à une police x2
flutter test test/screens --run-skipped --update-goldens   # captures dans build/screens/
flutter build apk --release
```

À chaque envoi sur la branche `main`, GitHub Actions (`.github/workflows/build-apk.yml`) lance l'analyse et les tests, compile l'APK et publie une Release avec le fichier `tic-tac-sante.apk`.

Organisation du code :

- `lib/core/` : modèles, logique (occurrences, oublis, statistiques), stockage local, notifications, PDF, documents exportés (`documents.dart`).
- `lib/ui/` : écrans (Aujourd'hui, Médicaments, Historique, Réglages, Nouveau rappel, Export...). `theme.dart` regroupe les couleurs et la police, `widgets.dart` les composants communs (lignes de prise, pastilles de statut, choix segmentés), `intake_sheet.dart` le panneau de détail d'une prise.
- `android/.../MainActivity.kt` : canal `fr.babas50.tictac/documents` (copie du PDF dans Téléchargements via MediaStore, ouverture, envoi par e-mail avec pièce jointe).
- `assets/fonts/` : police Atkinson Hyperlegible (Braille Institute, licence SIL OFL 1.1, voir `OFL.txt`).
- `test/` : tests unitaires et tests d'affichage en grande police.

Fonctionnement des rappels : chaque prise est programmée comme une alarme exacte (`exactAllowWhileIdle`) avec sa relance, sur une fenêtre glissante de 3 à 14 jours qui est prolongée à chaque ouverture de l'application et à chaque bouton touché dans une notification. Le récepteur `BOOT_COMPLETED` reprogramme les alarmes après un redémarrage.

**Signature** : la clé de signature n'est pas dans le dépôt. Elle est fournie au workflow par quatre secrets GitHub Actions (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, dans *Settings > Secrets and variables > Actions*). Gardez une copie privée du fichier de clé : sans elle, les mises à jour ne pourront plus s'installer par-dessus l'application. Une compilation locale sans ces variables utilise la clé de debug.
