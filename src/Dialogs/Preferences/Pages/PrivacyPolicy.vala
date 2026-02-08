/*
 * Copyright © 2024 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 */

public class Dialogs.Preferences.Pages.PrivacyPolicy : Dialogs.Preferences.Pages.BasePage {
    public PrivacyPolicy (Adw.PreferencesDialog preferences_dialog) {
        Object (
            preferences_dialog: preferences_dialog,
            title: _("Privacy Policy")
        );
    }

    ~PrivacyPolicy () {
        debug ("Destroying - Dialogs.Preferences.Pages.PrivacyPolicy\n");
    }

    construct {
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
            vexpand = true,
            hexpand = true,
            margin_start = 24,
            margin_end = 24,
            margin_bottom = 24,
            margin_top = 24
        };

        // Header
        var hero_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            halign = Gtk.Align.CENTER,
            margin_bottom = 12
        };

        var shield_icon = new Gtk.Image.from_icon_name ("shield-safe-symbolic") {
            pixel_size = 64,
            css_classes = { "accent" }
        };

        var hero_title = new Gtk.Label (_("Your Privacy Matters")) {
            css_classes = { "title-1" },
            halign = Gtk.Align.CENTER
        };

        var hero_subtitle = new Gtk.Label (_("Planote respects your privacy and keeps your data safe.")) {
            css_classes = { "body" },
            halign = Gtk.Align.CENTER,
            wrap = true,
            justify = Gtk.Justification.CENTER
        };

        hero_box.append (shield_icon);
        hero_box.append (hero_title);
        hero_box.append (hero_subtitle);
        content_box.append (hero_box);

        // No Data Collection Section
        var no_collection_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            css_classes = { "card" },
            margin_start = 12,
            margin_end = 12
        };

        var no_collection_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16
        };

        var no_collection_icon = new Gtk.Image.from_icon_name ("eye-not-looking-symbolic") {
            pixel_size = 24,
            css_classes = { "success" }
        };

        var no_collection_title = new Gtk.Label (_("No Data Collection")) {
            css_classes = { "title-4" },
            halign = Gtk.Align.START,
            hexpand = true
        };

        no_collection_header.append (no_collection_icon);
        no_collection_header.append (no_collection_title);

        var no_collection_desc = new Gtk.Label (_("We do not collect, store, or transmit any of your personal data. Your tasks, notes, and settings stay on your device.")) {
            css_classes = { "body" },
            wrap = true,
            xalign = 0,
            margin_start = 16,
            margin_end = 16,
            margin_bottom = 16
        };

        no_collection_box.append (no_collection_header);
        no_collection_box.append (no_collection_desc);
        content_box.append (no_collection_box);

        // Local Storage Section
        var local_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            css_classes = { "card" },
            margin_start = 12,
            margin_end = 12
        };

        var local_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16
        };

        var local_icon = new Gtk.Image.from_icon_name ("drive-harddisk-symbolic") {
            pixel_size = 24,
            css_classes = { "accent" }
        };

        var local_title = new Gtk.Label (_("Local Storage Only")) {
            css_classes = { "title-4" },
            halign = Gtk.Align.START,
            hexpand = true
        };

        local_header.append (local_icon);
        local_header.append (local_title);

        var local_desc = new Gtk.Label (_("All your data is stored locally on your computer in a SQLite database. You have full control over your information.")) {
            css_classes = { "body" },
            wrap = true,
            xalign = 0,
            margin_start = 16,
            margin_end = 16,
            margin_bottom = 16
        };

        local_box.append (local_header);
        local_box.append (local_desc);
        content_box.append (local_box);

        // No Tracking Section
        var no_tracking_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            css_classes = { "card" },
            margin_start = 12,
            margin_end = 12
        };

        var no_tracking_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16
        };

        var no_tracking_icon = new Gtk.Image.from_icon_name ("security-high-symbolic") {
            pixel_size = 24,
            css_classes = { "warning" }
        };

        var no_tracking_title = new Gtk.Label (_("No Analytics or Tracking")) {
            css_classes = { "title-4" },
            halign = Gtk.Align.START,
            hexpand = true
        };

        no_tracking_header.append (no_tracking_icon);
        no_tracking_header.append (no_tracking_title);

        var no_tracking_desc = new Gtk.Label (_("Planote does not include any analytics, telemetry, or tracking code. We don't know how you use the app — and that's by design.")) {
            css_classes = { "body" },
            wrap = true,
            xalign = 0,
            margin_start = 16,
            margin_end = 16,
            margin_bottom = 16
        };

        no_tracking_box.append (no_tracking_header);
        no_tracking_box.append (no_tracking_desc);
        content_box.append (no_tracking_box);

        // Third-Party Sync Section
        var sync_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            css_classes = { "card" },
            margin_start = 12,
            margin_end = 12
        };

        var sync_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16
        };

        var sync_icon = new Gtk.Image.from_icon_name ("cloud-outline-thick-symbolic") {
            pixel_size = 24,
            css_classes = { "accent" }
        };

        var sync_title = new Gtk.Label (_("Optional Third-Party Sync")) {
            css_classes = { "title-4" },
            halign = Gtk.Align.START,
            hexpand = true
        };

        sync_header.append (sync_icon);
        sync_header.append (sync_title);

        var sync_desc = new Gtk.Label (_("If you choose to sync with services like Todoist or CalDAV, your data is transmitted directly to those services using your own account. We never see or store this data.")) {
            css_classes = { "body" },
            wrap = true,
            xalign = 0,
            margin_start = 16,
            margin_end = 16,
            margin_bottom = 16
        };

        sync_box.append (sync_header);
        sync_box.append (sync_desc);
        content_box.append (sync_box);

        // Legal Notice Section
        var legal_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
            css_classes = { "card" },
            margin_start = 12,
            margin_end = 12
        };

        var legal_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16
        };

        var legal_icon = new Gtk.Image.from_icon_name ("dialog-information-symbolic") {
            pixel_size = 24,
            css_classes = { "dim-label" }
        };

        var legal_title = new Gtk.Label (_("Legal")) {
            css_classes = { "title-4" },
            halign = Gtk.Align.START,
            hexpand = true
        };

        legal_header.append (legal_icon);
        legal_header.append (legal_title);

        var legal_desc = new Gtk.Label (_("This application comes with absolutely no warranty. See the GNU General Public Licence, version 2 or later for details.")) {
            css_classes = { "body" },
            wrap = true,
            xalign = 0,
            margin_start = 16,
            margin_end = 16,
            margin_bottom = 16
        };

        legal_box.append (legal_header);
        legal_box.append (legal_desc);
        content_box.append (legal_box);

        // Open Source Notice
        var opensource_label = new Gtk.Label (_("Planote is free and open source software. You can review the source code anytime.")) {
            css_classes = { "caption", "dim-label" },
            halign = Gtk.Align.CENTER,
            wrap = true,
            justify = Gtk.Justification.CENTER,
            margin_top = 12
        };
        content_box.append (opensource_label);

        var scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            child = content_box
        };

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (new Adw.HeaderBar ());
        toolbar_view.content = scrolled_window;

        child = toolbar_view;

        destroy.connect (() => {
            clean_up ();
        });
    }

    public override void clean_up () {
        foreach (var entry in signal_map.entries) {
            entry.value.disconnect (entry.key);
        }

        signal_map.clear ();
    }
}
