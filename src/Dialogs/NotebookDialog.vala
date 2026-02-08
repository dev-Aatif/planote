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

public class Dialogs.NotebookDialog : Adw.Window {
    public Objects.Notebook? notebook { get; construct; default = null; }
    
    private Adw.EntryRow name_row;
    private Widgets.ColorPickerRow color_row;
    private bool is_edit_mode;
    
    private Gtk.Stack emoji_color_stack;
    private Gtk.Switch emoji_switch;
    private Gtk.Label emoji_label;
    private Gtk.Image color_icon;
    private Gee.HashMap<ulong, GLib.Object> signal_map = new Gee.HashMap<ulong, GLib.Object> ();

    public NotebookDialog () {
        Object (
            modal: true,
            default_width: 400
        );
    }

    public NotebookDialog.edit (Objects.Notebook notebook) {
        Object (
            modal: true,
            default_width: 400,
            notebook: notebook
        );
    }

    construct {
        is_edit_mode = notebook != null;
        title = is_edit_mode ? _("Edit Notebook") : _("New Notebook");

        var headerbar = new Adw.HeaderBar ();
        var action_button = new Gtk.Button.with_label (is_edit_mode ? _("Save") : _("Create")) {
             css_classes = { "suggested-action" }
        };
        headerbar.pack_end (action_button);
        action_button.clicked.connect (() => {
            if (is_edit_mode) {
                update_notebook ();
            } else {
                create_notebook ();
            }
            close ();
        });

        // Emoji & Color Preview
        var current_emoji = is_edit_mode ? notebook.icon : "📓";
        var current_color = is_edit_mode ? notebook.color : "blue";
        
        emoji_label = new Gtk.Label (current_emoji);
        
        color_icon = new Gtk.Image.from_icon_name ("notebook-symbolic") {
            pixel_size = 32,
            icon_size = Gtk.IconSize.LARGE,
            css_classes = { "view-icon" }
        };
        Util.get_default ().set_widget_color (current_color, color_icon);
        
        emoji_color_stack = new Gtk.Stack () {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        
        var color_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.CENTER
        };
        color_box.append (color_icon);
        
        emoji_color_stack.add_named (color_box, "color");
        emoji_color_stack.add_named (emoji_label, "emoji");
        
        // Determine initial state: if icon is a default notebook emoji (📓) or matches current color, assume color mode?
        // Or better, just check if it's an emoji-style notebook. 
        // For simplicity, let's use the ProjectIconStyle logic or just default to color mode unless user explicitly picks emoji
        // But Notebook object store icon as string.
        bool use_emoji = true; // Default to showing what we have
        // Heuristic: if icon is one of the generic colored ones, maybe show color? 
        // But for now let's just default to "Use Emoji" being active if the icon isn't empty
        
        emoji_color_stack.visible_child_name = "emoji"; 
        
        var emoji_picker_button = new Gtk.Button () {
            hexpand = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            height_request = 64,
            width_request = 64,
            margin_top = 6,
            child = emoji_color_stack,
            css_classes = { "title-2", "button-emoji-picker" }
        };

        var emoji_chooser = new Gtk.EmojiChooser () {
            has_arrow = false
        };
        emoji_chooser.set_parent (emoji_picker_button);

        // Inputs
        name_row = new Adw.EntryRow () {
            title = _("Name"),
            text = is_edit_mode ? notebook.name : _("New Notebook")
        };
        
        // Emoji Switch
        var emoji_icon_img = new Gtk.Image.from_icon_name ("reaction-add2-symbolic");
        emoji_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER,
            active = true // Default to emoji mode as it's more expressive for notebooks
        };
        
        var emoji_switch_row = new Adw.ActionRow ();
        emoji_switch_row.title = _("Use Emoji");
        emoji_switch_row.set_activatable_widget (emoji_switch);
        emoji_switch_row.add_prefix (emoji_icon_img);
        emoji_switch_row.add_suffix (emoji_switch);
        
        color_row = new Widgets.ColorPickerRow ();
        if (is_edit_mode && notebook.color != "") {
            color_row.color = notebook.color;
        } else {
            color_row.color = "blue";
        }
        
        // Wrap color picker in revealer
        var color_group = new Adw.Bin () {
            margin_end = 12,
            margin_start = 12,
            margin_top = 12,
            margin_bottom = 1,
            valign = Gtk.Align.START,
            css_classes = { "card" },
            child = color_row
        };
        
        var color_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            reveal_child = !emoji_switch.active,
            child = color_group
        };
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.append (emoji_picker_button);
        
        var group_wrapper = new Adw.PreferencesGroup () {
             margin_top = 24
        };
        group_wrapper.add (name_row);
        group_wrapper.add (emoji_switch_row);
        
        content_box.append (group_wrapper);
        content_box.append (color_revealer);

        var content_clamp = new Adw.Clamp () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_top = 6,
            child = content_box
        };

        var toolbar_view = new Adw.ToolbarView () {
            content = content_clamp
        };
        toolbar_view.add_top_bar (headerbar);
        
        content = toolbar_view;

        // Connections
        // Bind action button sensitivity to name_row text
        name_row.notify["text"].connect (() => {
            action_button.sensitive = name_row.text.strip ().length > 0;
        });
        
        signal_map[emoji_chooser.emoji_picked.connect ((emoji) => {
            emoji_label.label = emoji;
        })] = emoji_chooser;
        
        signal_map[emoji_switch.notify["active"].connect (() => {
            if (emoji_switch.active) {
                color_revealer.reveal_child = false;
                emoji_color_stack.visible_child_name = "emoji";
                
                if (emoji_label.label.strip () == "") {
                    emoji_label.label = "📓";
                }
                
                emoji_chooser.popup ();
            } else {
                color_revealer.reveal_child = true;
                emoji_color_stack.visible_child_name = "color";
            }
        })] = emoji_switch;
        
        signal_map[color_row.color_changed.connect (() => {
            Util.get_default ().set_widget_color (color_row.color, color_icon);
        })] = color_row;
        
        signal_map[emoji_picker_button.clicked.connect (() => {
            if (emoji_switch.active) {
                emoji_chooser.popup ();
            }
        })] = emoji_picker_button;
        
        // Initial state logic
        if (is_edit_mode) {
             // If we have an emoji that looks like a normal char, use emoji mode. 
             // Logic: If user was using color mode, maybe we stored a specific icon?
             // Since Notebook object only has 'icon', let's assume it's always an emoji/icon.
             // But valid "Color Mode" implies using a generic icon with the selected color.
             // We can simulate this: if emoji switch is OFF, we define icon as "📓" (generic) but rely on color.
             // For now, let's just respect the switch.
        }
    }
    
    public override void dispose () {
        foreach (var entry in signal_map.entries) {
            entry.value.disconnect (entry.key);
        }
        signal_map.clear ();
        base.dispose ();
    }

    private void create_notebook () {
        var new_notebook = new Objects.Notebook ();
        new_notebook.name = name_row.text;
        new_notebook.color = color_row.color;
        new_notebook.icon = emoji_switch.active ? emoji_label.label : "notebook-symbolic"; // Use symbolic icon for color mode
        Services.Store.instance ().insert_notebook (new_notebook);
    }

    private void update_notebook () {
        notebook.name = name_row.text;
        notebook.color = color_row.color;
        notebook.icon = emoji_switch.active ? emoji_label.label : "notebook-symbolic";
        notebook.update_modified_time ();
        Services.Database.get_default ().update_notebook (notebook);
        notebook.updated ();
    }
}
