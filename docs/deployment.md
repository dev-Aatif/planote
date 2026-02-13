# Planote Deployment Guide

This guide covers the process of packaging and releasing Planote.

## 📦 Packaging via Flatpak

Planote is designed to be distributed via Flatpak.

### Building the Flatpak
1.  Ensure `flatpak` and `flatpak-builder` are installed.
2.  Run the build command:

```bash
flatpak-builder --user --install --force-clean build-dir io.github.dev_aatif.planote.json
```

### Running the Flatpak
Once installed, run:

```bash
flatpak run io.github.dev_aatif.planote
```

## 🚀 Release Process

1.  **Update Version**:
    -   Bump the version number in `meson.build`.
    -   Update `CHANGELOG.md` with the new version and date.
    -   Update `data/io.github.dev_aatif.planote.appdata.xml.in` with a new `<release>` entry.

2.  **Verify**:
    -   Run a clean build.
    -   Run all tests (`meson test`).
    -   Manual verification of key features.

3.  **Tag and Push**:
    -   Commit changes: `git commit -am "Release 1.0.0"`
    -   Create a tag: `git tag -a v1.0.0 -m "Version 1.0.0"`
    -   Push to GitHub: `git push origin v1.0.0`

4.  **GitHub Release**:
    -   Draft a new release on GitHub.
    -   Copy content from `RELEASE_NOTES.md` or `CHANGELOG.md`.
    -   (Optional) Attach the Flatpak bundle if generated manually.
