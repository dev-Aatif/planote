# Planote Development Guide

This guide covers how to build, run, and contribute to Planote.

## 🛠 Prerequisites

To build Planote from source, you need the following dependencies installed on your system.

### Build Tools
-   `meson` (>= 0.56)
-   `ninja`
-   `valac` (>= 0.48)

### Libraries (Development Packages)
-   `gtk4` (>= 4.14.4)
-   `libadwaita-1` (>= 1.5.3)
-   `libgee-0.8` (>= 0.20.6)
-   `json-glib-1.0` (>= 1.8.0)
-   `libsoup-3.0` (>= 3.4.4)
-   `sqlite3` (>= 3.45.1)
-   `webkitgtk-6.0` (>= 2.44.3)
-   `libportal` (>= 0.7.1)
-   `libportal-gtk4` (>= 0.7.1)
-   `libsecret-1` (>= 0.21.4)
-   `libspelling-1`
-   `gtksourceview-5`

## 🏗️ Building and Running

### 1. Configure the Build
Use `meson` to configure the build directory.

```bash
meson build --prefix=/usr
```

### 2. Compile
Compile the project using `ninja`.

```bash
cd build
ninja
```

### 3. Run Locally
You can run the compiled binary directly from the build directory.

```bash
./io.github.dev_aatif.planote
```

### 4. Install (Optional)
To install Planote system-wide:

```bash
sudo ninja install
```

## 📂 Project Structure

-   **`src/`**: User Interface and application logic (Views, Dialogs, Windows).
-   **`core/`**: Core business logic, Services, and Objects.
    -   **`Services/`**: Database, Settings, SyncManager, UndoManager.
    -   **`Objects/`**: Data models (Task, Note, Project, Label).
    -   **`Widgets/`**: Reusable UI components (MarkdownEditor, etc.).
-   **`data/`**: Assets, GResource files, translations, and desktop files.
-   **`tests/`**: Unit tests.

## 💻 IDE Setup

### GNOME Builder (Recommended)
1.  Open GNOME Builder.
2.  Click "Clone Repository" and enter `https://github.com/dev-Aatif/planote.git`.
3.  Builder will automatically handle dependencies (via Flatpak) and build configuration.
4.  Click the **Run** button to build and launch.

### VS Code
1.  Install the **Vala** extension for syntax highlighting.
2.  Use the integrated terminal to run build commands.
