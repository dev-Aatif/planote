/*
 * Copyright © 2024 Planote Contributors
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

public class Dialogs.ManageArchive : Adw.Dialog {
    private Gtk.ListBox projects_listbox;
    private Gtk.ListBox notebooks_listbox;
    private Gtk.Stack projects_stack;
    private Gtk.Stack notebooks_stack;
    private Gee.HashMap<ulong, GLib.Object> signal_map = new Gee.HashMap<ulong, GLib.Object> ();

    public ManageArchive () {
        Object (
            title: _("Archive"),
            content_width: 400,
            content_height: 500
        );
    }

    ~ManageArchive () {
        debug ("Destroying - Dialogs.ManageArchive\n");
    }

    construct {
        var headerbar = new Adw.HeaderBar ();
        headerbar.add_css_class ("flat");

        // Stack switcher
        var stack_switcher = new Adw.ViewSwitcher () {
            policy = WIDE
        };

        // Create stack pages using Adw.ViewStack
        var view_stack = new Adw.ViewStack ();

        // Projects page with placeholder
        projects_listbox = new Gtk.ListBox () {
            hexpand = true,
            valign = START,
            css_classes = { "listbox-background" }
        };

        var projects_card = new Adw.Bin () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 6,
            margin_top = 12,
            css_classes = { "card" },
            child = projects_listbox,
            valign = START
        };

        var projects_placeholder = new Adw.StatusPage () {
            icon_name = "folder-symbolic",
            title = _("No Archived Projects"),
            description = _("Projects you archive will appear here"),
            vexpand = true
        };
        projects_placeholder.add_css_class ("compact");

        projects_stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        projects_stack.add_named (new Widgets.ScrolledWindow (projects_card), "content");
        projects_stack.add_named (projects_placeholder, "placeholder");
        
        view_stack.add_titled_with_icon (projects_stack, "projects", _("Projects"), "folder-symbolic");

        // Notebooks page with placeholder
        notebooks_listbox = new Gtk.ListBox () {
            hexpand = true,
            valign = START,
            css_classes = { "listbox-background" }
        };

        var notebooks_card = new Adw.Bin () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 6,
            margin_top = 12,
            css_classes = { "card" },
            child = notebooks_listbox,
            valign = START
        };

        var notebooks_placeholder = new Adw.StatusPage () {
            icon_name = "notebook-symbolic",
            title = _("No Archived Notebooks"),
            description = _("Notebooks you archive will appear here. Notes inside archived notebooks are preserved."),
            vexpand = true
        };
        notebooks_placeholder.add_css_class ("compact");

        notebooks_stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        notebooks_stack.add_named (new Widgets.ScrolledWindow (notebooks_card), "content");
        notebooks_stack.add_named (notebooks_placeholder, "placeholder");
        
        view_stack.add_titled_with_icon (notebooks_stack, "notebooks", _("Notebooks"), "notebook-symbolic");

        stack_switcher.stack = view_stack;
        headerbar.set_title_widget (stack_switcher);

        var toolbar_view = new Adw.ToolbarView ();
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.content = view_stack;

        child = toolbar_view;
        Services.EventBus.get_default ().disconnect_typing_accel ();

        // Populate archived projects
        foreach (Objects.Project project in Services.Store.instance ().get_all_projects_archived ()) {
            if (project.is_archived) {
                projects_listbox.append (new Widgets.ProjectItemRow (project, "menu"));
            }
        }

        // Populate archived notebooks
        foreach (Objects.Notebook notebook in Services.Store.instance ().notebooks) {
            if (notebook.is_archived) {
                notebooks_listbox.append (create_notebook_row (notebook));
            }
        }

        // Show placeholders if empty
        update_placeholders ();

        signal_map[Services.Store.instance ().project_unarchived.connect (() => {
            update_placeholders ();
        })] = Services.Store.instance ();

        signal_map[Services.Store.instance ().notebook_updated.connect ((notebook) => {
            update_placeholders ();
        })] = Services.Store.instance ();

        closed.connect (() => {
            clean_up ();
            Services.EventBus.get_default ().connect_typing_accel ();
        });
    }

    private Gtk.Widget create_notebook_row (Objects.Notebook notebook) {
        var row = new Adw.ActionRow () {
            title = notebook.name,
            subtitle = notebook.description.length > 0 ? notebook.description : _("%d notes").printf ((int) notebook.notes.size),
            activatable = true
        };

        var icon_label = new Gtk.Label (notebook.icon) {
            css_classes = { "dim-label" }
        };
        row.add_prefix (icon_label);

        var unarchive_button = new Gtk.Button.from_icon_name ("view-restore-symbolic") {
            valign = CENTER,
            css_classes = { "flat", "circular" },
            tooltip_text = _("Unarchive")
        };

        unarchive_button.clicked.connect (() => {
            notebook.unarchive ();
            row.unparent ();
            update_placeholders ();

            Services.EventBus.get_default ().send_toast (
                Util.get_default ().create_toast (_("Notebook unarchived"))
            );
        });

        var delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
            valign = CENTER,
            css_classes = { "flat", "circular" },
            tooltip_text = _("Delete permanently")
        };

        delete_button.clicked.connect (() => {
            Services.Store.instance ().delete_notebook (notebook);
            row.unparent ();
            update_placeholders ();
        });

        row.add_suffix (unarchive_button);
        row.add_suffix (delete_button);

        return row;
    }

    private void update_placeholders () {
        // Show placeholder or content for each tab
        bool has_projects = Util.get_default ().get_children (projects_listbox).length () > 0;
        bool has_notebooks = Util.get_default ().get_children (notebooks_listbox).length () > 0;

        projects_stack.visible_child_name = has_projects ? "content" : "placeholder";
        notebooks_stack.visible_child_name = has_notebooks ? "content" : "placeholder";
    }

    public void clean_up () {
        foreach (var entry in signal_map.entries) {
            entry.value.disconnect (entry.key);
        }

        signal_map.clear ();

        foreach (unowned Gtk.Widget child in Util.get_default ().get_children (projects_listbox)) {
            ((Widgets.ProjectItemRow) child).clean_up ();
        }
    }

    public override void dispose () {
        clean_up ();
        base.dispose ();
    }
}
