[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)

<div align="center">
  <span align="center"> <img width="128" height="128" class="center" src="data/logo.png" alt="Planote Icon"></span>
  <h1 align="center">Planote</h1>
  <h3 align="center">Your thoughts, beautifully organized</h3>
</div>

## About

Planote is a beautiful and powerful note-taking application, forked from [Planify](https://github.com/alainm23/planify) by Alain M. It combines powerful task management with elegant note-taking features.

## ✨ Features

### 🎯 Core Functionality

- **🚀 Modern Interface**: Clean, intuitive design built with GTK4 and libadwaita
- **🤚 Drag & Drop**: Effortlessly organize notes, tasks, and projects
- **💯 Progress Tracking**: Visual indicators show completion status at a glance
- **📂 Smart Organization**: Group items into sections with custom labels
- **📅 Calendar Integration**: Visualize your schedule and plan effectively
- **⏰ Flexible Reminders**: Multiple reminders per task
- **🌙 Dark Mode**: Seamless integration with system themes
- **🔍 Quick Search**: Find anything instantly
- **📝 Markdown Support**: Rich text formatting for notes and descriptions

### ☁️ Cloud Synchronization

- **Todoist Integration**: Full sync with your existing Todoist account
- **Nextcloud Support**: Keep your data private with self-hosted solutions
- **Offline Mode**: Work without internet - sync when you're back online

_Note: Planote is not created by, affiliated with, or supported by Doist_

## 📥 Installation

### 🛠 Build from Source

<details>
<summary><strong>System Requirements & Dependencies</strong></summary>

**Build Dependencies:**

| Package            | Version  |
| ------------------ | -------- |
| meson              | ≥ 0.56   |
| valac              | ≥ 0.48   |
| gio-2.0            | ≥ 2.80.3 |
| glib-2.0           | ≥ 2.80.3 |
| gee-0.8            | ≥ 0.20.6 |
| gtk4               | ≥ 4.14.4 |
| libsoup-3.0        | ≥ 3.4.4  |
| sqlite3            | ≥ 3.45.1 |
| libadwaita-1       | ≥ 1.5.3  |
| webkitgtk-6.0      | ≥ 2.44.3 |
| json-glib-1.0      | ≥ 1.8.0  |
| libecal-2.0        | ≥ 3.52.4 |
| libedataserver-1.2 | ≥ 3.52.4 |
| libportal          | ≥ 0.7.1  |
| libportal-gtk4     | ≥ 0.7.1  |
| gxml-0.20          | ≥ 0.21.0 |
| libsecret-1        | ≥ 0.21.4 |
| libspelling-dev    | latest   |
| gtksourceview-5    | 5.12.1   |

**Install Dependencies:**

**Fedora/RHEL:**

```bash
sudo dnf install vala meson ninja-build gtk4-devel libadwaita-devel libgee-devel libsoup3-devel webkitgtk6.0-devel libportal-devel libportal-gtk4-devel evolution-devel libspelling-devel gtksourceview5-devel
```

**Ubuntu/Debian:**

```bash
sudo apt install valac meson ninja-build libgtk-4-dev libadwaita-1-dev libgee-0.8-dev libjson-glib-dev libecal2.0-dev libsoup-3.0-dev libwebkitgtk-6.0-dev libportal-dev libportal-gtk4-dev libspelling-1-dev libgtksourceview-5-dev
```

</details>

**Build Instructions:**

```bash
# Clone the repository
git clone https://github.com/dev-Aatif/planote.git
cd planote

# Configure build
meson build --prefix=/usr

# Compile
cd build
ninja

# Install
sudo ninja install

# Run
io.github.dev_aatif.planote
```

### 🏗️ Development Setup

**Using GNOME Builder:**

1. Install [GNOME Builder](https://apps.gnome.org/Builder/)
2. Clone this repository
3. Open the project in GNOME Builder
4. Click "Run" to build and test

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📋 Credits

Planote is a fork of [Planify](https://github.com/alainm23/planify) by Alain M. (alainm23).
We thank Alain and all Planify contributors for their excellent work.

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

<div align="center">
  <strong>Made with 💜</strong>
</div>
