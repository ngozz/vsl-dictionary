# VSL Dictionary — Từ điển Ký hiệu Việt Nam

A fast, offline-first Flutter app for browsing the Vietnamese Sign Language
dictionary. Video-first, search-first, no fluff.

**Source data:** dictionary content transcribed from the National Sign
Language Dictionary at [qipedc.moet.gov.vn/dictionary](https://qipedc.moet.gov.vn/dictionary).

## What it does

- **Search-first** home: instant accent-insensitive search with prefix-match
  ranking and highlight, over 4,300 signs.
- **Browse tabs** — Tất cả / Từ vựng (alphabetically grouped with an A–Z jump
  rail and draggable scrollbar), Số đếm, Bảng chữ cái.
- **Word detail** — sign video (H.264, silent by design), per-region variants
  (Bắc / Trung / Nam) if available, 0.5× slow-mo, fullscreen playback,
  description and illustration images.
- **Personal touches** — favorites, default region preference, three themes
  (Tối / Đen / Sáng, green-seeded Material 3), interface in Vietnamese.
- **Fully offline** — all media is bundled in the app. A CDN/streaming mode is
  planned (the media layer is already URL-shaped for it).

## Project layout

```
vsl-dictionary/
├── data/
│   ├── vsl_data.json     # dictionary index (id, word, type, description…)
│   ├── videos/           # 4,364 re-encoded sign videos (H.264 mp4, no audio)
│   └── images/           # 1,840 illustrations (WebP q80)
├── lib/
│   ├── main.dart         # app entry + Material You themes
│   ├── models/word.dart  # data model
│   ├── services/         # dictionary search, media resolution, settings
│   └── screens/          # home (search/browse) + word detail
├── .github/workflows/    # build + release CI (see below)
└── icon.png              # launcher icon source
```

The `_sources/` folder (not included here) holds the original Unity project.
Data is mine: video files are re-encoded to H.264 mp4, images to WebP.

## Building

```bash
flutter pub get
flutter run              # run on a device
flutter build apk --release         # Android
flutter build web --release         # Web → build/web
flutter build ios --no-codesign     # iOS (needs Xcode + macOS)
```

## CI/CD (GitHub Actions)

`.github/workflows/build.yml` builds and publishes automatically. Triggers:

| Trigger | Effect |
|---|---|
| Push commit whose **message contains `[build]`** | Full build: Android APK + Web + unsigned iOS IPA |
| **Manual** (`workflow_dispatch`) | Same, any time |
| Any other push | CI skipped on purpose |

Each build run **creates a GitHub Release** (`v<run-number>`) containing:

- `vsl-dictionary-android.apk` — sideload-ready
- `vsl-dictionary-ios-unsigned.ipa` — not code-signed; resign or use a
  sideload tool (e.g. AltStore, Sideloadly) to install
- `vsl-dictionary-web.zip` — static web build

The web artifact is also **deployed to GitHub Pages** automatically on each
`main` build (base path is baked at build time so it works under
`/<repo>/`). The online app is available at
`https://ngozz.github.io/vsl-dictionary/`.

The iOS build can be added to SideStore or AltStore using this source:
`https://ngozz.github.io/vsl-dictionary/altstore-source.json`. It points to the
latest unsigned IPA release; SideStore/AltStore signs it during installation.
The source file is `web/altstore-source.json`.

### Android signing

Android updates must use the same signing certificate as the installed
version. To use one certificate locally and in GitHub Actions:

1. Generate a release keystore once, outside the repository:

   ```bash
   keytool -genkeypair -v \
     -keystore vsl-dictionary-release.jks \
     -alias vsl-dictionary \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Keep the `.jks` file and its passwords private. Back them up securely; if
   the keystore is lost, existing installations cannot be updated.
3. Configure local Flutter builds with `android/key.properties`:

   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=vsl-dictionary
   storeFile=/absolute/path/to/vsl-dictionary-release.jks
   ```

   Do not commit `android/key.properties` or the keystore.
4. Add the same values to GitHub repository secrets:
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS`. The keystore should be
   base64-encoded for the secret:

   ```bash
   base64 -w 0 vsl-dictionary-release.jks
   ```

5. Configure `android/app/build.gradle.kts` to read `key.properties` locally
   and use the decoded GitHub secret in CI, then build with
   `flutter build apk --release`.

Before switching signing keys, verify the certificate fingerprints:

```bash
keytool -list -v -keystore vsl-dictionary-release.jks | grep -E 'Alias name|SHA256'
apksigner verify --print-certs path/to/app.apk
```

Changing the application ID or signing key creates a separate Android app
instead of an update.

### Repo setup notes

1. Enable **Actions → Settings → Pages → GitHub Pages** with the workflow
   source set (the `deploy-pages` job configures this).
2. Media (~540 MB) makes the repo big; consider
   [`git lfs`](https://git-lfs.com) for `data/videos/*` if you hit push
   limits — or keep media out of git and fetch it from your CDN in a later
   iteration (the media service is designed to swap prefixes to URLs).
3. iOS builds need no extra setup (no signing config = unsigned IPA on a
   macOS runner).

## Data attribution

Dictionary contents sourced from the
[Việt Nam Dictionary of Sign Language](https://qipedc.moet.gov.vn/dictionary)
(Trung tâm Ký hiệu Việt Nam / Bộ Giáo dục và Đào tạo). This project is a
personal-use reader, not the original work.
