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

public class Dialogs.NoteEditorDialog : Adw.Window {
    public Objects.Note note { get; construct; }

    private Widgets.MarkdownEditor editor;
    private Gtk.Label word_count_label;
    private Gtk.Label save_status_label;
    private Gtk.DropDown toolbar_heading_dropdown;
    private uint save_timeout_id = 0;

    public NoteEditorDialog (Objects.Note note) {
        Object (note: note);
    }

    private Gtk.Entry title_entry;

    construct {
        title = note.title;
        default_width = 800;
        default_height = 600;
        modal = true;

        var headerbar = new Adw.HeaderBar ();

        var save_button = new Gtk.Button.with_label (_("Save")) {
             css_classes = { "suggested-action" }
        };
        headerbar.pack_end (save_button);
        save_button.clicked.connect (() => {
             save_note ();
             close ();
        });

        // Keyboard shortcuts help button
        var shortcuts_button = new Gtk.Button () {
            icon_name = "keyboard-shortcuts-symbolic",
            tooltip_text = _("Keyboard Shortcuts")
        };
        shortcuts_button.add_css_class ("flat");
        headerbar.pack_end (shortcuts_button);
        shortcuts_button.clicked.connect (() => {
            try {
                var shortcuts_builder = new Gtk.Builder ();
                shortcuts_builder.add_from_resource ("/io/github/dev_aatif/planote/shortcuts.ui");
                
                var shortcuts_window = (Gtk.ShortcutsWindow) shortcuts_builder.get_object ("shortcuts-planote");
                shortcuts_window.set_transient_for (this);
                shortcuts_window.show ();
            } catch (Error e) {
                warning ("Failed to open shortcuts window: %s\n", e.message);
            }
        });

        editor = new Widgets.MarkdownEditor ();
        editor.set_text (note.content);
        editor.margin_top = editor.margin_bottom = editor.margin_start = editor.margin_end = 24;
        editor.vexpand = true;
        editor.hexpand = true;
        
        // Sync toolbar dropdown with editor's heading level
        editor.heading_level_changed.connect ((level) => {
            if (toolbar_heading_dropdown != null) {
                toolbar_heading_dropdown.selected = (uint) level;
            }
        });

        word_count_label = new Gtk.Label ("") {
            css_classes = { "caption", "dimmed" }
        };

        save_status_label = new Gtk.Label ("") {
            css_classes = { "caption", "dimmed" }
        };

        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 6,
            margin_top = 6
        };
        status_box.append (save_status_label);
        status_box.append (word_count_label);

        // Apply status bar alignment from settings
        var settings = Services.Settings.get_default ().settings;
        apply_status_bar_alignment (status_box, settings.get_string ("notes-status-bar-alignment"));

        settings.changed["notes-status-bar-alignment"].connect (() => {
            apply_status_bar_alignment (status_box, settings.get_string ("notes-status-bar-alignment"));
        });

        var toolbar = create_toolbar ();

        title_entry = new Gtk.Entry () {
            text = note.title,
            placeholder_text = _("Untitled Note"),
            margin_start = 12,
            margin_end = 12,
            margin_top = 12
        };
        title_entry.add_css_class ("title-2");
        title_entry.add_css_class ("flat");

        title_entry.changed.connect (() => {
            title = title_entry.text;
            schedule_autosave (editor.get_text ());
        });

        // Put editor in a scrolled window so it expands
        var scrolled = new Gtk.ScrolledWindow () {
            vexpand = true,
            hexpand = true,
            child = editor
        };

