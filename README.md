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
- **Fully offline capable** — sign videos stream from the CDN by default
  (small ~25 MB APK) and can be downloaded in-app for a fully offline
  library; a FULL variant (~600 MB APK) bundles everything instead.

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
| Push commit whose **message contains `[build]`** | Builds **both variants**: Android APK + unsigned iOS IPA + Web |
| **Manual** (`workflow_dispatch`) | Same, any time |
| Any other push | CI skipped on purpose |

Each build run **creates a GitHub Release** (`v<run-number>`) containing
**both variants**, built from the same commit:

- `vsl-dictionary-android.apk` — SMALL (CDN): streams sign videos from the
  media host, downloads them in-app for offline use
- `vsl-dictionary-android-full.apk` — FULL: all media bundled (~600 MB)
- `vsl-dictionary-ios-unsigned.ipa` — SMALL (CDN); the SideStore/AltStore
  source points here
- `vsl-dictionary-ios-full-unsigned.ipa` — FULL: all media bundled
- `vsl-dictionary-web.zip` — static web build

The web artifact is also **deployed to GitHub Pages** automatically on each
`main` build (base path is baked at build time so it works under
`/<repo>/`). The online app is available at
`https://ngozz.github.io/vsl-dictionary/`.

## CDN mode (SMALL builds)

Sign videos stream from `https://vsl-dictionary-media.ngozz.workers.dev`
(Cloudflare Workers static assets, free tier). Resolution order: downloaded
copy → CDN stream → bundled asset. `tools/toggle_videos.ps1` flips between
variants (pubspec asset line + `lib/config.dart` together); CI runs it
twice per release to build both.

- **Download all** (Settings → Tải xuống & cập nhật): ~513 MB into app
  storage with size+SHA-256 verification before promotion; re-running only
  enqueues the delta.
- **Update check**: at startup (toggleable) or manually — compares manifest
  sizes against local copies and prompts before re-downloading anything.
- **Web**: streams CDN-first; if the CDN fails for a video, the player
  retries it from the bundled GitHub Pages copy.

The iOS build can be added to SideStore or AltStore using this source:
`https://ngozz.github.io/vsl-dictionary/altstore-source.json`. It points to
the latest **small** unsigned IPA release (offline comes from in-app
downloads); SideStore/AltStore signs it during installation.

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
