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
 * Abstract base class for undoable commands.
 * Implement execute() for the forward action and undo() for reversal.
 */
public abstract class Services.Command : GLib.Object {
    /**
     * Execute the command (forward action).
     * @return true if successful
     */
    public abstract bool execute ();
    
    /**
     * Undo the command (reverse action).
     * @return true if successful
     */
    public abstract bool undo ();
    
    /**
     * Human-readable description of the command.
     */
    public abstract string description { owned get; }
}

/**
 * Command to add an item to the store.
 */
public class Services.AddItemCommand : Services.Command {
    private Objects.Item item;
    private bool insert_db;
    
    public AddItemCommand (Objects.Item item, bool insert_db = true) {
        this.item = item;
        this.insert_db = insert_db;
    }
    
    public override string description {
        owned get { return "Add task: %s".printf (item.content); }
    }
    
    public override bool execute () {
        Services.Store.instance ().insert_item (item, insert_db);
        return true;
    }
    
    public override bool undo () {
        Services.Store.instance ().delete_item (item);
        return true;
    }
}

/**
 * Command to delete an item from the store.
 */
public class Services.DeleteItemCommand : Services.Command {
    private Objects.Item item;
    private Objects.Item? item_backup;
    
    public DeleteItemCommand (Objects.Item item) {
        this.item = item;
        // Create a backup for undo
        this.item_backup = null;
    }
    
    public override string description {
        owned get { return "Delete task: %s".printf (item.content); }
    }
    
    public override bool execute () {
        // Backup item state before deletion
        item_backup = item;
        Services.Store.instance ().delete_item (item);
        return true;
    }
    
    public override bool undo () {
        if (item_backup != null) {
            // Restore the item
            item_backup.is_deleted = false;
            Services.Store.instance ().insert_item (item_backup, true);
            return true;
        }
        return false;
    }
}

/**
 * Command to update an item.
 */
public class Services.UpdateItemCommand : Services.Command {
    private Objects.Item item;
    private string update_id;
    private string old_content;
    private string new_content;
    private string old_description;
    private string new_description;
    
    public UpdateItemCommand (Objects.Item item, string update_id = "") {
        this.item = item;
        this.update_id = update_id;
        // Backup will be set when execute is called
        this.old_content = "";
        this.new_content = "";
        this.old_description = "";
        this.new_description = "";
    }
    
    public void set_content_change (string old_val, string new_val) {
        this.old_content = old_val;
        this.new_content = new_val;
    }
    
    public void set_description_change (string old_val, string new_val) {
        this.old_description = old_val;
        this.new_description = new_val;
    }
    
    public override string description {
        owned get { return "Update task: %s".printf (item.content); }
    }
    
    public override bool execute () {
        if (new_content != "") {
            item.content = new_content;
        }
        if (new_description != "") {
            item.description = new_description;
        }
        Services.Store.instance ().update_item (item, update_id);
        return true;
    }
    
    public override bool undo () {
        if (old_content != "") {
            item.content = old_content;
        }
        if (old_description != "") {
            item.description = old_description;
        }
        Services.Store.instance ().update_item (item, update_id);
        return true;
    }
}

/**
 * Command to add a project.
 */
public class Services.AddProjectCommand : Services.Command {
    private Objects.Project project;
    
    public AddProjectCommand (Objects.Project project) {
        this.project = project;
    }
    
    public override string description {
        owned get { return "Add project: %s".printf (project.name); }
    }
    
    public override bool execute () {
        Services.Store.instance ().insert_project (project);
        return true;
    }
    
    public override bool undo () {
        Services.Store.instance ().delete_project.begin (project);
        return true;
    }
}

/**
 * Command to delete a project.
 */
public class Services.DeleteProjectCommand : Services.Command {
    private Objects.Project project;
    
    public DeleteProjectCommand (Objects.Project project) {
        this.project = project;
    }
    
    public override string description {
        owned get { return "Delete project: %s".printf (project.name); }
    }
    
    public override bool execute () {
        Services.Store.instance ().delete_project.begin (project);
        return true;
    }
    
    public override bool undo () {
        project.is_deleted = false;
        Services.Store.instance ().insert_project (project);
        return true;
    }
}

/**
 * Manages undo/redo stack for reversible operations.
 * Singleton pattern for global access.
 */
public class Services.UndoManager : GLib.Object {
    private Gee.LinkedList<Command> undo_stack;
    private Gee.LinkedList<Command> redo_stack;
    private int max_history = 50;
    
    /**
     * Emitted when undo/redo state changes.
     */
    public signal void changed ();
    
    /**
     * Emitted when an action is performed (for UI feedback).
     */
    public signal void action_performed (string description);
    
    /**
     * Emitted when an action is undone (for UI feedback).
     */
    public signal void action_undone (string description);
    
    private static UndoManager? _instance;
    public static UndoManager instance () {
        if (_instance == null) {
            _instance = new UndoManager ();
        }
        return _instance;
    }
    
    construct {
        undo_stack = new Gee.LinkedList<Command> ();
        redo_stack = new Gee.LinkedList<Command> ();
    }
    
    /**
     * Execute a command and add it to the undo stack.
     * @param command The command to execute
     * @return true if execution was successful
     */
    public bool execute (Command command) {
        bool success = command.execute ();
        if (success) {
            undo_stack.offer_head (command);
            redo_stack.clear ();  // Clear redo stack on new action
            trim_history ();
            action_performed (command.description);
            changed ();
        }
        return success;
    }
    
    /**
     * Undo the last action.
     * @return true if undo was successful
     */
    public bool undo () {
        if (undo_stack.size == 0) {
            return false;
        }
        
        var command = undo_stack.poll_head ();
        bool success = command.undo ();
        if (success) {
            redo_stack.offer_head (command);
            action_undone (command.description);
            changed ();
        } else {
            // Put it back if undo failed
            undo_stack.offer_head (command);
        }
        return success;
    }
    
    /**
     * Redo the last undone action.
     * @return true if redo was successful
     */
    public bool redo () {
        if (redo_stack.size == 0) {
            return false;
        }
        
        var command = redo_stack.poll_head ();
        bool success = command.execute ();
        if (success) {
            undo_stack.offer_head (command);
            action_performed (command.description);
            changed ();
        } else {
            // Put it back if redo failed
            redo_stack.offer_head (command);
        }
        return success;
    }
    
    /**
     * Clear all history.
     */
    public void clear () {
        undo_stack.clear ();
        redo_stack.clear ();
        changed ();
    }
    
    /**
     * Check if undo is available.
     */
    public bool can_undo {
        get { return undo_stack.size > 0; }
    }
    
    /**
     * Check if redo is available.
     */
    public bool can_redo {
        get { return redo_stack.size > 0; }
    }
    
    /**
     * Get the description of the next undo action.
     */
    public string? next_undo_description {
        owned get {
            if (undo_stack.size > 0) {
                return undo_stack.peek_head ().description;
            }
            return null;
        }
    }
    
    /**
     * Get the description of the next redo action.
     */
    public string? next_redo_description {
        owned get {
            if (redo_stack.size > 0) {
                return redo_stack.peek_head ().description;
            }
            return null;
        }
    }
    
    private void trim_history () {
        while (undo_stack.size > max_history) {
            undo_stack.poll_tail ();
        }
    }
}
