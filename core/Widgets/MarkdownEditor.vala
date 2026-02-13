/*
 * Copyright © 2025 Alain M. (https://github.com/alainm23/planify)
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
 *
 * Authored by: Alain M. <alainmh23@gmail.com>
 */

public class Widgets.MarkdownEditor : Adw.Bin {
    public Gtk.TextView text_view;
    public GtkSource.Buffer buffer;

    private Gtk.Popover format_popover;
    private Gtk.DropDown heading_dropdown;
    private bool heading_popover_active = false;
    private int _current_heading_level = 0; // 0 = Normal, 1-6 = H1-H6
    public int current_heading_level {
        get { return _current_heading_level; }
        set {
            if (_current_heading_level != value) {
                _current_heading_level = value;
                heading_level_changed (value);
            }
        }
    }
    public signal void heading_level_changed (int level);

    private Gtk.TextTag h1_tag;
    private Gtk.TextTag h2_tag;
    private Gtk.TextTag h3_tag;
    private Gtk.TextTag h4_tag;
    private Gtk.TextTag h5_tag;
    private Gtk.TextTag h6_tag;
    private Gtk.TextTag invisible_tag;
    private Gtk.TextTag placeholder_tag;


    private bool mouse_pressed = false;
    private bool showing_placeholder = false;
    private bool updating_programmatically = false;
    
    // Track heading level per line (line_number -> heading_level)
    private Gee.HashMap<int, int> line_heading_levels = new Gee.HashMap<int, int> ();
    
    public string placeholder_text {get; set; default = ""; }

    public signal void text_changed (string text);
    public signal void escape_pressed ();
    public signal void return_pressed ();
    public signal void focus_in ();
    public signal void focus_out ();

    public bool is_editable {
        set {
            text_view.editable = value;
        }

        get {
            return text_view.editable;
        }
    }

    ~MarkdownEditor () {
        debug ("Destroying - Layouts.Widgets.MarkdownEditor\n");
    }
    
    construct {
        buffer = new GtkSource.Buffer (null);
        
        text_view = new Gtk.TextView.with_buffer (buffer) {
            wrap_mode = Gtk.WrapMode.WORD,
            accepts_tab = false
        };
        text_view.remove_css_class ("view");
        
        create_text_tags ();
        
        notify["placeholder-text"].connect (update_placeholder_visibility);
        update_placeholder_visibility ();
        
        create_format_popover ();

#if WITH_LIBSPELLING
        var adapter = new Spelling.TextBufferAdapter (buffer, Spelling.Checker.get_default ());
        text_view.extra_menu = adapter.get_menu_model ();
        text_view.insert_action_group ("spelling", adapter);
        adapter.enabled = Services.Settings.get_default ().settings.get_boolean ("spell-checking-enabled");
        
        Services.Settings.get_default ().settings.changed["spell-checking-enabled"].connect (() => {
            adapter.enabled = Services.Settings.get_default ().settings.get_boolean ("spell-checking-enabled");
        });
#endif
        
        // Apply font settings from preferences
        apply_font_settings ();
        Services.Settings.get_default ().settings.changed["notes-font-family"].connect (apply_font_settings);
        Services.Settings.get_default ().settings.changed["notes-font-size"].connect (apply_font_settings);
        
        buffer.changed.connect (on_buffer_changed);
        buffer.notify["has-selection"].connect (on_selection_lost);
        buffer.notify["cursor-position"].connect (on_cursor_moved);
        
        var click_controller = new Gtk.EventControllerLegacy ();
        click_controller.event.connect (on_event);
        text_view.add_controller (click_controller);
        
        /*
        gesture_click = new Gtk.GestureClick ();
        gesture_click.pressed.connect (on_text_clicked);
        text_view.add_controller (gesture_click);
        */
        
        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        text_view.add_controller (key_controller);
        
        var focus_controller = new Gtk.EventControllerFocus ();
        focus_controller.enter.connect (handle_focus_in);
        focus_controller.leave.connect (handle_focus_out);
        text_view.add_controller (focus_controller);
        
        // Setup context menu for right-click
        setup_context_menu ();
        
        child = text_view;

        destroy.connect (() => {
            cleanup ();
        });
    }
    
