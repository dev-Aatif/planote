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

public class Layouts.NotebookRow : Gtk.ListBoxRow {
    public Objects.Notebook notebook { get; construct; }

    private Gtk.Image icon_image;
    private Gtk.Label emoji_label;
    private Gtk.Stack icon_stack;
    private Gtk.Label name_label;
    public Gtk.Box handle_grid;
    private Gtk.Popover? menu_popover = null;
    private Gee.HashMap<ulong, GLib.Object> signals_map = new Gee.HashMap<ulong, GLib.Object> ();

    public NotebookRow (Objects.Notebook notebook) {
        Object (notebook: notebook);
    }

    construct {
        css_classes = { "row", "transition", "no-padding" };

        icon_stack = new Gtk.Stack ();
        
        icon_image = new Gtk.Image.from_icon_name ("notebook-symbolic") {
            pixel_size = 22,
            css_classes = { "view-icon" }
        };
        
        emoji_label = new Gtk.Label ("") {
            css_classes = { "emoji-icon" } 
        };
        
        icon_stack.add_named (icon_image, "icon");
        icon_stack.add_named (emoji_label, "emoji");
        
        update_request ();

        name_label = new Gtk.Label (notebook.name) {
            valign = Gtk.Align.CENTER,
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            halign = Gtk.Align.START,
        };

        var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_end = 3,
            margin_start = 3,
            margin_top = 3,
            margin_bottom = 3
        };

        row_box.append (icon_stack);
        row_box.append (name_label);

