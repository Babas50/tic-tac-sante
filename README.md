# Tic-Tac Santé

Application Android simple et colorée qui rappelle l'heure des médicaments. Elle fonctionne **sans internet, sans compte et sans serveur** : tout reste sur le téléphone.

- Rappels **tous les jours** ou **une seule fois**, à une ou plusieurs heures, avec la quantité de votre choix (½ comprimé, 2 gouttes...).
- Notification avec trois boutons : **Pris**, **Dans 30 min**, **Dans 1 h**. Dans l'application, on peut aussi reporter de 15 min ou 2 h.
- **Relance automatique** 15 minutes plus tard si personne n'a répondu.
- Alarmes à l'heure exacte, même téléphone en veille, et **reprogrammées après un redémarrage**.
- **Bibliothèque** de médicaments (nom, descriptif, consignes comme le maximum par jour).
- **Historique** : pris, reporté, oublié, ponctuel, avec heure prévue et heure réelle.
- **Export pour le médecin** : un PDF d'une à deux pages (nom, date de naissance, traitement en cours, taux de prises respectées) à envoyer par e-mail, enregistrer ou imprimer.
- **Sauvegarde / restauration** de toutes les données dans un fichier.
- Pensée pour les seniors : gros boutons, gros textes qui suivent la taille de police d'Android sans jamais être coupés, fort contraste, couleurs par moment de la journée.

## Installer l'application sur le téléphone

1. Sur le téléphone Android, ouvrez cette page :
   **https://github.com/Babas50/Tic-Tac-Sant-/releases/latest**
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
flutter build apk --release
```

À chaque envoi sur la branche `main`, GitHub Actions (`.github/workflows/build-apk.yml`) lance l'analyse et les tests, compile l'APK et publie une Release avec le fichier `tic-tac-sante.apk`.

Organisation du code :

- `lib/core/` : modèles, logique (occurrences, oublis, statistiques), stockage local, notifications, PDF.
- `lib/ui/` : écrans (Aujourd'hui, Médicaments, Historique, Réglages, Nouveau rappel, Export...).
- `test/` : tests unitaires et tests d'affichage en grande police.

Fonctionnement des rappels : chaque prise est programmée comme une alarme exacte (`exactAllowWhileIdle`) avec sa relance, sur une fenêtre glissante de 3 à 14 jours qui est prolongée à chaque ouverture de l'application et à chaque bouton touché dans une notification. Le récepteur `BOOT_COMPLETED` reprogramme les alarmes après un redémarrage.

**Signature** : la clé `android/app/signing/release.jks` est volontairement dans le dépôt pour que chaque APK compilé puisse s'installer par-dessus le précédent. Pour plus de sécurité, vous pouvez la remplacer par des secrets GitHub (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) ; attention, changer de clé oblige à désinstaller l'ancienne version (faites une sauvegarde avant).