    private void create_text_tags () {
        /*
        // Formatting tags removed by user request
        */
        
        h1_tag = buffer.create_tag ("h1",
                                   "scale", 1.2,
                                   "weight", Pango.Weight.BOLD);
        
        h2_tag = buffer.create_tag ("h2",
                                   "scale", 1.1,
                                   "weight", Pango.Weight.BOLD);
        
        h3_tag = buffer.create_tag ("h3",
                                   "scale", 1.05,
                                   "weight", Pango.Weight.BOLD);
        
        h4_tag = buffer.create_tag ("h4",
                                   "scale", 1.0,
                                   "weight", Pango.Weight.BOLD);
        
        h5_tag = buffer.create_tag ("h5",
                                   "scale", 0.95,
                                   "weight", Pango.Weight.BOLD);
        
        h6_tag = buffer.create_tag ("h6",
                                   "scale", 0.9,
                                   "weight", Pango.Weight.BOLD);
        
        invisible_tag = buffer.create_tag ("invisible",
                                         "invisible", true);
        
        // Placeholder uses less prominent styling
        placeholder_tag = buffer.create_tag ("placeholder");
        
        // Apply theme-aware colors
        update_tag_colors ();
        
        // Listen for style changes to update colors when theme changes
        var style_manager = Adw.StyleManager.get_default ();
        style_manager.notify["dark"].connect (update_tag_colors);
    }
    
    private void update_tag_colors () {
        var style_manager = Adw.StyleManager.get_default ();
        bool is_dark = style_manager.dark;
        
        // Use appropriate colors for light/dark theme
        if (is_dark) {
            placeholder_tag.foreground = "#8b949e"; // Dimmed text for dark mode
        } else {
            placeholder_tag.foreground = "#888888"; // Dimmed text for light mode
        }
    }
    
    private void create_format_popover () {        
        // Heading dropdown (H1-H6)
        var heading_model = new Gtk.StringList (null);
        heading_model.append (_("Normal"));
        heading_model.append ("H1");
        heading_model.append ("H2");
        heading_model.append ("H3");
        heading_model.append ("H4");
        heading_model.append ("H5");
        heading_model.append ("H6");
        
        heading_dropdown = new Gtk.DropDown (heading_model, null) {
            tooltip_text = _("Heading Level"),
            valign = CENTER,
            halign = CENTER
        };
        heading_dropdown.selected = 0;
        heading_dropdown.notify["selected"].connect (() => {
            int selected = (int) heading_dropdown.selected;
            current_heading_level = selected; // Update sticky heading level
            apply_heading_format (selected); // Apply format (0 = Normal removes heading)
            heading_popover_active = true;
            format_popover.popdown ();
            heading_popover_active = false;
        });
        
        // Sync internal dropdown when heading level changes externally
        heading_level_changed.connect ((level) => {
            if (heading_dropdown.selected != (uint) level) {
                heading_dropdown.selected = (uint) level;
            }
        });
        
        var format_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        format_box.append (heading_dropdown);

        format_popover = new Gtk.Popover () {
            has_arrow = false,
            autohide = false,
            child = format_box
        };
    }
    
    private bool on_event (Gdk.Event event) {
        
        if (event.get_event_type () == Gdk.EventType.BUTTON_PRESS) {
            mouse_pressed = true;
        } else if (event.get_event_type () == Gdk.EventType.BUTTON_RELEASE && mouse_pressed) {
            mouse_pressed = false;
            
            Gtk.TextIter start, end;
            if (buffer.get_selection_bounds (out start, out end)) {
                show_format_popover (start);
            }
        }

        return false;
    }
    
    private void show_format_popover (Gtk.TextIter start) {
        Gdk.Rectangle rect;
        text_view.get_iter_location (start, out rect);
        
        int x, y;
        text_view.buffer_to_window_coords (Gtk.TextWindowType.TEXT,
                                         rect.x, rect.y,
                                         out x, out y);
        
        rect.x = x;
        rect.y = y;
        
        format_popover.set_parent (text_view);
        format_popover.set_pointing_to (rect);
        format_popover.popup ();
    }
    
