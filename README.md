# Pulse

Pulse is a social navigation prototype merging location discovery and Pulse-style check-ins.

## MapLibre & Tile Usage
- Map rendering uses [MapLibre GL](https://maplibre.org/); in dev we point to the demo style (`https://demotiles.maplibre.org/style.json`).
- Demo tiles are public but rate limited; for larger tests switch to a personal tile source (MapTiler, Stadia Maps, etc.) and update `styleString`.
- When testing on iOS, run `cd ios && pod install --repo-update` to pull MapLibre pods from `https://github.com/m0nac0/flutter-maplibre-podspecs.git`.
- Zoom controls and static demo location (Account → “Use static demo location”) help validate marker layouts without moving the simulator.

## Getting Started
1. Install Flutter 3.10+ and run `flutter pub get`.
2. For iOS: `cd ios && pod install --repo-update` (MapLibre pods required).
3. Launch: `flutter run` (grant location permissions on first launch).

### Helpful Commands
```bash
flutter clean
flutter pub get
flutter run
```

## Roadmap
See `lib/ideas/steps.txt` for the phased plan. Each task includes a test note to double-check regressions before marking complete. Content architecture lives in `lib/ideas/*`.
