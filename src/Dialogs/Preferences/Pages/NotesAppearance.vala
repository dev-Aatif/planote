/*
 * Copyright © 2025 Planote Contributors
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

public class Dialogs.Preferences.Pages.NotesAppearance : Dialogs.Preferences.Pages.BasePage {

    public NotesAppearance (Adw.PreferencesDialog preferences_dialog) {
        Object (
            preferences_dialog: preferences_dialog,
            title: _("Notes Appearance")
        );
    }

    ~NotesAppearance () {
        debug ("Destroying - Dialogs.Preferences.Pages.NotesAppearance\n");
    }

    construct {
        var settings = Services.Settings.get_default ().settings;

        // Font Family - Common fonts dropdown
        string[] common_fonts = {
            "Sans", "Serif", "Monospace",
            "Inter", "Roboto", "Open Sans", "Noto Sans",
            "Ubuntu", "Cantarell", "Liberation Sans",
            "Fira Sans", "Source Sans 3", "Lato",
            "Georgia", "Times New Roman", "Palatino",
            "Fira Code", "JetBrains Mono", "Source Code Pro"
        };
        
        var font_model = new Gtk.StringList (null);
        foreach (var font in common_fonts) {
            font_model.append (font);
        }

        var font_dropdown = new Gtk.DropDown (font_model, null) {
            valign = CENTER
        };
        
        // Find current font in list
        var current_font = settings.get_string ("notes-font-family");
        for (int i = 0; i < common_fonts.length; i++) {
            if (common_fonts[i] == current_font) {
                font_dropdown.selected = i;
                break;
            }
        }
        
        // Font preview label
        var preview_label = new Gtk.Label (_("The quick brown fox jumps over the lazy dog")) {
            wrap = true,
            max_width_chars = 30,
            margin_top = 6,
            margin_bottom = 6
        };
        update_font_preview (preview_label, current_font, settings.get_int ("notes-font-size"));

        var font_family_row = new Adw.ActionRow () {
            title = _("Font Family"),
            subtitle = _("Font used for note text")
        };
        font_family_row.add_suffix (font_dropdown);

        signal_map[font_dropdown.notify["selected"].connect (() => {
            var selected_font = common_fonts[font_dropdown.selected];
            settings.set_string ("notes-font-family", selected_font);
            update_font_preview (preview_label, selected_font, settings.get_int ("notes-font-size"));
        })] = font_dropdown;
        
        // Preview row
        var preview_row = new Adw.ActionRow () {
            title = _("Preview"),
            subtitle = _("Sample text with selected font")
        };
        preview_row.add_suffix (preview_label);

        // Font Size
        var font_size_spin = new Gtk.SpinButton.with_range (8, 48, 1) {
            valign = CENTER,
            value = settings.get_int ("notes-font-size")
        };

        var font_size_row = new Adw.ActionRow () {
            title = _("Font Size"),
            subtitle = _("Size of note text in points")
        };
        font_size_row.add_suffix (font_size_spin);

        signal_map[font_size_spin.value_changed.connect (() => {
            settings.set_int ("notes-font-size", (int) font_size_spin.value);
            update_font_preview (preview_label, common_fonts[font_dropdown.selected], (int) font_size_spin.value);
        })] = font_size_spin;

        // Status Bar Alignment
        var alignment_model = new Gtk.StringList (null);
        alignment_model.append (_("Left"));
        alignment_model.append (_("Center"));
        alignment_model.append (_("Right"));

        var alignment_dropdown = new Gtk.DropDown (alignment_model, null) {
            valign = CENTER
        };

        var current_alignment = settings.get_string ("notes-status-bar-alignment");
        if (current_alignment == "left") {
            alignment_dropdown.selected = 0;
        } else if (current_alignment == "center") {
            alignment_dropdown.selected = 1;
        } else {
            alignment_dropdown.selected = 2;
        }

        var alignment_row = new Adw.ActionRow () {
            title = _("Status Bar Alignment"),
            subtitle = _("Position of autosave indicator and word counter")
        };
        alignment_row.add_suffix (alignment_dropdown);

        signal_map[alignment_dropdown.notify["selected"].connect (() => {
            string[] alignments = { "left", "center", "right" };
            settings.set_string ("notes-status-bar-alignment", alignments[alignment_dropdown.selected]);
        })] = alignment_dropdown;

        // Show Word Count
        var word_count_switch = new Gtk.Switch () {
            valign = CENTER,
            active = settings.get_boolean ("notes-show-word-count")
        };

        var word_count_row = new Adw.ActionRow () {
            title = _("Show Word Count"),
            subtitle = _("Display word and character count in editor")
        };
        word_count_row.add_suffix (word_count_switch);
        word_count_row.set_activatable_widget (word_count_switch);

        signal_map[word_count_switch.notify["active"].connect (() => {
            settings.set_boolean ("notes-show-word-count", word_count_switch.active);
        })] = word_count_switch;

        // Typography Group
        var typography_group = new Adw.PreferencesGroup () {
            title = _("Typography")
        };
        typography_group.add (font_family_row);
        typography_group.add (font_size_row);
        typography_group.add (preview_row);

        // Status Bar Group
        var status_bar_group = new Adw.PreferencesGroup () {
            title = _("Status Bar")
        };
        status_bar_group.add (alignment_row);
        status_bar_group.add (word_count_row);

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_top = 6
        };
        content_box.append (typography_group);
        content_box.append (status_bar_group);

        var toolbar_view = new Adw.ToolbarView () {
            content = content_box
        };
        toolbar_view.add_top_bar (new Adw.HeaderBar ());

        child = toolbar_view;

        destroy.connect (() => {
            clean_up ();
        });
    }
    
    private void update_font_preview (Gtk.Label label, string font_family, int font_size) {
        var css = "label { font-family: %s; font-size: %dpt; }".printf (font_family, font_size);
        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (css);
            label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            debug ("Failed to apply font preview: %s", e.message);
        }
    }
}