        // Main layout: title, toolbar, scrollable editor area
        var editor_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            vexpand = true
        };
        editor_area.append (title_entry);
        editor_area.append (toolbar);
        editor_area.append (scrolled);

        // Outer box: editor area + fixed status bar at bottom
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.append (editor_area);
        content_box.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        content_box.append (status_box);

        var toolbar_view = new Adw.ToolbarView () {
            content = content_box
        };
        toolbar_view.add_top_bar (headerbar);

        content = toolbar_view;

        editor.text_changed.connect ((text) => {
            update_word_count (text);
            schedule_autosave (text);
        });

        update_word_count (note.content);

        // Grab focus on editor when dialog is shown
        map.connect (() => {
            Timeout.add (100, () => {
                // Focus title if it's "Untitled Note" (new note), otherwise editor
                if (note.title == _("Untitled Note")) {
                    title_entry.grab_focus ();
                    title_entry.select_region (0, -1);
                } else {
                    editor.text_view.grab_focus ();
                    // Position cursor at end of text
                    Gtk.TextIter end_iter;
                    editor.buffer.get_end_iter (out end_iter);
                    editor.buffer.place_cursor (end_iter);
                }
                return Source.REMOVE;
            });
        });

        // Keyboard shortcuts using key event controller (more reliable)
        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            // Check for Ctrl modifier
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                switch (keyval) {
                    case Gdk.Key.b:
                        editor.toggle_bold_format ();
                        return true;
                    case Gdk.Key.i:
                        editor.toggle_italic_format ();
                        return true;
                    case Gdk.Key.minus:
                        editor.toggle_strikethrough_format ();
                        return true;
                    case Gdk.Key.a:
                        editor.select_all ();
                        return true;
                    case Gdk.Key.z:
                        editor.undo ();
                        return true;
                    case Gdk.Key.y:
                        editor.redo ();
                        return true;
                }
            }

            // F11 for fullscreen toggle (no modifier needed)
            if (keyval == Gdk.Key.F11) {
                if (fullscreened) {
                    unfullscreen ();
                } else {
                    fullscreen ();
                }
                return true;
            }

            return false;
        });
        ((Gtk.Widget) this).add_controller (key_controller);

        // Handle window close to ensure save completes
        close_request.connect (() => {
            if (save_timeout_id > 0) {
                Source.remove (save_timeout_id);
                save_timeout_id = 0;
            }
            save_note ();
            return false;
        });
    }

    private void update_word_count (string text) {
        // Split and filter out empty strings for accurate word count
        var parts = text.split_set (" \n\t");
        int word_count = 0;
        foreach (var part in parts) {
            if (part.strip ().length > 0) {
                word_count++;
            }
        }
        var chars = text.length;
        word_count_label.label = _("%d words, %d characters").printf (word_count, chars);
    }

    private void schedule_autosave (string text) {
        if (save_timeout_id > 0) {
            Source.remove (save_timeout_id);
        }

        save_status_label.label = _("Saving...");

        save_timeout_id = Timeout.add (500, () => {
            note.title = title_entry.text;
            note.content = text;
            note.update_modified_time (); // This also updates search_index
            Services.Store.instance ().update_note (note);
            save_timeout_id = 0;

            save_status_label.label = _("Saved");

            // Clear status after 2 seconds
            Timeout.add (2000, () => {
                save_status_label.label = "";
                return Source.REMOVE;
            });

            return Source.REMOVE;
        });
    }

    private void save_note () {
        note.title = title_entry.text;
        note.content = editor.get_text ();
        note.update_modified_time (); // This also updates search_index
        Services.Store.instance ().update_note (note);
    }

    private Gtk.Widget create_toolbar () {
        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 6,
            margin_end = 6,
            margin_top = 6,
            margin_bottom = 6
        };

        var bold_btn = create_toolbar_button ("text-bold-symbolic", _("Bold"));
        bold_btn.clicked.connect (() => editor.toggle_bold_format ());
        toolbar.append (bold_btn);

        var italic_btn = create_toolbar_button ("text-italic-symbolic", _("Italic"));
        italic_btn.clicked.connect (() => editor.toggle_italic_format ());
        toolbar.append (italic_btn);

        var strike_btn = create_toolbar_button ("text-strikethrough-symbolic", _("Strikethrough"));
        strike_btn.clicked.connect (() => editor.toggle_strikethrough_format ());
        toolbar.append (strike_btn);

        toolbar.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));

        // Heading dropdown (H1-H6)
        var heading_model = new Gtk.StringList (null);
        heading_model.append (_("Normal"));
        heading_model.append ("H1");
        heading_model.append ("H2");
        heading_model.append ("H3");
        heading_model.append ("H4");
        heading_model.append ("H5");
        heading_model.append ("H6");

        toolbar_heading_dropdown = new Gtk.DropDown (heading_model, null) {
            tooltip_text = _("Heading Level")
        };
        toolbar_heading_dropdown.selected = 0;
        toolbar_heading_dropdown.notify["selected"].connect (() => {
            int selected = (int) toolbar_heading_dropdown.selected;
            editor.current_heading_level = selected; // Update sticky heading level
            editor.apply_heading_format (selected); // Apply format (0 = Normal removes heading)
        });
        toolbar.append (toolbar_heading_dropdown);

        toolbar.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));

        var ul_btn = create_toolbar_button ("view-list-symbolic", _("Bulleted List"));
        ul_btn.clicked.connect (() => editor.apply_unordered_list_format ());
        toolbar.append (ul_btn);

        var ol_btn = create_toolbar_button ("view-list-ordered-symbolic", _("Ordered List"));
        ol_btn.clicked.connect (() => editor.apply_ordered_list_format ());
        toolbar.append (ol_btn);

        toolbar.append (new Gtk.Separator (Gtk.Orientation.VERTICAL));

        var link_btn = create_toolbar_button ("chain-link-loose-symbolic", _("Link"));
        link_btn.clicked.connect (() => editor.insert_link ());
        toolbar.append (link_btn);

        var code_btn = create_toolbar_button ("code-symbolic", _("Code"));
        code_btn.clicked.connect (() => editor.toggle_code_format ());
        toolbar.append (code_btn);

        return toolbar;
    }

    private Gtk.Button create_toolbar_button (string icon_name, string tooltip) {
        var btn = new Gtk.Button.from_icon_name (icon_name) {
            tooltip_text = tooltip
        };
        btn.add_css_class ("flat");
        return btn;
    }

    private Gtk.Button create_toolbar_button_label (string label, string tooltip) {
        var btn = new Gtk.Button.with_label (label) {
            tooltip_text = tooltip
        };
        btn.add_css_class ("flat");
        return btn;
    }

    private void apply_status_bar_alignment (Gtk.Box status_box, string alignment) {
        switch (alignment) {
            case "left":
                status_box.halign = Gtk.Align.START;
                break;
            case "center":
                status_box.halign = Gtk.Align.CENTER;
                break;
            case "right":
            default:
                status_box.halign = Gtk.Align.END;
                break;
        }
    }
}
