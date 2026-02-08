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

public class Objects.Note : Objects.BaseObject {
    // Core Fields
    public string title { get; set; default = ""; }
    public string content { get; set; default = ""; }
    
    // Organization
    public string notebook_id { get; set; default = ""; }
    public string folder_id { get; set; default = ""; }
    
    // Metadata
    public string created_at { get; set; default = ""; }
    public string updated_at { get; set; default = ""; }
    public string accessed_at { get; set; default = ""; }
    public bool is_pinned { get; set; default = false; }
    public bool is_archived { get; set; default = false; }
    public bool is_favorite { get; set; default = false; }
    public bool is_deleted { get; set; default = false; }
    
    // Rich Content
    public string format_type { get; set; default = "markdown"; } // markdown, html, plain
    public bool has_checklist { get; set; default = false; }
    public new string color { get; set; default = ""; }
    
    // Sync & Backend
    public string source_id { get; set; default = "local"; }
    public string backend_type { get; set; default = "local"; }
    public string extra_data { get; set; default = ""; }
    
    // Search
    public string search_index { get; set; default = ""; }
    
    // Relationships (stored as JSON arrays)
    public string tags { get; set; default = ""; } // JSON array of tag IDs
    public string linked_items { get; set; default = ""; } // JSON array of item IDs
    
    // Collections (not persisted directly)
    private Gee.ArrayList<Objects.Label> _labels;
    public Gee.ArrayList<Objects.Label> labels {
        get {
            if (_labels == null) {
                _labels = new Gee.ArrayList<Objects.Label> ();
                load_labels ();
            }
            return _labels;
        }
    }
    
    private Gee.ArrayList<Objects.Attachment> _attachments;
    public Gee.ArrayList<Objects.Attachment> attachments {
        get {
            if (_attachments == null) {
                _attachments = new Gee.ArrayList<Objects.Attachment> ();
                load_attachments ();
            }
            return _attachments;
        }
    }
    
    Objects.Notebook? _notebook;
    public Objects.Notebook? notebook {
        get {
            if (_notebook == null && notebook_id != "") {
                _notebook = Services.Store.instance ().get_notebook (notebook_id);
            }
            return _notebook;
        }
        set {
            _notebook = value;
            if (value != null) {
                notebook_id = value.id;
            }
        }
    }
    
    // Computed Properties
    public string display_date {
        owned get {
            return Utils.Datetime.get_relative_date_from_string (updated_at);
        }
    }
    
    public int word_count {
        get {
            if (content == "") {
                return 0;
            }
            
            string[] words = content.strip ().split_set (" \t\n\r");
            int count = 0;
            foreach (string word in words) {
                if (word.strip ().length > 0) {
                    count++;
                }
            }
            return count;
        }
    }
    
    public int character_count {
        get {
            return content.length;
        }
    }
    
    public int reading_time_minutes {
        get {
            // Average reading speed: 200 words per minute
            return (word_count / 200) + 1;
        }
    }
    
    // Signals
    public signal void deleted_note ();
    public signal void attachment_added (Objects.Attachment attachment);
    public signal void attachment_deleted (Objects.Attachment attachment);
    
    public Note () {
        id = Util.get_default ().generate_id ();
        created_at = new GLib.DateTime.now_local ().to_string ();
        updated_at = created_at;
        accessed_at = created_at;
    }
    
    public Note.from_import (string import_title, string import_content) {
        this ();
        title = import_title;
        content = import_content;
        update_search_index ();
    }

    public Note.from_import_json (Json.Node node) {
        var obj = node.get_object ();

        id = obj.get_string_member ("id");
        title = obj.has_member ("title") ? obj.get_string_member ("title") : "";
        content = obj.has_member ("content") ? obj.get_string_member ("content") : "";
        notebook_id = obj.has_member ("notebook_id") ? obj.get_string_member ("notebook_id") : "";
        folder_id = obj.has_member ("folder_id") ? obj.get_string_member ("folder_id") : "";
        created_at = obj.has_member ("created_at") ? obj.get_string_member ("created_at") : new GLib.DateTime.now_local ().to_string ();
        updated_at = obj.has_member ("updated_at") ? obj.get_string_member ("updated_at") : new GLib.DateTime.now_local ().to_string ();
        accessed_at = obj.has_member ("accessed_at") ? obj.get_string_member ("accessed_at") : new GLib.DateTime.now_local ().to_string ();
        is_pinned = obj.has_member ("is_pinned") ? obj.get_boolean_member ("is_pinned") : false;
        is_archived = obj.has_member ("is_archived") ? obj.get_boolean_member ("is_archived") : false;
        is_favorite = obj.has_member ("is_favorite") ? obj.get_boolean_member ("is_favorite") : false;
        is_deleted = obj.has_member ("is_deleted") ? obj.get_boolean_member ("is_deleted") : false;
        format_type = obj.has_member ("format_type") ? obj.get_string_member ("format_type") : "markdown";
        has_checklist = obj.has_member ("has_checklist") ? obj.get_boolean_member ("has_checklist") : false;
        color = obj.has_member ("color") ? obj.get_string_member ("color") : "";
        source_id = obj.has_member ("source_id") ? obj.get_string_member ("source_id") : "local";
        backend_type = obj.has_member ("backend_type") ? obj.get_string_member ("backend_type") : "local";
        extra_data = obj.has_member ("extra_data") ? obj.get_string_member ("extra_data") : "";
        search_index = obj.has_member ("search_index") ? obj.get_string_member ("search_index") : "";
        tags = obj.has_member ("tags") ? obj.get_string_member ("tags") : "";
        linked_items = obj.has_member ("linked_items") ? obj.get_string_member ("linked_items") : "";
    }
    
