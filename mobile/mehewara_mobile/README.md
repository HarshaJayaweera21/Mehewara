# Mehewara mobile application

Updated 2026-09-26 from the checked-in Flutter code.

## Current state

`lib/main.dart` launches the Flutter counter demo. Account, report, problem, work-order, network, and storage paths have been scaffolded, but there is no connected resident or crew workflow. The WorkOrder service file is empty. Do not treat the folder structure as evidence of working features.

The app currently does not submit municipal reports, authenticate against ASP.NET, show assigned work, start/complete jobs, or demonstrate the cross-client workflow. These remain future work in the [project plan](../../plan.md).

## Run the starter

Use Flutter with a Dart SDK satisfying `^3.13.3`, as specified in `pubspec.yaml`. From this directory:

```powershell
flutter pub get
flutter run
```

Choose an installed device/emulator supported by the local Flutter installation. The displayed application is the starter counter.

```powershell
flutter analyze
flutter test
```

The checked-in widget test targets the starter. These commands were not executed during the documentation update. The dependency list currently contains Flutter and Cupertino icons, with Flutter test/lints for development; it does not establish an implemented API, camera, GPS, or secure-token feature.

## Future integration

The [current API reference](<../../Mehewara_API_Contract (1).md>) lists implemented server routes. WorkOrder list/start/complete routes are currently absent and must be implemented before a mobile crew flow can use them. The [root guide](../../README.md) describes the running backend/web/AI components.
