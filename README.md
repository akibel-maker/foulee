# Foulée — tracker de course pour iPhone

App iOS native (SwiftUI, iOS 17+) pour enregistrer tes courses, à la manière de Strava, sans compte ni serveur : tout reste sur ton iPhone (et dans l'app Santé si tu le souhaites).

## Fonctionnalités

| Onglet | Ce qu'il fait |
|---|---|
| **Courir** | GPS en direct, y compris écran verrouillé · distance, chrono (pauses exclues), allure instantanée et moyenne, dernier km, dénivelé, cadence (podomètre) · carte avec ton tracé · coach vocal en français à chaque kilomètre · indicateur de qualité GPS |
| **Itinéraires** (bouton 🗺 dans Courir) | Choisis une distance (1 à 30 km) et une difficulté (facile / modéré / difficile) : l'app calcule 4 boucles qui partent de ta position et y reviennent, sur chemins piétons (Apple Plans), mesure leur dénivelé (Open-Meteo) et les classe. Durée estimée selon ton allure habituelle. « Courir cet itinéraire » l'affiche sur la carte de course. |
| **Historique** | Toutes tes courses par mois, avec vignette du tracé. Détail : carte, stats, temps au kilomètre, profil d'altitude, meilleurs efforts, notes. |
| **Progression** | **Objectifs personnalisés** (distance, sorties, temps, dénivelé, sortie longue, sommeil ; par semaine / mois / an ou jusqu'à une date) avec anneau de progression, reste à faire par jour et série de périodes réussies · **calendrier d'activité** sur 13 semaines · jours préférés, équilibre semaine/week-end, durée moyenne, fréquence · totaux semaine/mois/année avec comparaison à la période précédente, km par semaine, évolution de l'allure, records personnels (1 km, 5 km, 10 km, semi, marathon, plus longue sortie, plus gros D+). |
| **Étirements** | Les 12 routines du guide (Réveil, Posture, Nuque d'écran, Au bureau, Cou, Sommeil, Ischio-jambiers, Hanches, Épaules, Expert…) et ses ~65 mouvements expliqués · suggestion selon le moment de la journée (et après une course) · parcours par zone · **lecteur guidé** (minuteur, « change de côté », guide vocal, vibrations, écran toujours allumé) · durée courte/normale/longue · précaution cervicale et postures avancées désactivables · **routines personnelles** et **routine composée** à la demande · favoris · tableau de bord (séries, jours complétés, calendrier, historique) · séances enregistrées dans Santé (Souplesse) · lien avec les habitudes (minutes d'étirements automatiques). |
| **Quotidien › Habitudes** | Suivi d'habitudes indépendant de la course : habitudes Oui/Non ou à quantité (verres d'eau, minutes de lecture…), **pas comptés automatiquement depuis Santé**, fréquence (tous les jours, certains jours, X fois par semaine), rappels par notification, séries 🔥, taux de réussite, calendrier de l'historique, saisie des jours précédents, archivage. |
| **Quotidien › Sommeil** | Nuits lues dans Santé (Apple Watch ou autre app) : durée, heures de coucher/réveil, phases (profond, léger, paradoxal), graphique 7/14/30 nuits, moyennes, régularité du coucher, objectif de sommeil, **effet du sommeil sur ton allure de course**. |
| **Apple Watch** | App autonome au poignet : course extérieure (GPS) ou tapis · chrono, distance, allure, **fréquence cardiaque en direct**, calories · vibration à chaque km · pause, verrou eau, contrôle de la musique · enregistrement dans Santé · **la course arrive automatiquement dans l'historique de l'iPhone** (même si l'iPhone était resté à la maison : elle est envoyée dès qu'il est à portée). |
| **Réglages** | Objectif, poids (calories), coach vocal, enregistrement dans Santé, **import de tes anciennes courses depuis Santé** (Apple Watch, autres apps). |

Données de l'iPhone utilisées : GPS et altitude (CoreLocation), podomètre (CoreMotion), Santé (HealthKit : fréquence cardiaque si Apple Watch, poids, enregistrement et import des entraînements).

## Installer l'app sur ton iPhone

Il faut un **Mac avec Xcode 16 ou plus récent** (gratuit sur le Mac App Store).

1. Installe XcodeGen (génère le projet Xcode) : `brew install xcodegen`
   (pas Homebrew ? → https://brew.sh)
2. Dans le dossier du projet : `xcodegen`
   → crée `RunTracker.xcodeproj`. Ouvre-le.
3. Dans Xcode : cible **RunTracker** › **Signing & Capabilities** › **Team** : choisis ton identifiant Apple
   (ajoute-le si besoin via Xcode › Settings › Accounts).
   Si le Bundle Identifier est refusé, remplace `com.akibel.runtracker` par quelque chose d'unique.
4. Branche ton iPhone, sélectionne-le en haut de Xcode, puis ▶︎ (Cmd + R).
5. Sur l'iPhone, la première fois : Réglages › Confidentialité et sécurité › **Mode développeur** (à activer), puis
   Réglages › Général › VPN et gestion de l'appareil › fais confiance à ton compte développeur.
6. Au lancement, accepte la localisation (**position exacte**), les mouvements et Santé.

### Installer l'app Apple Watch

L'app Watch est intégrée au projet (cible **FouleeWatch**) et s'installe avec l'app iPhone.

1. Après `git pull`, relance `xcodegen` (le projet a changé), puis rouvre `RunTracker.xcodeproj`.
2. Dans **Signing & Capabilities**, choisis ton équipe pour **les deux cibles** : `RunTracker` et `FouleeWatch`.
   (Pour ne plus avoir à le refaire : renseigne `DEVELOPMENT_TEAM` dans `project.yml`.)
3. Active le **Mode développeur sur la Watch** : Réglages de la Watch › Confidentialité et sécurité › Mode développeur
   (l'option apparaît après une première tentative d'installation depuis Xcode, comme sur l'iPhone).
4. En haut de Xcode, choisis le schéma **FouleeWatch** et ta Watch comme destination, puis ▶︎.
   La Watch doit être déverrouillée, à côté de l'iPhone (lui-même connecté au Mac). La première installation peut être longue.
5. Sur la Watch, ouvre Foulée et accepte Santé et la localisation.

> Si tu as changé l'identifiant de l'app (Bundle Identifier) dans Xcode, mets la même valeur dans `APP_BUNDLE_ID` dans `project.yml` avant de relancer `xcodegen` : l'app Watch doit avoir l'identifiant de l'app iPhone suivi de `.watchkitapp`.

> **Compte Apple gratuit ou payant ?** Avec un identifiant Apple gratuit, l'app fonctionne mais doit être réinstallée depuis Xcode tous les 7 jours. Avec le programme développeur Apple (99 €/an), elle reste 1 an et tu peux la distribuer via TestFlight.
> Si Xcode refuse la capacité HealthKit avec un compte gratuit, supprime-la dans Signing & Capabilities : tout fonctionne sauf la partie Santé.

**Astuce GPS :** pour garder le suivi écran verrouillé, laisse l'autorisation de localisation sur « Lorsque l'app est active » (la flèche bleue en haut de l'écran indique que l'enregistrement continue).

## Structure

```
RunTracker/
  App/        point d'entrée, état partagé
  Models/     Run (SwiftData), calculs (splits, records, dénivelé)
  Services/   RunTracker (GPS + podomètre), VoiceCoach, HealthKit, suggestions d'itinéraires, altimétrie
  Views/      Courir, Itinéraires, Historique, Détail, Progression, Réglages
FouleeWatch/  app Apple Watch (séance HealthKit, GPS, écrans, envoi vers l'iPhone)
Shared/       code commun iPhone + Watch (points GPS, format d'échange, mise en forme)
project.yml   configuration XcodeGen (Info.plist, autorisations, mode arrière-plan, HealthKit)
```

## Pistes pour la suite

- Live Activity / Dynamic Island et widget écran verrouillé pendant la course
- Suivi en direct de la course Watch sur l'iPhone (mirroring de séance)
- Complication / widget Watch
- Séances fractionnées guidées, plans d'entraînement
- Segments et suivi d'un itinéraire avec guidage vocal aux intersections
- Synchronisation iCloud (SwiftData + CloudKit)
