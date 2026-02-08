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

public class Views.Notes.Notes : Adw.Bin {
    private Layouts.HeaderBar headerbar;
    private Gtk.Label title_label;
    private Gtk.Stack stack;
    private Gtk.ListBox listbox;
    private Gtk.FlowBox flowbox;
    private Gtk.ScrolledWindow scrolled_window;
    private Adw.StatusPage placeholder;

    private Objects.Notebook _notebook;
    private ulong notebook_updated_handler_id = 0;
    
    public Objects.Notebook notebook {
        get { return _notebook; }
        set {
            // Disconnect previous notebook's signal if any
            if (_notebook != null && notebook_updated_handler_id > 0) {
                _notebook.disconnect (notebook_updated_handler_id);
                notebook_updated_handler_id = 0;
            }
            
            _notebook = value;
            if (_notebook != null) {
                _filter_object = null; // Clear filter if notebook is set
                update_view ();
            
                // Subscribe to notebook.updated to sync title changes immediately
                notebook_updated_handler_id = _notebook.updated.connect (() => {
                    title_label.label = _notebook.name;
                    headerbar.title = _notebook.name;
                });
            } else if (_filter_object == null) {
                update_view ();
            }
        }
    }

    private Objects.BaseObject _filter_object;
    public Objects.BaseObject filter_object {
        get { return _filter_object; }
        set {
            _filter_object = value;
            if (_filter_object != null) {
                _notebook = null; // Clear notebook if filter is set
                update_view ();
            }
        }
    }

    private Gee.HashMap<string, Widgets.NoteRow> notes_hashmap = new Gee.HashMap<string, Widgets.NoteRow> ();
    private Gee.HashMap<string, Gtk.FlowBoxChild> flowbox_hashmap = new Gee.HashMap<string, Gtk.FlowBoxChild> ();
    private Gee.HashMap<string, Widgets.NoteRow> flowbox_row_hashmap = new Gee.HashMap<string, Widgets.NoteRow> ();
    
    // Track currently expanded note (only one can be expanded at a time)
    private Widgets.NoteRow? currently_expanded_list_row = null;
    private Widgets.NoteRow? currently_expanded_flow_row = null;


    private Gtk.SearchBar search_bar;
    private Gtk.SearchEntry search_entry;
    private string search_query = "";
    
    private enum SortBy {
        UPDATED_DESC,
        UPDATED_ASC,
        CREATED_DESC,
        CREATED_ASC,
        TITLE_ASC,
        TITLE_DESC
    }
    private SortBy current_sort = SortBy.UPDATED_DESC;

    construct {
        headerbar = new Layouts.HeaderBar ();
        
        var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
            tooltip_text = _("New Note")
        };
        add_button.add_css_class ("flat");
        headerbar.pack_start (add_button);

        add_button.clicked.connect (() => {
            string target_notebook_id = "";
            if (notebook != null) {
                target_notebook_id = notebook.id;
            } else {
                var default_nb = Services.Store.instance ().get_default_notebook ();
                if (default_nb != null) {
                    target_notebook_id = default_nb.id;
                } else if (Services.Store.instance ().notebooks.size > 0) {
                     target_notebook_id = Services.Store.instance ().notebooks[0].id;
                }
            }

            if (target_notebook_id != "") {
                var note = new Objects.Note ();
                note.notebook_id = target_notebook_id;
                note.title = _("Untitled Note");
                note.content = "";
                Services.Store.instance ().insert_note (note);
                open_note_editor (note); // Immediate open
            }
        });
        
