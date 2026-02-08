/*
 * Copyright © 2026 Planote Contributors
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

public class Objects.Notebook : Objects.BaseObject {
    // Core Fields
    public new string name { get; set; default = ""; }
    public string description { get; set; default = ""; }
    
    // Appearance
    public new string color { get; set; default = "blue"; }
    public string icon { get; set; default = "📓"; }
    
    // Organization
    public int child_order { get; set; default = 0; }
    public bool is_default { get; set; default = false; }
    public bool is_archived { get; set; default = false; }
    public bool is_deleted { get; set; default = false; }
    public bool is_favorite { get; set; default = false; }
    
    // Sync & Backend
    public string source_id { get; set; default = "local"; }
    public string backend_type { get; set; default = "local"; }
    
    // Metadata
    public string created_at { get; set; default = ""; }
    public string updated_at { get; set; default = ""; }
    
    // Collections
    private Gee.ArrayList<Objects.Note> _notes;
    public Gee.ArrayList<Objects.Note> notes {
        get {
            if (_notes == null) {
                var db = Services.Database.get_default ();
                if (db != null) {
                    _notes = db.get_notes_by_notebook (id);
                } else {
                    _notes = new Gee.ArrayList<Objects.Note> ();
                }
            }
            return _notes;
        }
    }
    
    // Computed Properties
    public int note_count {
        get {
            return notes.size;
        }
    }
    
    public int active_note_count {
        get {
            int count = 0;
            foreach (var note in notes) {
                if (!note.is_archived && !note.is_deleted) {
                    count++;
                }
            }
            return count;
        }
    }
    
    public string display_name {
        owned get {
            return "%s %s".printf (icon, name);
        }
    }
    
    public string last_modified_display {
        owned get {
            return Utils.Datetime.get_relative_date_from_string (updated_at);
        }
    }
    
    // Signals
    public signal void deleted_notebook ();
    public signal void note_added (Objects.Note note);
    public signal void note_removed (Objects.Note note);
    
    public Notebook () {
        id = Util.get_default ().generate_id ();
        created_at = new GLib.DateTime.now_local ().to_string ();
        updated_at = created_at;
    }
    
    public Notebook.with_name (string notebook_name) {
        this ();
        name = notebook_name;
    }
    
    public Notebook.default_notebook () {
        this ();
        name = _("Default Notebook");
        icon = "📘";
        color = "blue";
        is_default = true;
    }

    public Notebook.from_import_json (Json.Node node) {
        var obj = node.get_object ();

        id = obj.get_string_member ("id");
        name = obj.get_string_member ("name");
        description = obj.has_member ("description") ? obj.get_string_member ("description") : "";
        color = obj.has_member ("color") ? obj.get_string_member ("color") : "blue";
        icon = obj.has_member ("icon") ? obj.get_string_member ("icon") : "📓";
        child_order = obj.has_member ("child_order") ? (int) obj.get_int_member ("child_order") : 0;
        is_default = obj.has_member ("is_default") ? obj.get_boolean_member ("is_default") : false;
        is_archived = obj.has_member ("is_archived") ? obj.get_boolean_member ("is_archived") : false;
        is_deleted = obj.has_member ("is_deleted") ? obj.get_boolean_member ("is_deleted") : false;
        is_favorite = obj.has_member ("is_favorite") ? obj.get_boolean_member ("is_favorite") : false;
        source_id = obj.has_member ("source_id") ? obj.get_string_member ("source_id") : "local";
        created_at = obj.has_member ("created_at") ? obj.get_string_member ("created_at") : new GLib.DateTime.now_local ().to_string ();
        updated_at = obj.has_member ("updated_at") ? obj.get_string_member ("updated_at") : new GLib.DateTime.now_local ().to_string ();
    }
    
    public void add_note (Objects.Note note) {
        note.notebook_id = id;
        // Use notes property getter to ensure _notes is initialized
        notes.add (note);
        update_modified_time ();
        note_added (note);
        updated ();
    }
    
    public void remove_note (Objects.Note note) {
        // Use notes property getter to ensure _notes is initialized
        notes.remove (note);
        note.notebook_id = "";
        update_modified_time ();
        note_removed (note);
        updated ();
    }
    
    public void update_modified_time () {
        updated_at = new GLib.DateTime.now_local ().to_string ();
    }
    
    public void archive () {
        is_archived = true;
        updated ();
        Services.Database.get_default ().update_notebook (this);
        Services.Store.instance ().notebook_updated (this);
    }
    
    public void unarchive () {
        is_archived = false;
        updated ();
        Services.Database.get_default ().update_notebook (this);
        Services.Store.instance ().notebook_updated (this);
    }
    
    public Gee.ArrayList<Objects.Note> get_pinned_notes () {
        var pinned = new Gee.ArrayList<Objects.Note> ();
        foreach (var note in notes) {
            if (note.is_pinned && !note.is_archived && !note.is_deleted) {
                pinned.add (note);
            }
        }
        return pinned;
    }
    
    public Gee.ArrayList<Objects.Note> get_favorite_notes () {
        var favorites = new Gee.ArrayList<Objects.Note> ();
        foreach (var note in notes) {
            if (note.is_favorite && !note.is_archived && !note.is_deleted) {
                favorites.add (note);
            }
        }
        return favorites;
    }
    
    public Gee.ArrayList<Objects.Note> get_recent_notes (int limit = 10) {
        var recent = new Gee.ArrayList<Objects.Note> ();
        
        // Sort by updated_at descending
        var sorted_notes = new Gee.ArrayList<Objects.Note> ();
        foreach (var note in notes) {
            if (!note.is_archived && !note.is_deleted) {
                sorted_notes.add (note);
            }
        }
        
        sorted_notes.sort ((a, b) => {
            return b.updated_at.collate (a.updated_at);
        });
        
        for (int i = 0; i < int.min (limit, sorted_notes.size); i++) {
            recent.add (sorted_notes[i]);
        }
        
        return recent;
    }
    
    public int get_total_word_count () {
        int total = 0;
        foreach (var note in notes) {
            if (!note.is_archived && !note.is_deleted) {
                total += note.word_count;
            }
        }
        return total;
    }
    
    public void print_debug () {
        print ("\n=== Notebook Debug Info ===\n");
        print ("ID: %s\n", id);
        print ("Name: %s\n", name);
        print ("Icon: %s\n", icon);
        print ("Color: %s\n", color);
        print ("Created: %s\n", created_at);
        print ("Updated: %s\n", updated_at);
        print ("Total Notes: %d\n", note_count);
        print ("Active Notes: %d\n", active_note_count);
        print ("Is Default: %s\n", is_default.to_string ());
        print ("Is Archived: %s\n", is_archived.to_string ());
        print ("===========================\n\n");
    }
}