    /*
    // Formatting methods removed by user request (Plain Text + Headings only)
    */
    
    private void on_selection_lost () {
        Gtk.TextIter start, end;
        if (!buffer.get_selection_bounds (out start, out end)) {
            format_popover.popdown ();
        }
    }
    
    private void on_cursor_moved () {
        Gtk.TextIter start, end;
        if (!buffer.get_selection_bounds (out start, out end)) {
            var cursor = buffer.get_insert ();
            Gtk.TextIter iter;
            buffer.get_iter_at_mark (out iter, cursor);
            
            if (iter.get_line_offset () == 0 || iter.ends_line ()) {
                clear_cursor_formatting ();
            }
        }
    }
    
    private void handle_focus_in () {
        Services.EventBus.get_default ().disconnect_typing_accel ();
        
        if (showing_placeholder) {
            Gtk.TextIter start, end;
            buffer.get_bounds (out start, out end);
            var current_text = buffer.get_text (start, end, false);
            
            if (current_text == placeholder_text) {
                buffer.set_text ("", -1);
            }
            showing_placeholder = false;
        }
        
        text_view.grab_focus ();
        focus_in ();
    }
    
    private void handle_focus_out () {
        Services.EventBus.get_default ().connect_typing_accel ();
        update_placeholder_visibility ();
        focus_out ();
    }
    
    private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
        if (format_popover.visible) {
            format_popover.popdown ();
        }
        
        if (keyval == Gdk.Key.Escape) {
            escape_pressed ();
            return true;
        }
        
        if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
        /*
        if (handle_list_enter ()) {
            return true;
        }
        */
            
            // Handle heading continuation if a heading level is active
            if (current_heading_level > 0) {
                if (handle_heading_enter ()) {
                    return true;
                }
            }