        // Ctrl+N for new note
        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0 && keyval == Gdk.Key.n) {
                string target_notebook_id = "";
                if (notebook != null) {
                    target_notebook_id = notebook.id;
                } else {
                    var default_nb = Services.Store.instance ().get_default_notebook ();
                    if (default_nb != null) {
                        target_notebook_id = default_nb.id;
                    } else if (Services.Store.instance ().notebooks.size > 0) {
                        target_notebook_id = Services.Store.instance ().notebooks[0].id;
                    }
                }

                if (target_notebook_id != "") {
                    var note = new Objects.Note ();
                    note.notebook_id = target_notebook_id;
                    note.title = _("Untitled Note");
                    note.content = "";
                    Services.Store.instance ().insert_note (note);
                    open_note_editor (note);
                }
                return true;
            }
            return false;
        });
        add_controller (key_controller);

        // Search Button
        var search_button = new Gtk.ToggleButton () {
            icon_name = "system-search-symbolic",
            tooltip_text = _("Search Notes")
        };
        search_button.add_css_class ("flat");
        headerbar.pack_end (search_button);
        
        // Sort Button
        var sort_menu = new GLib.Menu ();
        var updated_section = new GLib.Menu ();
        updated_section.append (_("Updated (Newest First)"), "notes.sort_updated_desc");
        updated_section.append (_("Updated (Oldest First)"), "notes.sort_updated_asc");
        sort_menu.append_section (null, updated_section);
        
        var created_section = new GLib.Menu ();
        created_section.append (_("Created (Newest First)"), "notes.sort_created_desc");
        created_section.append (_("Created (Oldest First)"), "notes.sort_created_asc");
        sort_menu.append_section (null, created_section);
        
        var title_section = new GLib.Menu ();
        title_section.append (_("Title (A-Z)"), "notes.sort_title_asc");
        title_section.append (_("Title (Z-A)"), "notes.sort_title_desc");
        sort_menu.append_section (null, title_section);

        var sort_button = new Gtk.MenuButton () {
            icon_name = "view-sort-descending-symbolic",
            tooltip_text = _("Sort Notes"),
            menu_model = sort_menu
        };
        sort_button.add_css_class ("flat");
        headerbar.pack_end (sort_button);
        
        setup_sort_actions ();

        var view_mode_button = new Gtk.Button.from_icon_name ("view-grid-symbolic") {
            tooltip_text = _("Toggle List/Grid View")
        };
        view_mode_button.add_css_class ("flat");
        headerbar.pack_end (view_mode_button);
        view_mode_button.clicked.connect (() => {
            var mode = Services.Settings.get_default ().settings.get_string ("notes-view-mode");
            Services.Settings.get_default ().settings.set_string ("notes-view-mode", mode == "list" ? "grid" : "list");
        });

        title_label = new Gtk.Label ("") {
            halign = START,
            margin_start = 30,
            margin_top = 12
        };
        title_label.add_css_class ("font-bold");
        title_label.add_css_class ("title-2");

        listbox = new Gtk.ListBox () {
            margin_start = 30,
            margin_end = 30,
            margin_top = 12,
            margin_bottom = 12
        };
        listbox.add_css_class ("listbox-background");
        listbox.set_filter_func (filter_notes);
        listbox.set_sort_func (sort_notes);

        flowbox = new Gtk.FlowBox () {
            margin_start = 30,
            margin_end = 30,
            margin_top = 12,
            margin_bottom = 12,
            column_spacing = 12,
            row_spacing = 12,
            homogeneous = true,
            min_children_per_line = 1,
            max_children_per_line = 4
        };
        flowbox.set_filter_func (filter_flow_notes);
        flowbox.set_sort_func (sort_flow_notes);

        stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        stack.add_named (listbox, "list");
        stack.add_named (flowbox, "grid");

        placeholder = new Adw.StatusPage () {
            icon_name = "document-properties-symbolic",
            title = _("No Notes Found"),
            description = _("Create your first note in this notebook"),
            valign = CENTER,
            vexpand = true
        };
        
        var placeholder_button = new Gtk.Button.with_label (_("Create Note")) {
            halign = CENTER
        };
        placeholder_button.add_css_class ("pill");
        placeholder_button.add_css_class ("suggested-action");
        placeholder.child = placeholder_button;
        
        placeholder_button.clicked.connect (() => {
            if (notebook != null) {
                var note = new Objects.Note ();
                note.notebook_id = notebook.id;
                note.title = _("Untitled Note");
                note.content = "";
                Services.Store.instance ().insert_note (note);
                open_note_editor (note);
            }
        });

        var main_stack = new Gtk.Stack () {
            transition_type = CROSSFADE
        };
        main_stack.add_named (stack, "content");
        main_stack.add_named (placeholder, "placeholder");

        // Search Bar Setup
        search_bar = new Gtk.SearchBar ();
        search_entry = new Gtk.SearchEntry ();
        search_bar.child = search_entry;
        search_bar.connect_entry (search_entry);
        
        search_button.bind_property ("active", search_bar, "search-mode-enabled", GLib.BindingFlags.BIDIRECTIONAL);
        
        search_entry.search_changed.connect (() => {
            search_query = search_entry.text.strip ().down ();
            listbox.invalidate_filter ();
            flowbox.invalidate_filter ();
        });

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.append (title_label);
        content_box.append (main_stack);

        var clamp = new Adw.Clamp () {
            maximum_size = 864,
            child = content_box
        };

        scrolled_window = new Gtk.ScrolledWindow () {
            child = clamp,
            hscrollbar_policy = NEVER
        };

        var toolbar_view = new Adw.ToolbarView () {
            content = scrolled_window
        };
        toolbar_view.add_top_bar (headerbar);
        toolbar_view.add_top_bar (search_bar);

        child = toolbar_view;

        var settings = Services.Settings.get_default ().settings;
        ulong view_mode_id = settings.changed["notes-view-mode"].connect (update_view_mode);
        signal_map[view_mode_id] = settings;
        
        update_view_mode ();

        ulong note_added_id = Services.Store.instance ().note_added.connect ((note) => {
            if (notebook != null && note.notebook_id == notebook.id) {
                add_note (note);
            } else if (filter_object != null && matches_filter (note)) {
                add_note (note);
            }
        });
        signal_map[note_added_id] = Services.Store.instance ();

        ulong note_deleted_id = Services.Store.instance ().note_deleted.connect ((note) => {
            if (notes_hashmap.has_key (note.id)) {
                var row = notes_hashmap[note.id];
                // Reset expanded tracking if this was the expanded note
                if (currently_expanded_list_row == row) {
                    currently_expanded_list_row = null;
                }
                if (row != null && row.get_parent () == listbox) {
                    listbox.remove (row);
                }
                notes_hashmap.unset (note.id);
            }
            if (flowbox_hashmap.has_key (note.id)) {
                var flow_child = flowbox_hashmap[note.id];
                if (flow_child != null && flow_child.get_parent () == flowbox) {
                    flowbox.remove (flow_child);
                }
                flowbox_hashmap.unset (note.id);
            }
            if (flowbox_row_hashmap.has_key (note.id)) {
                var flow_row = flowbox_row_hashmap[note.id];
                // Reset expanded tracking if this was the expanded note
                if (currently_expanded_flow_row == flow_row) {
                    currently_expanded_flow_row = null;
                }
                flowbox_row_hashmap.unset (note.id);
            }
            check_placeholder ();
        });
        signal_map[note_deleted_id] = Services.Store.instance ();
        
        ulong notebook_deleted_id = Services.Store.instance ().notebook_deleted.connect ((deleted_notebook) => {
            if (notebook != null && deleted_notebook.id == notebook.id) {
                // Current notebook was deleted
                notebook = null; // This will clear the view
                
                // Defer notebook switching to avoid race conditions during deletion
                Idle.add (() => {
                    // Try to find another notebook to switch to
                    var notebooks = Services.Store.instance ().notebooks;
                    if (notebooks.size > 0) {
                        notebook = notebooks[0];
                    }
                    return Source.REMOVE;
                });
            }
        });
        signal_map[notebook_deleted_id] = Services.Store.instance ();
        
        // Handle notebook archive - navigate away from archived notebook
        ulong notebook_archived_id = Services.Store.instance ().notebook_updated.connect ((updated_notebook) => {
            if (notebook != null && updated_notebook.id == notebook.id && updated_notebook.is_archived) {
                // Current notebook was archived - find another notebook to show
                Idle.add (() => {
                    var notebooks = Services.Store.instance ().notebooks;
                    foreach (var nb in notebooks) {
                        if (!nb.is_archived) {
                            // Navigate to this non-archived notebook
                            Services.EventBus.get_default ().pane_selected (PaneType.NOTEBOOK, nb.id);
                            return Source.REMOVE;
                        }
                    }
                    // No notebooks available, go to inbox
                    Services.EventBus.get_default ().pane_selected (PaneType.FILTER, Objects.Filters.Inbox.get_default ().view_id);
                    return Source.REMOVE;
                });
            }
        });
        signal_map[notebook_archived_id] = Services.Store.instance ();
        
        destroy.connect (clean_up);
    }
    
    private Gee.HashMap<ulong, Object> signal_map = new Gee.HashMap<ulong, Object> ();
    
    private void clean_up () {
        foreach (var entry in signal_map.entries) {
            entry.value.disconnect (entry.key);
        }
        signal_map.clear ();
    }

    private void setup_sort_actions () {
        var action_group = new SimpleActionGroup ();
        
        var action_updated_desc = new SimpleAction ("sort_updated_desc", null);
        action_updated_desc.activate.connect (() => { current_sort = SortBy.UPDATED_DESC; invalidate_sort (); });
        action_group.add_action (action_updated_desc);

        var action_updated_asc = new SimpleAction ("sort_updated_asc", null);
        action_updated_asc.activate.connect (() => { current_sort = SortBy.UPDATED_ASC; invalidate_sort (); });
        action_group.add_action (action_updated_asc);
        
        var action_created_desc = new SimpleAction ("sort_created_desc", null);
        action_created_desc.activate.connect (() => { current_sort = SortBy.CREATED_DESC; invalidate_sort (); });
        action_group.add_action (action_created_desc);
        
        var action_created_asc = new SimpleAction ("sort_created_asc", null);
        action_created_asc.activate.connect (() => { current_sort = SortBy.CREATED_ASC; invalidate_sort (); });
        action_group.add_action (action_created_asc);
        
        var action_title_asc = new SimpleAction ("sort_title_asc", null);
        action_title_asc.activate.connect (() => { current_sort = SortBy.TITLE_ASC; invalidate_sort (); });
        action_group.add_action (action_title_asc);
        
        var action_title_desc = new SimpleAction ("sort_title_desc", null);
        action_title_desc.activate.connect (() => { current_sort = SortBy.TITLE_DESC; invalidate_sort (); });
        action_group.add_action (action_title_desc);
        
        insert_action_group ("notes", action_group);
    }
    
    private void invalidate_sort () {
        listbox.invalidate_sort ();
        flowbox.invalidate_sort ();
    }

    private bool filter_notes (Gtk.ListBoxRow row) {
        if (search_query == "") return true;
        var note_row = row as Widgets.NoteRow;
        return note_row.note.title.down ().contains (search_query) || note_row.note.content.down ().contains (search_query);
    }
    
    private bool filter_flow_notes (Gtk.FlowBoxChild child) {
        if (search_query == "") return true;
        var row = child.child as Widgets.NoteRow;
        return row.note.title.down ().contains (search_query) || row.note.content.down ().contains (search_query);
    }
    
    private int sort_notes (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var note1 = ((Widgets.NoteRow) row1).note;
        var note2 = ((Widgets.NoteRow) row2).note;
        return compare_notes (note1, note2);
    }
    
    private int sort_flow_notes (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
        var note1 = ((Widgets.NoteRow) child1.child).note;
        var note2 = ((Widgets.NoteRow) child2.child).note;
        return compare_notes (note1, note2);
    }
    
    private int compare_notes (Objects.Note note1, Objects.Note note2) {
        switch (current_sort) {
            case SortBy.UPDATED_DESC:
                return note2.updated_at.collate (note1.updated_at);
            case SortBy.UPDATED_ASC:
                return note1.updated_at.collate (note2.updated_at);
            case SortBy.CREATED_DESC:
                return note2.created_at.collate (note1.created_at);
            case SortBy.CREATED_ASC:
                return note1.created_at.collate (note2.created_at);
            case SortBy.TITLE_ASC:
                return note1.title.collate (note2.title);
            case SortBy.TITLE_DESC:
                return note2.title.collate (note1.title);
            default:
                return 0;
        }
    }

    private void update_view_mode () {
        var mode = Services.Settings.get_default ().settings.get_string ("notes-view-mode");
        stack.visible_child_name = mode;
    }

    private void update_view () {
        if (notebook == null && filter_object == null) return;

        string title = "";
        Gee.ArrayList<Objects.Note> notes = new Gee.ArrayList<Objects.Note> ();

        if (notebook != null) {
            title = notebook.name;
            notes = Services.Store.instance ().get_notes_by_notebook (notebook.id);
        } else if (filter_object != null) {
            title = filter_object.name;
            if (filter_object is Objects.Filters.NotesInbox) {
                 notes = Services.Store.instance ().get_notes_inbox ();
            } else if (filter_object is Objects.Filters.NotesToday) {
                 notes = Services.Store.instance ().get_notes_today ();
            } else if (filter_object is Objects.Filters.NotesPinboard) {
                 notes = Services.Store.instance ().get_notes_pinned ();
            } else if (filter_object is Objects.Filters.NotesArchived) { // Completed
                 notes = Services.Store.instance ().get_notes_archived ();
            } else if (filter_object is Objects.Filters.AllNotes) {
                 notes = Services.Store.instance ().get_all_notes ();
            } else if (filter_object is Objects.Filters.NotesLabels) {
                 // For labels overview, show notes with labels?
                 notes = Services.Store.instance ().get_notes_with_labels ();
            } else if (filter_object is Objects.Filters.Notes) {
                 notes = Services.Store.instance ().get_all_notes (); 
            }
        }

        title_label.label = title;
        headerbar.title = title;

        // Clear existing
        foreach (var row in notes_hashmap.values) {
            listbox.remove (row);
        }
        foreach (var flow_child in flowbox_hashmap.values) {
            flowbox.remove (flow_child);
        }
        notes_hashmap.clear ();
        flowbox_hashmap.clear ();
        flowbox_row_hashmap.clear ();
        
        // Reset expanded note tracking
        currently_expanded_list_row = null;
        currently_expanded_flow_row = null;

        foreach (var note in notes) {
            add_note (note);
        }

        check_placeholder ();
    }

    private bool matches_filter (Objects.Note note) {
        if (filter_object == null) return false;
        
        if (filter_object is Objects.Filters.NotesInbox) {
             var default_nb = Services.Store.instance ().get_default_notebook ();
             return default_nb != null && note.notebook_id == default_nb.id;
        } else if (filter_object is Objects.Filters.NotesToday) {
             var updated = Utils.Datetime.get_date_from_string (note.updated_at);
             return Utils.Datetime.is_same_day (updated, new GLib.DateTime.now_local ());
        } else if (filter_object is Objects.Filters.NotesPinboard) {
             return note.is_pinned;
        } else if (filter_object is Objects.Filters.NotesArchived) {
             return note.is_archived;
        } else if (filter_object is Objects.Filters.AllNotes || filter_object is Objects.Filters.Notes) {
             return !note.is_archived && !note.is_deleted;
        } else if (filter_object is Objects.Filters.NotesLabels) {
             return note.labels.size > 0;
        }
        return false;
    }

    private void add_note (Objects.Note note) {
        var row = new Widgets.NoteRow (note);
        notes_hashmap[note.id] = row;
        listbox.append (row);
        
        // Also add to flowbox for grid view (needs separate instance)
        var flow_row = new Widgets.NoteRow (note);
        var flow_child = new Gtk.FlowBoxChild ();
        flow_child.child = flow_row;
        flowbox_hashmap[note.id] = flow_child;
        flowbox_row_hashmap[note.id] = flow_row;
        flowbox.append (flow_child);
        
        row.activate.connect (() => {
            open_note_editor (note);
        });
        
        row.edit_requested.connect (() => {
            open_note_editor (note);
        });
        
        // Handle expansion for list view - only one note can be expanded at a time
        row.expansion_changed.connect ((is_expanded) => {
            if (is_expanded) {
                // Collapse previously expanded note if different
                if (currently_expanded_list_row != null && currently_expanded_list_row != row) {
                    currently_expanded_list_row.collapse ();
                }
                currently_expanded_list_row = row;
            } else {
                if (currently_expanded_list_row == row) {
                    currently_expanded_list_row = null;
                }
            }
        });
        
        flow_row.activate.connect (() => {
            open_note_editor (note);
        });
        
        flow_row.edit_requested.connect (() => {
            open_note_editor (note);
        });
        
        // Handle expansion for grid view - only one note can be expanded at a time
        flow_row.expansion_changed.connect ((is_expanded) => {
            if (is_expanded) {
                // Collapse previously expanded note if different
                if (currently_expanded_flow_row != null && currently_expanded_flow_row != flow_row) {
                    currently_expanded_flow_row.collapse ();
                }
                currently_expanded_flow_row = flow_row;
            } else {
                if (currently_expanded_flow_row == flow_row) {
                    currently_expanded_flow_row = null;
                }
            }
        });

        check_placeholder ();
    }
    
    private void open_note_editor (Objects.Note note) {
        var dialog = new Dialogs.NoteEditorDialog (note);
        dialog.transient_for = (Gtk.Window) get_root ();
        dialog.present ();
    }

    private void check_placeholder () {
        var main_stack = (Gtk.Stack) stack.get_parent ();
        if (notes_hashmap.size == 0) {
            main_stack.visible_child_name = "placeholder";
        } else {
            main_stack.visible_child_name = "content";
        }
    }
}
