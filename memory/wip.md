---
task: Rename project from GraceWay to GraceWay
started: 2026-04-24
status: in_progress
---

## What we're doing
Full project rename: GraceWay → GraceWay across all code, config, assets, and docs.

## Approved changes (user confirmed all YES)
- App display name: `GraceWay` → `GraceWay`
- Dart package name: `graceway` → `graceway` (pubspec.yaml + all imports)
- Bundle/package ID: `com.graceway.faith` → `com.graceway.faith`
- Domain: `graceway.faith` → `graceway.faith`
- URL scheme: `graceway://` → `graceway://`
- Class names: `GraceWayApp` → `GraceWayApp`, etc.
- File renames: `graceway_*.dart`, `*.iml`, docs files

## Steps
- [ ] 1. Bulk text replacement via sed (all text files, excluding binaries/build/.git)
- [ ] 2. Rename: graceway.iml → graceway.iml
- [ ] 3. Rename: android/graceway_android.iml → android/graceway_android.iml
- [ ] 4. Rename: lib/presentation/views/shared/graceway_paywall_view.dart → graceway_paywall_view.dart
- [ ] 5. Rename Android Kotlin dir: com/graceway/faith/ → com/graceway/faith/
- [ ] 6. Rename docs files (md, html, pdf filenames)
- [ ] 7. Verify — grep for remaining graceway occurrences

## Sed replacement order (most specific first)
1. com.graceway.faith → com.graceway.faith
2. com.graceway → com.graceway
3. package:graceway/ → package:graceway/
4. graceway.faith → graceway.faith
5. graceway:// → graceway://
6. GraceWayApp → GraceWayApp
7. GraceWay → GraceWay
8. graceway → graceway (catches remaining: binary names, strings, etc.)

## Files excluded from sed
- .git/, build/, node_modules/, .dart_tool/
- *.pdf, *.png, *.jpg, *.ico, *.gif, *.ttf, *.otf, *.woff, *.woff2
- pubspec.lock