            clear_cursor_formatting ();
            return_pressed ();
        }
        
        if (keyval == Gdk.Key.space) {
            clear_cursor_formatting ();
        }
        
        if (keyval >= 32 && keyval <= 126) {
            clear_cursor_formatting ();
        }
        
        return false;
    }
    
    private void clear_cursor_formatting () {
        var cursor = buffer.get_insert ();
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, cursor);
        
        /*
        // Formatting clearing logic removed
        */
    }
    
    /*
    private bool handle_list_enter () {
       // Removed
       return false;
    }
    
    private void renumber_ordered_list (int start_line, int current_number) {
       // Removed
    }
    */
    
    private bool handle_heading_enter () {
        if (current_heading_level == 0) {
            return false;
        }
        
        // Get the current line number BEFORE inserting newline
        Gtk.TextIter cursor;
        buffer.get_iter_at_mark (out cursor, buffer.get_insert ());
        int prev_line = cursor.get_line ();
        
        // Insert newline
        buffer.insert_at_cursor ("\n", -1);
        
        // Re-apply heading style to the PREVIOUS line (to preserve it)
        apply_heading_to_line (prev_line, current_heading_level);
        
        // Apply heading style to the new line
        apply_heading_to_current_line ();
        
        return true;
    }
    
    private void apply_heading_to_line (int line, int level) {
        // Store the heading level for this line
        if (level > 0) {
            line_heading_levels.set (line, level);
        } else {
            line_heading_levels.unset (line);
        }
        
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line);
        line_end = line_start;
        if (!line_end.ends_line ()) {
            line_end.forward_to_line_end ();
        }
        
        // Remove all heading tags from the line first
        buffer.remove_tag (h1_tag, line_start, line_end);
        buffer.remove_tag (h2_tag, line_start, line_end);
        buffer.remove_tag (h3_tag, line_start, line_end);
        buffer.remove_tag (h4_tag, line_start, line_end);
        buffer.remove_tag (h5_tag, line_start, line_end);
        buffer.remove_tag (h6_tag, line_start, line_end);
        
        // Apply the heading tag
        if (level > 0) {
            Gtk.TextTag tag = get_heading_tag (level);
            if (tag != null) {
                buffer.apply_tag (tag, line_start, line_end);
            }
        }
    }
    
    private void apply_heading_to_current_line () {
        if (current_heading_level == 0) {
            return;
        }
        
        Gtk.TextIter cursor;
        buffer.get_iter_at_mark (out cursor, buffer.get_insert ());
        int line = cursor.get_line ();
        
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line);
        line_end = line_start;
        if (!line_end.ends_line ()) {
            line_end.forward_to_line_end ();
        }
        
        // Apply the heading tag
        Gtk.TextTag tag = get_heading_tag (current_heading_level);
        if (tag != null) {
            buffer.apply_tag (tag, line_start, line_end);
        }
    }
    
    private Gtk.TextTag? get_heading_tag (int level) {
        switch (level) {
            case 1: return h1_tag;
            case 2: return h2_tag;
            case 3: return h3_tag;
            case 4: return h4_tag;
            case 5: return h5_tag;
            case 6: return h6_tag;
            default: return null;
        }
    }
    
    private void update_placeholder_visibility () {
        var real_text = get_real_text ().strip ();
        
        if (!text_view.has_focus && real_text == "" && placeholder_text != "" && !showing_placeholder) {
            showing_placeholder = true;
            buffer.set_text (placeholder_text, -1);
            Gtk.TextIter start, end;
            buffer.get_bounds (out start, out end);
            buffer.apply_tag (placeholder_tag, start, end);
        } else if (showing_placeholder && (text_view.has_focus || real_text != "")) {
            showing_placeholder = false;
            if (text_view.has_focus) {
                buffer.set_text ("", -1);
            }
        }
    }
    
    private string get_real_text () {
        if (showing_placeholder) {
            return "";
        }

        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        return buffer.get_text (start, end, true);
    }
    
    private void on_buffer_changed () {
        if (!showing_placeholder && !updating_programmatically) {
            apply_markdown_formatting ();
            
            // Apply heading style to current line if in heading mode
            if (current_heading_level > 0) {
                apply_heading_to_current_line ();
            }
            
            Gtk.TextIter start, end;
            buffer.get_bounds (out start, out end);
            text_changed (buffer.get_text (start, end, true));
        }
    }
    
    private void apply_markdown_formatting () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        buffer.remove_all_tags (start, end);
        
        // Re-apply saved heading styles
        foreach (var entry in line_heading_levels.entries) {
            int line = entry.key;
            int level = entry.value;
            
            Gtk.TextIter line_start, line_end;
            buffer.get_iter_at_line (out line_start, line);
            line_end = line_start;
            if (!line_end.ends_line ()) {
                line_end.forward_to_line_end ();
            }
            
            Gtk.TextTag tag = get_heading_tag (level);
            if (tag != null) {
                buffer.apply_tag (tag, line_start, line_end);
            }
        }
        
        var text = buffer.get_text (start, end, true);
        
        /*
        // Markdown parsing for bold, italic, code, links, etc. explicitly removed.
        // Only Headings are supported via line_heading_levels.
        */
        
    }
    
    public void apply_heading_format (int level) {
        // level: 0 = Normal (remove heading), 1 = H1, 2 = H2, ... 6 = H6
        // Pure WYSIWYG - no markdown prefixes, just apply visual styles
        
        Gtk.TextIter cursor;
        buffer.get_iter_at_mark (out cursor, buffer.get_insert ());
        int line = cursor.get_line ();
        
        // Store the heading level for this line
        if (level > 0) {
            line_heading_levels.set (line, level);
        } else {
            line_heading_levels.unset (line);
        }
        
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line);
        line_end = line_start;
        if (!line_end.ends_line ()) {
            line_end.forward_to_line_end ();
        }
        
        buffer.begin_user_action ();
        
        // Remove all heading tags from the line first
        buffer.remove_tag (h1_tag, line_start, line_end);
        buffer.remove_tag (h2_tag, line_start, line_end);
        buffer.remove_tag (h3_tag, line_start, line_end);
        buffer.remove_tag (h4_tag, line_start, line_end);
        buffer.remove_tag (h5_tag, line_start, line_end);
        buffer.remove_tag (h6_tag, line_start, line_end);
        
        // Apply the new heading tag if level > 0
        if (level > 0) {
            Gtk.TextTag tag = get_heading_tag (level);
            if (tag != null) {
                buffer.apply_tag (tag, line_start, line_end);
            }
        }
        
        buffer.end_user_action ();
        text_view.grab_focus ();
    }
    

    
    /*
    // Code and List formatting methods removed
    */
    
    public void set_text (string text) {
        updating_programmatically = true;
        showing_placeholder = false;
        buffer.set_text (text, -1);
        update_placeholder_visibility ();
        updating_programmatically = false;
        apply_markdown_formatting ();
    }
    
    public string get_text () {
        var text = get_real_text ();
        text = text.replace ("• ", "- ");

        return text;
    }
    
    public string get_plain_text () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, true);
        
        try {
            var regex = new GLib.Regex ("\\*+");
            return regex.replace (text, -1, 0, "");
        } catch (GLib.RegexError e) {
            return text;
        }
    }
    
    public void clear () {
        buffer.set_text ("", -1);
    }
    
    public new void focus () {
        text_view.grab_focus ();
    }
    
    public void cleanup () {
        if (format_popover != null) {
            if (format_popover.get_parent () != null) {
                format_popover.popdown ();
                format_popover.unparent ();
            }
            format_popover = null;
        }
    }
    
    /*
    // Popover methods removed
    */
    
    /*
    // Link methods removed
    */
    
    /*
    // Link methods removed
    */

    public void view_focus () {
        text_view.grab_focus ();
    }
    
    // ========================================
    // Context Menu and Edit Operations
    // ========================================
    
    private Gtk.PopoverMenu? context_menu_popover = null;
    private SimpleActionGroup context_actions;
    
    public void setup_context_menu () {
        // Create action group for context menu
        context_actions = new SimpleActionGroup ();
        
        var undo_action = new SimpleAction ("undo", null);
        undo_action.activate.connect (() => { undo (); });
        context_actions.add_action (undo_action);
        
        var redo_action = new SimpleAction ("redo", null);
        redo_action.activate.connect (() => { redo (); });
        context_actions.add_action (redo_action);
        
        var cut_action = new SimpleAction ("cut", null);
        cut_action.activate.connect (() => { cut_selection (); });
        context_actions.add_action (cut_action);
        
        var copy_action = new SimpleAction ("copy", null);
        copy_action.activate.connect (() => { copy_selection (); });
        context_actions.add_action (copy_action);
        
        var paste_action = new SimpleAction ("paste", null);
        paste_action.activate.connect (() => { paste (); });
        context_actions.add_action (paste_action);
        
        var delete_action = new SimpleAction ("delete", null);
        delete_action.activate.connect (() => { delete_selection (); });
        context_actions.add_action (delete_action);
        
        var select_all_action = new SimpleAction ("select-all", null);
        select_all_action.activate.connect (() => { select_all (); });
        context_actions.add_action (select_all_action);
        
        var uppercase_action = new SimpleAction ("uppercase", null);
        uppercase_action.activate.connect (() => { change_case_upper (); });
        context_actions.add_action (uppercase_action);
        
        var lowercase_action = new SimpleAction ("lowercase", null);
        lowercase_action.activate.connect (() => { change_case_lower (); });
        context_actions.add_action (lowercase_action);
        
        text_view.insert_action_group ("edit", context_actions);
        
        // Add heading actions
        for (int i = 1; i <= 6; i++) {
            int level = i;
            var heading_action = new SimpleAction ("heading%d".printf (i), null);
            heading_action.activate.connect (() => { apply_heading_format (level); });
            context_actions.add_action (heading_action);
        }
        
        // Build the menu model - Only include unique items to avoid duplicates
        var menu = new GLib.Menu ();
        
        var case_section = new GLib.Menu ();
        case_section.append (_("UPPERCASE"), "edit.uppercase");
        case_section.append (_("lowercase"), "edit.lowercase");
        menu.append_section (_("Change Case"), case_section);
        
        // Heading submenu
        var heading_submenu = new GLib.Menu ();
        heading_submenu.append ("H1", "edit.heading1");
        heading_submenu.append ("H2", "edit.heading2");
        heading_submenu.append ("H3", "edit.heading3");
        heading_submenu.append ("H4", "edit.heading4");
        heading_submenu.append ("H5", "edit.heading5");
        heading_submenu.append ("H6", "edit.heading6");
        menu.append_submenu (_("Heading"), heading_submenu);
        
        // Set the extra menu on the text view
        text_view.extra_menu = menu;
        
        // Update action sensitivity based on selection
        buffer.notify["has-selection"].connect (update_context_action_sensitivity);
        buffer.notify["cursor-position"].connect (update_context_action_sensitivity);
        update_context_action_sensitivity ();
    }
    
    private void update_context_action_sensitivity () {
        var has_selection = buffer.has_selection;
        
        var cut_action = (SimpleAction) context_actions.lookup_action ("cut");
        var copy_action = (SimpleAction) context_actions.lookup_action ("copy");
        var delete_action = (SimpleAction) context_actions.lookup_action ("delete");
        var uppercase_action = (SimpleAction) context_actions.lookup_action ("uppercase");
        var lowercase_action = (SimpleAction) context_actions.lookup_action ("lowercase");
        var undo_action = (SimpleAction) context_actions.lookup_action ("undo");
        var redo_action = (SimpleAction) context_actions.lookup_action ("redo");
        
        cut_action.set_enabled (has_selection);
        copy_action.set_enabled (has_selection);
        delete_action.set_enabled (has_selection);
        uppercase_action.set_enabled (has_selection);
        lowercase_action.set_enabled (has_selection);
        undo_action.set_enabled (buffer.can_undo);
        redo_action.set_enabled (buffer.can_redo);
    }
    

    
    // Undo/Redo using GtkSource.Buffer built-in support
    public void undo () {
        if (buffer.can_undo) {
            buffer.undo ();
        }
    }
    
    public void redo () {
        if (buffer.can_redo) {
            buffer.redo ();
        }
    }
    
    // Select All
    public void select_all () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        buffer.select_range (start, end);
    }
    
    // Cut/Copy/Paste/Delete operations
    public void cut_selection () {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var text = buffer.get_text (start, end, true);
            clipboard.set_text (text);
            buffer.delete (ref start, ref end);
        }
    }
    
    public void copy_selection () {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var text = buffer.get_text (start, end, true);
            clipboard.set_text (text);
        }
    }
    
    public void paste () {
        var clipboard = Gdk.Display.get_default ().get_clipboard ();
        clipboard.read_text_async.begin (null, (obj, res) => {
            try {
                var text = clipboard.read_text_async.end (res);
                if (text != null) {
                    buffer.begin_user_action ();
                    Gtk.TextIter start, end;
                    if (buffer.get_selection_bounds (out start, out end)) {
                        buffer.delete (ref start, ref end);
                    }
                    buffer.insert_at_cursor (text, -1);
                    buffer.end_user_action ();
                }
            } catch (Error e) {
                debug ("Paste error: %s", e.message);
            }
        });
    }
    
    public void delete_selection () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            buffer.delete (ref start, ref end);
        }
    }
    
    // Change Case
    public void change_case_upper () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var text = buffer.get_text (start, end, true);
            buffer.begin_user_action ();
            buffer.delete (ref start, ref end);
            buffer.insert (ref start, text.up (), -1);
            buffer.end_user_action ();
        }
    }
    
    public void change_case_lower () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var text = buffer.get_text (start, end, true);
            buffer.begin_user_action ();
            buffer.delete (ref start, ref end);
            buffer.insert (ref start, text.down (), -1);
            buffer.end_user_action ();
        }
    }
    
    private void apply_font_settings () {
        var settings = Services.Settings.get_default ().settings;
        var font_family = settings.get_string ("notes-font-family");
        var font_size = settings.get_int ("notes-font-size");
        
        // Create Pango font description
        var font_desc = new Pango.FontDescription ();
        font_desc.set_family (font_family);
        font_desc.set_size (font_size * Pango.SCALE);
        
        // Apply to text view using Pango attributes
        var attrs = new Pango.AttrList ();
        attrs.insert (new Pango.AttrFontDesc (font_desc));
        
        // Use CSS provider for better GTK4 integration
        var css = "textview { font-family: %s; font-size: %dpt; }".printf (font_family, font_size);
        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (css);
            text_view.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            debug ("Failed to apply font settings: %s", e.message);
        }
    }
}
