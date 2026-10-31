# Foulée — tracker de course pour iPhone

App iOS native (SwiftUI, iOS 17+) pour enregistrer tes courses, à la manière de Strava, sans compte ni serveur : tout reste sur ton iPhone (et dans l'app Santé si tu le souhaites).

## Fonctionnalités

| Onglet | Ce qu'il fait |
|---|---|
| **Courir** | GPS en direct, y compris écran verrouillé · distance, chrono (pauses exclues), allure instantanée et moyenne, dernier km, dénivelé, cadence (podomètre) · carte avec ton tracé · coach vocal en français à chaque kilomètre · indicateur de qualité GPS |
| **Itinéraires** | Choisis une distance (1 à 30 km) et une difficulté (facile / modéré / difficile) : l'app calcule 4 boucles qui partent de ta position et y reviennent, sur chemins piétons (Apple Plans), mesure leur dénivelé (Open-Meteo) et les classe. Durée estimée selon ton allure habituelle. « Courir cet itinéraire » l'affiche sur la carte de course. |
| **Historique** | Toutes tes courses par mois, avec vignette du tracé. Détail : carte, stats, temps au kilomètre, profil d'altitude, meilleurs efforts, notes. |
| **Progression** | Objectif hebdomadaire, série de semaines, totaux semaine/mois/année avec comparaison à la période précédente, km par semaine, évolution de l'allure, records personnels (1 km, 5 km, 10 km, semi, marathon, plus longue sortie, plus gros D+). |
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
project.yml   configuration XcodeGen (Info.plist, autorisations, mode arrière-plan, HealthKit)
```

## Pistes pour la suite

- Live Activity / Dynamic Island et widget écran verrouillé pendant la course
- App Apple Watch (fréquence cardiaque en direct)
- Séances fractionnées guidées, plans d'entraînement
- Segments et suivi d'un itinéraire avec guidage vocal aux intersections
- Synchronisation iCloud (SwiftData + CloudKit)