    private void load_labels () {
        if (tags == "" || tags == "[]") {
            return;
        }
        
        try {
            var parser = new Json.Parser ();
            parser.load_from_data (tags, -1);
            
            var array = parser.get_root ().get_array ();
            array.foreach_element ((arr, index, node) => {
                string label_id = node.get_string ();
                Objects.Label? label = Services.Store.instance ().get_label (label_id);
                if (label != null) {
                    _labels.add (label);
                }
            });
        } catch (Error e) {
            warning ("Error loading note labels: %s", e.message);
        }
    }
    
    private void load_attachments () {
        // Load attachments from database
        // _attachments = Services.Database.get_default ().get_note_attachments (id);
        // TODO: Implement when NoteAttachments table is ready
    }
    
    public void add_label (Objects.Label label) {
        if (labels.contains (label)) {
            return;
        }
        
        _labels.add (label);
        save_labels ();
        updated ();
    }
    
    public void remove_label (Objects.Label label) {
        _labels.remove (label);
        save_labels ();
        updated ();
    }
    
    private void save_labels () {
        var builder = new Json.Builder ();
        builder.begin_array ();
        
        foreach (var label in _labels) {
            builder.add_string_value (label.id);
        }
        
        builder.end_array ();
        
        var generator = new Json.Generator ();
        var root = builder.get_root ();
        generator.set_root (root);
        tags = generator.to_data (null);
    }
    
    public void update_search_index () {
        // Create searchable text from title and content
        search_index = (title + " " + content).down ();
    }
    
    public void update_accessed_time () {
        accessed_at = new GLib.DateTime.now_local ().to_string ();
        Services.Database.get_default ().update_note (this);
    }
    
    public void update_modified_time () {
        updated_at = new GLib.DateTime.now_local ().to_string ();
        update_search_index ();
    }
    
    public bool matches_search (string query) {
        if (query.strip () == "") {
            return true;
        }
        
        string search_lower = query.down ();
        return search_index.contains (search_lower);
    }
    
    public string get_preview (int max_length = 150) {
        if (content.length <= max_length) {
            return content;
        }
        
        string preview = content.substring (0, max_length);
        int last_space = preview.last_index_of (" ");
        
        if (last_space > 0) {
            preview = preview.substring (0, last_space);
        }
        
        return preview + "...";
    }
    
    public void copy_to_clipboard () {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        
        string clipboard_text = "# %s\n\n%s".printf (title, content);
        clipboard.set_text (clipboard_text);
    }
    
    public Objects.Note duplicate () {
        var new_note = new Objects.Note ();
        new_note.title = _("Copy of %s").printf (title);
        new_note.content = content;
        new_note.notebook_id = notebook_id;
        new_note.folder_id = folder_id;
        new_note.color = color;
        new_note.format_type = format_type;
        new_note.tags = tags;
        new_note.update_search_index ();
        
        return new_note;
    }
    
    public string to_markdown () {
        var builder = new StringBuilder ();
        builder.append ("# %s\n\n".printf (title));
        
        if (labels.size > 0) {
            builder.append ("**Tags:** ");
            for (int i = 0; i < labels.size; i++) {
                builder.append (labels[i].name);
                if (i < labels.size - 1) {
                    builder.append (", ");
                }
            }
            builder.append ("\n\n");
        }
        
        builder.append ("**Created:** %s\n\n".printf (Utils.Datetime.get_default_date_format_from_string (created_at)));
        builder.append ("**Modified:** %s\n\n".printf (Utils.Datetime.get_default_date_format_from_string (updated_at)));
        builder.append ("---\n\n");
        builder.append (content);
        
        return builder.str;
    }
    
    public void print_debug () {
        print ("\n=== Note Debug Info ===\n");
        print ("ID: %s\n", id);
        print ("Title: %s\n", title);
        print ("Notebook: %s\n", notebook_id);
        print ("Created: %s\n", created_at);
        print ("Updated: %s\n", updated_at);
        print ("Content length: %d chars\n", character_count);
        print ("Word count: %d\n", word_count);
        print ("Is Pinned: %s\n", is_pinned.to_string ());
        print ("Is Favorite: %s\n", is_favorite.to_string ());
        print ("Labels: %d\n", labels.size);
        print ("======================\n\n");
    }
}
