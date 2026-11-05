# Publishing checklist — vsl-dictionary

## Release hygiene
- [x] `LICENSE` (MIT), `fastlane/metadata/android/` (en-US + vi-VN text, icon,
      4 phone screenshots, `changelogs/1.txt`).
- [ ] Tag the release commit — F-Droid reads these tags:
      `git tag v1.0.0 && git push origin v1.0.0`
- [ ] `pubspec.yaml` version is `1.0.0+1`. For every future store release the
      `+N` (versionCode) must strictly increase.
- [ ] CI publishes on a `[build]` commit marker and auto-attaches APKs/IPAs to
      a GitHub Release. Edit the release text for v1.0.0 to be user-facing.

## Store listings
- Keep `short_description.txt` ≤ 80 chars (no trailing dot) and `title.txt`
  ≤ 30 chars.
- For every future release add `changelogs/<versionCode>.txt` (≤ 500 chars) in
  both locales — F-Droid reads them automatically.

## F-Droid
1. Repo requirements: FOSS license ✓, FOSS dependencies ✓, version tags,
   fastlane metadata ✓.
2. Open a submission: <https://gitlab.com/fdroid/rfp/issues> (or the forum
   submission queue).
3. Fork <https://gitlab.com/fdroid/fdroiddata> and add
   `metadata/com.ngozz.vsl_dictionary.yml`. Copy the build block from an
   existing Flutter app in fdroiddata; point `UpdateCheckData` at
   `pubspec.yaml` for auto-updates.
4. Build the committed (CDN) state only — do **not** point the metadata at the
   FULL variant. Keep the committed state = `tools/toggle_videos.ps1 0`.
5. Validate with `fdroid lint`, test the build via the fdroiddata CI, then
   open a merge request. Review takes days to weeks.

Notes:
- F-Droid signs the APK with its own key; `vsl-dictionary.jks` stays local and
  is never committed (CI signs GitHub releases from repo secrets).
- The FULL APK (~600 MB, videos bundled) is a GitHub-only convenience.
- Be ready to answer where the dictionary data/videos come from (MoET portal
  via the NgonTay project) — reviewers may raise NonFreeAssets for bundled
  media; the CDN variant bundles none.

## Play Store (optional)
- One-time $25 fee; reuse the fastlane text and screenshots for the listing.
- Build an AAB: `flutter build appbundle --release`.
- Data safety: the app collects no user data. Content rating: educational.
- Distribute the CDN (small) APK/AAB, not the FULL variant.

## Never commit
- `android/key.properties`, `*.jks` (gitignored; release signing uses GitHub
  secrets).