        handle_grid = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            css_classes = { "transition", "selectable-item" }
        };
        handle_grid.append (row_box);

        child = handle_grid;

        var select_gesture = new Gtk.GestureClick ();
        handle_grid.add_controller (select_gesture);
        signals_map[select_gesture.released.connect (() => {
            Services.EventBus.get_default ().pane_selected (PaneType.NOTEBOOK, notebook.id);
        })] = select_gesture;

        // Right-click context menu
        var menu_gesture = new Gtk.GestureClick () {
            button = 3
        };
        handle_grid.add_controller (menu_gesture);
        signals_map[menu_gesture.pressed.connect ((n_press, x, y) => {
            build_context_menu (x, y);
        })] = menu_gesture;

        signals_map[Services.EventBus.get_default ().pane_selected.connect ((pane_type, id) => {
            if (pane_type == PaneType.NOTEBOOK && notebook.id == id) {
                handle_grid.add_css_class ("selected");
            } else {
                handle_grid.remove_css_class ("selected");
            }
        })] = Services.EventBus.get_default ();

        signals_map[notebook.updated.connect (update_request)] = notebook;

        destroy.connect (() => {
            // Clean up popover first to avoid GTK warnings
            if (menu_popover != null) {
                menu_popover.unparent ();
                menu_popover = null;
            }
            
            foreach (var entry in signals_map.entries) {
                entry.value.disconnect (entry.key);
            }
            signals_map.clear ();
        });
    }

    private void update_request () {
        name_label.label = notebook.name;
        
        if (notebook.icon == "notebook-symbolic" || notebook.icon == "document-properties-symbolic") {
            icon_stack.visible_child_name = "icon";
            icon_image.icon_name = "notebook-symbolic";
            if (notebook.color != "") {
                Util.get_default ().set_widget_color (notebook.color, icon_image);
            }
        } else {
            icon_stack.visible_child_name = "emoji";
            // Check if icon is empty, default to notebook-symbolic just in case
            if (notebook.icon == "") {
                 icon_stack.visible_child_name = "icon";
                 icon_image.icon_name = "notebook-symbolic";
            } else {
                 emoji_label.label = notebook.icon;
            }
        }
    }

    private void build_context_menu (double x, double y) {
        if (menu_popover != null) {
            menu_popover.pointing_to = { ((int) x), (int) y, 1, 1 };
            menu_popover.popup ();
            return;
        }

        var edit_item = new Widgets.ContextMenu.MenuItem (_("Edit Notebook"), "edit-symbolic");
        
        var favorite_item = new Widgets.ContextMenu.MenuItem (
            notebook.is_favorite ? _("Remove from Favorites") : _("Add to Favorites"),
            notebook.is_favorite ? "star-filled-symbolic" : "star-outline-large-symbolic"
        );
        
        var duplicate_item = new Widgets.ContextMenu.MenuItem (_("Duplicate"), "tabs-stack-symbolic");
        var archive_item = new Widgets.ContextMenu.MenuItem (_("Archive"), "shoe-box-symbolic");
        var delete_item = new Widgets.ContextMenu.MenuItem (_("Delete Notebook"), "user-trash-symbolic");
        delete_item.add_css_class ("menu-item-danger");

        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_box.margin_top = menu_box.margin_bottom = 3;
        menu_box.append (edit_item);
        menu_box.append (favorite_item);
        menu_box.append (duplicate_item);

        menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
        menu_box.append (archive_item);
        menu_box.append (delete_item);

        menu_popover = new Gtk.Popover () {
            has_arrow = false,
            halign = Gtk.Align.START,
            child = menu_box,
            width_request = 250
        };

        menu_popover.set_parent (this);
        menu_popover.pointing_to = { ((int) x), (int) y, 1, 1 };
        menu_popover.popup ();

        edit_item.clicked.connect (() => {
            menu_popover.popdown ();
            var dialog = new Dialogs.NotebookDialog.edit (notebook);
            dialog.transient_for = Planote._instance.main_window;
            dialog.present ();
        });

        favorite_item.clicked.connect (() => {
            menu_popover.popdown ();
            notebook.is_favorite = !notebook.is_favorite;
            notebook.update_modified_time ();
            Services.Database.get_default ().update_notebook (notebook);
            Services.Store.instance ().notebook_updated (notebook);
            Services.EventBus.get_default ().notebook_favorite_toggled (notebook);
            
            // Reset the popover so it rebuilds with updated favorite status next time
            menu_popover.unparent ();
            menu_popover = null;
        });

        duplicate_item.clicked.connect (() => {
            menu_popover.popdown ();
            duplicate_notebook ();
        });

        archive_item.clicked.connect (() => {
            menu_popover.popdown ();
            notebook.archive ();
            // The sidebar's notebook_updated handler will remove this row
        });

        delete_item.clicked.connect (() => {
            menu_popover.popdown ();
            delete_notebook ();
        });
    }

    private void duplicate_notebook () {
        var new_notebook = new Objects.Notebook ();
        new_notebook.name = notebook.name + " " + _("(Copy)");
        new_notebook.icon = notebook.icon;
        new_notebook.color = notebook.color;
        new_notebook.description = notebook.description;

        Services.Store.instance ().insert_notebook (new_notebook);

        // Duplicate notes
        foreach (var note in notebook.notes) {
            var new_note = new Objects.Note ();
            new_note.notebook_id = new_notebook.id;
            new_note.title = note.title;
            new_note.content = note.content;
            new_note.color = note.color;

            Services.Store.instance ().insert_note (new_note);
        }

        Services.EventBus.get_default ().send_toast (
            Util.get_default ().create_toast (_("Notebook duplicated successfully"))
        );
    }

    private void delete_notebook () {
        var dialog = new Adw.AlertDialog (
            _("Delete Notebook?"),
            _("This will permanently delete \"%s\" and all its notes. This action cannot be undone.").printf (notebook.name)
        );

        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("delete", _("Delete"));
        dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.default_response = "cancel";

        dialog.response.connect ((response) => {
            if (response == "delete") {
                // Capture notebook reference before any cleanup
                var notebook_to_delete = notebook;
                
                // Clean up this row immediately
                hide_destroy ();
                
                // Defer the actual deletion to avoid focus issues
                Idle.add (() => {
                    Services.Store.instance ().delete_notebook (notebook_to_delete);
                    return Source.REMOVE;
                });
            }
        });

        dialog.present (Planote._instance.main_window);
    }

    public void hide_destroy () {
        // Clean up popover first
        if (menu_popover != null) {
            menu_popover.unparent ();
            menu_popover = null;
        }

        // Disconnect all signals to prevent crashes
        foreach (var entry in signals_map.entries) {
            entry.value.disconnect (entry.key);
        }
        signals_map.clear ();
        
        // Handle different parent types
        var parent_listbox = parent as Gtk.ListBox;
        if (parent_listbox != null) {
            parent_listbox.remove (this);
            return;
        }
        
        // Fallback: try to unparent from any parent
        if (parent != null) {
            unparent ();
        }
    }
}
