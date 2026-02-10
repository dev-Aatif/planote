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

/**
 * AutoSave service provides debounced auto-save functionality for notes.
 * Prevents data loss on crashes by automatically saving after a delay.
 */
public class Services.AutoSave : GLib.Object {
    private static AutoSave? _instance;
    
    private Gee.HashMap<string, uint> pending_saves;
    private Gee.HashMap<string, unowned Objects.Note> pending_notes;
    private const uint DEBOUNCE_MS = 2000;  // 2 second debounce
    
    public static AutoSave get_default () {
        if (_instance == null) {
            _instance = new AutoSave ();
        }
        return _instance;
    }
    
    construct {
        pending_saves = new Gee.HashMap<string, uint> ();
        pending_notes = new Gee.HashMap<string, unowned Objects.Note> ();
    }
    
    /**
     * Schedule an auto-save for a note with debounce.
     * Cancels any pending save for the same note and schedules a new one.
     * @param note The note to save
     */
    public void schedule_save (Objects.Note note) {
        // Cancel existing pending save for this note
        cancel (note.id);
        
        // Schedule new save after debounce delay
        uint timeout_id = Timeout.add (DEBOUNCE_MS, () => {
            perform_save (note);
            pending_saves.unset (note.id);
            return GLib.Source.REMOVE;
        });
        
        pending_saves.set (note.id, timeout_id);
        pending_notes.set (note.id, note);
    }
    
    /**
     * Cancel a pending auto-save for a specific note.
     * @param note_id The ID of the note to cancel save for
     */
    public void cancel (string note_id) {
        if (pending_saves.has_key (note_id)) {
            Source.remove (pending_saves.get (note_id));
            pending_saves.unset (note_id);
            pending_notes.unset (note_id);
        }
    }
    
    /**
     * Immediately save all pending notes.
     * Call this before app close to ensure no data loss.
     */
    public void flush_all () {
        // Cancel all pending timeouts first
        foreach (var entry in pending_saves.entries) {
            Source.remove (entry.value);
        }
        
        // Force immediate save of all pending notes to prevent data loss
        foreach (var entry in pending_notes.entries) {
            perform_save (entry.value);
        }
        
        pending_saves.clear ();
        pending_notes.clear ();
    }
    
    /**
     * Check if a note has a pending save.
     * @param note_id The ID of the note to check
     * @return true if there's a pending save
     */
    public bool has_pending_save (string note_id) {
        return pending_saves.has_key (note_id);
    }
    
    /**
     * Get the number of pending saves.
     * @return count of notes with pending saves
     */
    public int pending_count {
        get { return pending_saves.size; }
    }
    
    private void perform_save (Objects.Note note) {
        // Only save if note hasn't been deleted
        if (!note.is_deleted) {
            note.updated_at = new GLib.DateTime.now_local ().to_string ();
            Services.Database.get_default ().update_note (note);
            debug ("Auto-saved note: %s", note.title);
        }
    }
}
