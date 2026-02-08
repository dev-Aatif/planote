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
    private Gtk.Button bold_button;
    private Gtk.Button italic_button;
    private Gtk.Button strikethrough_button;
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
    private Gtk.Button code_button;
    private Gtk.Button link_button;
    private Gtk.Button unordered_list_button;
    private Gtk.Button ordered_list_button;

    private Gtk.Popover link_popover;
    private Gtk.Entry link_entry;
    private Gtk.Button link_apply_button;
    private Gtk.Button link_remove_button;
    private Gtk.TextTag bold_tag;
    private Gtk.TextTag italic_tag;
    private Gtk.TextTag strikethrough_tag;
    private Gtk.TextTag h1_tag;
    private Gtk.TextTag h2_tag;
    private Gtk.TextTag h3_tag;
    private Gtk.TextTag h4_tag;
    private Gtk.TextTag h5_tag;
    private Gtk.TextTag h6_tag;
    private Gtk.TextTag code_tag;
    private Gtk.TextTag link_tag;
    private Gtk.TextTag invisible_tag;
    private Gtk.TextTag placeholder_tag;
    private Gtk.TextTag list_tag;
    private Gtk.TextTag ordered_list_tag;

    private string selected_link_text = "";
    private bool mouse_pressed = false;
    private bool showing_placeholder = false;
    private Gtk.GestureClick gesture_click;
    private bool editing_existing_link = false;
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
        
        gesture_click = new Gtk.GestureClick ();
        gesture_click.pressed.connect (on_text_clicked);
        text_view.add_controller (gesture_click);
        
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
        bold_tag = buffer.create_tag ("bold",
                                     "weight", Pango.Weight.BOLD);
        
        italic_tag = buffer.create_tag ("italic",
                                       "style", Pango.Style.ITALIC);
        
        strikethrough_tag = buffer.create_tag ("strikethrough",
                                              "strikethrough", true);
        
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
        
        // Use CSS-aware colors that adapt to light/dark themes
        code_tag = buffer.create_tag ("code",
                                         "family", "monospace");
        
        link_tag = buffer.create_tag ("link",
                                     "underline", Pango.Underline.SINGLE);
        
        invisible_tag = buffer.create_tag ("invisible",
                                         "invisible", true);
        
        // Placeholder uses less prominent styling
        placeholder_tag = buffer.create_tag ("placeholder");
        
        list_tag = buffer.create_tag ("unordered-list",
                                     "left-margin", 20);
        
        ordered_list_tag = buffer.create_tag ("ordered-list",
                                             "left-margin", 0);
        
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
            code_tag.foreground = "#f78166";       // Softer red for dark mode
            link_tag.foreground = "#58a6ff";       // Brighter blue for dark mode
            placeholder_tag.foreground = "#8b949e"; // Dimmed text for dark mode
        } else {
            code_tag.foreground = "#cf222e";       // Standard red for light mode
            link_tag.foreground = "#0969da";       // Standard blue for light mode
            placeholder_tag.foreground = "#888888"; // Dimmed text for light mode
        }
    }
    
    private void create_format_popover () {        
        bold_button = new Gtk.Button.from_icon_name ("text-bold-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        bold_button.add_css_class ("flat");
        
        italic_button = new Gtk.Button.from_icon_name ("text-italic-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        italic_button.add_css_class ("flat");
        
        strikethrough_button = new Gtk.Button.from_icon_name ("text-strikethrough-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        strikethrough_button.add_css_class ("flat");
        
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
        
        code_button = new Gtk.Button.from_icon_name ("code-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        code_button.add_css_class ("flat");
        
        link_button = new Gtk.Button.from_icon_name ("chain-link-loose-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        link_button.add_css_class ("flat");
        
        unordered_list_button = new Gtk.Button.from_icon_name ("view-list-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        unordered_list_button.add_css_class ("flat");
        
        ordered_list_button = new Gtk.Button.from_icon_name ("view-list-ordered-symbolic") {
            valign = CENTER,
            halign = CENTER
        };
        ordered_list_button.add_css_class ("flat");
                
        var format_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        format_box.append (heading_dropdown);
        format_box.append (new Gtk.Separator (VERTICAL));
        format_box.append (bold_button);
        format_box.append (italic_button);
        format_box.append (strikethrough_button);
        format_box.append (code_button);
        format_box.append (new Gtk.Separator (VERTICAL));
        format_box.append (unordered_list_button);
        format_box.append (ordered_list_button);

        format_box.append (new Gtk.Separator (VERTICAL));
        format_box.append (link_button);

        bold_button.clicked.connect (on_bold_clicked);
        italic_button.clicked.connect (on_italic_clicked);
        strikethrough_button.clicked.connect (on_strikethrough_clicked);

        code_button.clicked.connect (on_code_clicked);
        link_button.clicked.connect (on_link_clicked);
        unordered_list_button.clicked.connect (on_unordered_list_clicked);
        ordered_list_button.clicked.connect (on_ordered_list_clicked);

        create_link_popover ();

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
    
    private void on_bold_clicked () {
        toggle_bold_format ();
        format_popover.popdown ();
    }
    
    private void on_italic_clicked () {
        toggle_italic_format ();
        format_popover.popdown ();
    }
    
    private void on_strikethrough_clicked () {
        toggle_strikethrough_format ();
        format_popover.popdown ();
    }
    
    private void on_code_clicked () {
        toggle_code_format ();
        format_popover.popdown ();
    }
    
    private void on_link_clicked () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            selected_link_text = buffer.get_text (start, end, false);
            
            if (is_already_link (start, end)) {
                show_edit_link_popover (start);
            } else {
                show_add_link_popover (start);
            }
        }

        format_popover.popdown ();
    }
    
    public void insert_link () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            selected_link_text = buffer.get_text (start, end, false);
            
            if (is_already_link (start, end)) {
                show_edit_link_popover (start);
            } else {
                show_add_link_popover (start);
            }
        } else {
            var cursor = buffer.get_insert ();
            Gtk.TextIter iter;
            buffer.get_iter_at_mark (out iter, cursor);
            
            if (iter.has_tag (link_tag)) {
                show_edit_link_popover (iter);
            } else {
                selected_link_text = "";
                show_add_link_popover (iter);
            }
        }
    }

    private void on_unordered_list_clicked () {
        apply_unordered_list_format ();
        format_popover.popdown ();
    }
    
    private void on_ordered_list_clicked () {
        apply_ordered_list_format ();
        format_popover.popdown ();
    }

    public void toggle_bold_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var selected_text = buffer.get_text (start, end, false);
            
            var has_bold = is_already_bold (start, end);
            var has_italic = is_already_italic (start, end);
            
            if (has_bold && has_italic) {
                remove_bold_keep_italic (start, end);
            } else if (has_bold) {
                remove_bold_format (start, end);
            } else {
                add_bold_format (start, end, selected_text);
            }
        }
    }
    
    public void toggle_italic_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var selected_text = buffer.get_text (start, end, false);
            
            var has_bold = is_already_bold (start, end);
            var has_italic = is_already_italic (start, end);
            
            if (has_bold && has_italic) {
                remove_italic_keep_bold (start, end);
            } else if (has_italic) {
                remove_italic_format (start, end);
            } else {
                add_italic_format (start, end, selected_text);
            }
        }
    }
    
    public void toggle_strikethrough_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var selected_text = buffer.get_text (start, end, false);
            
            var has_strikethrough = text_has_strikethrough_in_range (start, end);
            
            if (has_strikethrough) {
                remove_strikethrough_format (start, end);
            } else {
                add_strikethrough_format (start, end, selected_text);
            }
        }
    }
    
    private bool is_already_bold (Gtk.TextIter start, Gtk.TextIter end) {
        return start.has_tag (bold_tag);
    }
    
    private bool is_already_italic (Gtk.TextIter start, Gtk.TextIter end) {
        return start.has_tag (italic_tag);
    }
    

    
    private void remove_bold_format (Gtk.TextIter start, Gtk.TextIter end) {
        var search_start = start;
        var search_end = end;
        
        while (search_start.backward_char ()) {
            if (search_start.has_tag (invisible_tag)) {
                continue;
            } else {
                search_start.forward_char ();
                break;
            }
        }
        
        while (search_end.forward_char ()) {
            if (search_end.has_tag (invisible_tag)) {
                continue;
            } else {
                search_end.backward_char ();
                break;
            }
        }
        
        var text = buffer.get_text (start, end, false);
        
        buffer.delete (ref search_start, ref search_end);
        buffer.insert (ref search_start, text, -1);
        
        apply_markdown_formatting ();
    }
    
    private void add_bold_format (Gtk.TextIter start, Gtk.TextIter end, string text) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        var has_italic = text_has_italic_in_range (start, end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        
        if (has_italic) {
            buffer.insert (ref expanded.start, "***" + clean_text + "***", -1);
        } else {
            buffer.insert (ref expanded.start, "**" + clean_text + "**", -1);
        }
        
        apply_markdown_formatting ();
    }
    
    private void remove_bold_keep_italic (Gtk.TextIter start, Gtk.TextIter end) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        buffer.insert (ref expanded.start, "*" + clean_text + "*", -1);
        
        apply_markdown_formatting ();
    }
    
    private void remove_italic_format (Gtk.TextIter start, Gtk.TextIter end) {
        var search_start = start;
        var search_end = end;
        
        while (search_start.backward_char ()) {
            if (search_start.has_tag (invisible_tag)) {
                continue;
            } else {
                search_start.forward_char ();
                break;
            }
        }
        
        while (search_end.forward_char ()) {
            if (search_end.has_tag (invisible_tag)) {
                continue;
            } else {
                search_end.backward_char ();
                break;
            }
        }
        
        var text = buffer.get_text (start, end, false);
        
        buffer.delete (ref search_start, ref search_end);
        buffer.insert (ref search_start, text, -1);
        
        apply_markdown_formatting ();
    }
    
    private void add_italic_format (Gtk.TextIter start, Gtk.TextIter end, string text) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        var has_bold = text_has_bold_in_range (start, end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        
        if (has_bold) {
            buffer.insert (ref expanded.start, "***" + clean_text + "***", -1);
        } else {
            buffer.insert (ref expanded.start, "*" + clean_text + "*", -1);
        }
        
        apply_markdown_formatting ();
    }
    
    private void remove_italic_keep_bold (Gtk.TextIter start, Gtk.TextIter end) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        buffer.insert (ref expanded.start, "**" + clean_text + "**", -1);
        
        apply_markdown_formatting ();
    }
    
    private void remove_strikethrough_format (Gtk.TextIter start, Gtk.TextIter end) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        var has_bold = text_has_bold_in_range (start, end);
        var has_italic = text_has_italic_in_range (start, end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        
        string formatted_text;
        if (has_bold && has_italic) {
            formatted_text = "***" + clean_text + "***";
        } else if (has_bold) {
            formatted_text = "**" + clean_text + "**";
        } else if (has_italic) {
            formatted_text = "*" + clean_text + "*";
        } else {
            formatted_text = clean_text;
        }
        
        buffer.insert (ref expanded.start, formatted_text, -1);
        
        apply_markdown_formatting ();
    }
    
    private void add_strikethrough_format (Gtk.TextIter start, Gtk.TextIter end, string text) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        var has_bold = text_has_bold_in_range (start, end);
        var has_italic = text_has_italic_in_range (start, end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        
        string formatted_text;
        if (has_bold && has_italic) {
            formatted_text = "~~***" + clean_text + "***~~";
        } else if (has_bold) {
            formatted_text = "~~**" + clean_text + "**~~";
        } else if (has_italic) {
            formatted_text = "~~*" + clean_text + "*~~";
        } else {
            formatted_text = "~~" + clean_text + "~~";
        }
        
        buffer.insert (ref expanded.start, formatted_text, -1);
        
        apply_markdown_formatting ();
    }
    
    private struct ExpandedRange {
        public Gtk.TextIter start;
        public Gtk.TextIter end;
    }
    
    private ExpandedRange expand_selection_for_asterisks (Gtk.TextIter start, Gtk.TextIter end) {
        var expanded_start = start;
        var expanded_end = end;
        
        while (expanded_start.backward_char ()) {
            if (expanded_start.has_tag (invisible_tag)) {
                continue;
            } else {
                expanded_start.forward_char ();
                break;
            }
        }
        
        while (expanded_end.forward_char ()) {
            if (expanded_end.has_tag (invisible_tag)) {
                continue;
            } else {
                expanded_end.backward_char ();
                break;
            }
        }
        
        ExpandedRange range = ExpandedRange ();
        range.start = expanded_start;
        range.end = expanded_end;
        
        return range;
    }
    
    private string get_clean_text_from_range (Gtk.TextIter start, Gtk.TextIter end) {
        var text = buffer.get_text (start, end, false);
        return text.replace ("*", "").replace ("~", "").replace ("`", "");
    }
    
    private bool text_has_bold_in_range (Gtk.TextIter start, Gtk.TextIter end) {
        var iter = start;
        while (iter.compare (end) < 0) {
            if (iter.has_tag (bold_tag)) {
                return true;
            }
            if (!iter.forward_char ()) break;
        }

        return false;
    }
    
    private bool text_has_italic_in_range (Gtk.TextIter start, Gtk.TextIter end) {
        var iter = start;
        while (iter.compare (end) < 0) {
            if (iter.has_tag (italic_tag)) {
                return true;
            }
            if (!iter.forward_char ()) break;
        }

        return false;
    }
    
    private bool text_has_strikethrough_in_range (Gtk.TextIter start, Gtk.TextIter end) {
        var iter = start;
        while (iter.compare (end) < 0) {
            if (iter.has_tag (strikethrough_tag)) {
                return true;
            }
            if (!iter.forward_char ()) break;
        }

        return false;
    }
    
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
            
            if (!iter.has_tag (bold_tag) && !iter.has_tag (italic_tag) && 
                !iter.has_tag (strikethrough_tag) && !iter.has_tag (code_tag) && 
                !iter.has_tag (link_tag)) {
                return;
            }
            
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
            if (handle_list_enter ()) {
                return true;
            }
            
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
        
        if (iter.has_tag (bold_tag) || iter.has_tag (italic_tag) || 
            iter.has_tag (strikethrough_tag) || iter.has_tag (code_tag) || 
            iter.has_tag (link_tag)) {
            
            var next_iter = iter;
            next_iter.forward_char ();
            
            buffer.remove_tag (bold_tag, iter, next_iter);
            buffer.remove_tag (italic_tag, iter, next_iter);
            buffer.remove_tag (strikethrough_tag, iter, next_iter);
            buffer.remove_tag (code_tag, iter, next_iter);
            buffer.remove_tag (link_tag, iter, next_iter);
        }
    }
    
    private bool handle_list_enter () {
        var cursor = buffer.get_insert ();
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, cursor);
        
        var line_num = iter.get_line ();
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line_num);
        line_end = line_start;
        if (!line_end.ends_line ()) {
            line_end.forward_to_line_end ();
        }
        
        var line_text = buffer.get_text (line_start, line_end, false);
        
        if (line_text.has_prefix ("- ") || line_text.has_prefix ("• ")) {
            var content = line_text.substring (2).strip ();
            if (content == "") {
                buffer.delete (ref line_start, ref line_end);
            } else {
                buffer.insert_at_cursor ("\n- ", -1);
            }

            return true;
        }
        
        try {
            var regex = new GLib.Regex ("^(\\d+)\\. (.*)$");
            GLib.MatchInfo match_info;
            
            if (regex.match (line_text, 0, out match_info)) {
                var number_str = match_info.fetch (1);
                var content = match_info.fetch (2).strip ();
                var number = int.parse (number_str);
                
                if (content == "") {
                    buffer.delete (ref line_start, ref line_end);
                } else {
                    var next_item = "\n%d. ".printf (number + 1);
                    buffer.insert_at_cursor (next_item, -1);
                }

                return true;
            }
        } catch (GLib.RegexError e) {
            warning ("Error in list regex: %s", e.message);
        }
        
        return false;
    }
    
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
        
        try {
            var bold_italic_regex = new GLib.Regex ("\\*\\*\\*([^*]+)\\*\\*\\*");
            GLib.MatchInfo match_info;
            
            if (bold_italic_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter bi_start, bi_end;
                    buffer.get_iter_at_offset (out bi_start, start_chars);
                    buffer.get_iter_at_offset (out bi_end, end_chars);
                    
                    Gtk.TextIter ast_end = bi_start;
                    ast_end.forward_chars (3);
                    buffer.apply_tag (invisible_tag, bi_start, ast_end);
                    
                    Gtk.TextIter text_start = bi_start;
                    text_start.forward_chars (3);
                    Gtk.TextIter text_end = bi_end;
                    text_end.backward_chars (3);
                    buffer.apply_tag (bold_tag, text_start, text_end);
                    buffer.apply_tag (italic_tag, text_start, text_end);
                    
                    Gtk.TextIter last_ast_start = bi_end;
                    last_ast_start.backward_chars (3);
                    buffer.apply_tag (invisible_tag, last_ast_start, bi_end);
                    
                } while (match_info.next ());
            }
            
            var bold_regex = new GLib.Regex ("(?<!\\*)\\*\\*([^*]+)\\*\\*(?!\\*)");
            
            if (bold_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter bold_start, bold_end;
                    buffer.get_iter_at_offset (out bold_start, start_chars);
                    buffer.get_iter_at_offset (out bold_end, end_chars);
                    
                    Gtk.TextIter ast_end = bold_start;
                    ast_end.forward_chars (2);
                    buffer.apply_tag (invisible_tag, bold_start, ast_end);
                    
                    Gtk.TextIter text_start = bold_start;
                    text_start.forward_chars (2);
                    Gtk.TextIter text_end = bold_end;
                    text_end.backward_chars (2);
                    buffer.apply_tag (bold_tag, text_start, text_end);
                    
                    Gtk.TextIter last_ast_start = bold_end;
                    last_ast_start.backward_chars (2);
                    buffer.apply_tag (invisible_tag, last_ast_start, bold_end);
                    
                } while (match_info.next ());
            }
            
            var italic_regex = new GLib.Regex ("(?<!\\*)\\*([^*]+)\\*(?!\\*)");
            
            if (italic_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter italic_start, italic_end;
                    buffer.get_iter_at_offset (out italic_start, start_chars);
                    buffer.get_iter_at_offset (out italic_end, end_chars);
                    
                    Gtk.TextIter ast_end = italic_start;
                    ast_end.forward_chars (1);
                    buffer.apply_tag (invisible_tag, italic_start, ast_end);
                    
                    Gtk.TextIter text_start = italic_start;
                    text_start.forward_chars (1);
                    Gtk.TextIter text_end = italic_end;
                    text_end.backward_chars (1);
                    buffer.apply_tag (italic_tag, text_start, text_end);
                    
                    Gtk.TextIter last_ast_start = italic_end;
                    last_ast_start.backward_chars (1);
                    buffer.apply_tag (invisible_tag, last_ast_start, italic_end);
                    
                } while (match_info.next ());
            }
            
            var strikethrough_regex = new GLib.Regex ("~~([^~]+)~~");
            
            if (strikethrough_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter strike_start, strike_end;
                    buffer.get_iter_at_offset (out strike_start, start_chars);
                    buffer.get_iter_at_offset (out strike_end, end_chars);
                    
                    Gtk.TextIter tilde_end = strike_start;
                    tilde_end.forward_chars (2);
                    buffer.apply_tag (invisible_tag, strike_start, tilde_end);
                    
                    Gtk.TextIter text_start = strike_start;
                    text_start.forward_chars (2);
                    Gtk.TextIter text_end = strike_end;
                    text_end.backward_chars (2);
                    buffer.apply_tag (strikethrough_tag, text_start, text_end);
                    
                    Gtk.TextIter last_tilde_start = strike_end;
                    last_tilde_start.backward_chars (2);
                    buffer.apply_tag (invisible_tag, last_tilde_start, strike_end);
                    
                } while (match_info.next ());
            }
            
            
            // Heading styles are now applied directly via WYSIWYG, no markdown prefixes needed
            
            var code_regex = new GLib.Regex ("`([^`]+)`");
            
            if (code_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter code_start, code_end;
                    buffer.get_iter_at_offset (out code_start, start_chars);
                    buffer.get_iter_at_offset (out code_end, end_chars);
                    
                    Gtk.TextIter tick_end = code_start;
                    tick_end.forward_chars (1);
                    buffer.apply_tag (invisible_tag, code_start, tick_end);
                    
                    Gtk.TextIter text_start = code_start;
                    text_start.forward_chars (1);
                    Gtk.TextIter text_end = code_end;
                    text_end.backward_chars (1);
                    buffer.apply_tag (code_tag, text_start, text_end);
                    
                    Gtk.TextIter last_tick_start = code_end;
                    last_tick_start.backward_chars (1);
                    buffer.apply_tag (invisible_tag, last_tick_start, code_end);
                    
                } while (match_info.next ());
            }
            
            var link_regex = new GLib.Regex ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)");
            
            if (link_regex.match (text, 0, out match_info)) {
                do {
                    int full_start_pos, full_end_pos;
                    match_info.fetch_pos (0, out full_start_pos, out full_end_pos);
                    
                    int text_start_pos, text_end_pos;
                    match_info.fetch_pos (1, out text_start_pos, out text_end_pos);
                    
                    var full_start_chars = text.substring (0, full_start_pos).char_count ();
                    var full_end_chars = text.substring (0, full_end_pos).char_count ();
                    var text_start_chars = text.substring (0, text_start_pos).char_count ();
                    var text_end_chars = text.substring (0, text_end_pos).char_count ();
                    
                    Gtk.TextIter full_start, full_end, text_start, text_end;
                    buffer.get_iter_at_offset (out full_start, full_start_chars);
                    buffer.get_iter_at_offset (out full_end, full_end_chars);
                    buffer.get_iter_at_offset (out text_start, text_start_chars);
                    buffer.get_iter_at_offset (out text_end, text_end_chars);
                    
                    buffer.apply_tag (link_tag, full_start, full_end);
                    
                    Gtk.TextIter bracket_end = full_start;
                    bracket_end.forward_chars (1);
                    buffer.apply_tag (invisible_tag, full_start, bracket_end);
                    
                    buffer.apply_tag (invisible_tag, text_end, full_end);
                    
                } while (match_info.next ());
            }
            
            var unordered_list_regex = new GLib.Regex ("^- (?!\\[[ x]\\])(.*)$", GLib.RegexCompileFlags.MULTILINE);
            
            if (unordered_list_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter list_start, list_end;
                    buffer.get_iter_at_offset (out list_start, start_chars);
                    buffer.get_iter_at_offset (out list_end, end_chars);
                    
                    var line_text = buffer.get_text (list_start, list_end, false);
                    if (line_text.has_prefix ("- ")) {
                        buffer.changed.disconnect (on_buffer_changed);
                        
                        Gtk.TextIter dash_end = list_start;
                        dash_end.forward_chars (1);
                        buffer.delete (ref list_start, ref dash_end);
                        buffer.insert (ref list_start, "•", -1);
                        
                        buffer.changed.connect (on_buffer_changed);
                        
                        buffer.get_iter_at_offset (out list_end, end_chars);
                    }
                    
                    buffer.apply_tag (list_tag, list_start, list_end);
                    
                } while (match_info.next ());
            }
            
            var ordered_list_regex = new GLib.Regex ("^(\\d+)\\. (.*)$", GLib.RegexCompileFlags.MULTILINE);
            
            if (ordered_list_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter list_start, list_end;
                    buffer.get_iter_at_offset (out list_start, start_chars);
                    buffer.get_iter_at_offset (out list_end, end_chars);
                    
                    buffer.apply_tag (ordered_list_tag, list_start, list_end);
                    
                } while (match_info.next ());
            }
            
            var plain_url_regex = new GLib.Regex ("(?<!\\[)(?<!\\()\\b[a-zA-Z][a-zA-Z0-9+.-]*://[^\\s)]+");
            
            if (plain_url_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    Gtk.TextIter url_start, url_end;
                    buffer.get_iter_at_offset (out url_start, start_chars);
                    buffer.get_iter_at_offset (out url_end, end_chars);
                    
                    buffer.apply_tag (link_tag, url_start, url_end);
                    
                } while (match_info.next ());
            }

        } catch (GLib.RegexError e) {
            warning ("Error in regex: %s", e.message);
        }
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
    

    
    public void toggle_code_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var selected_text = buffer.get_text (start, end, false);
            
            if (is_already_code (start, end)) {
                remove_code_format (start, end);
            } else {
                add_code_format (start, end, selected_text);
            }
        }
    }
    
    public void apply_unordered_list_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            apply_list_format (start, end, false);
        }
    }
    
    public void apply_ordered_list_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            apply_list_format (start, end, true);
        }
    }
    
    private void apply_list_format (Gtk.TextIter start, Gtk.TextIter end, bool ordered) {
        var start_line = start.get_line ();
        var end_line = end.get_line ();
        
        if (end.get_line_offset () == 0 && end_line > start_line) {
            end_line--;
        }
        
        var lines = new string[end_line - start_line + 1];
        
        for (int i = start_line; i <= end_line; i++) {
            Gtk.TextIter line_start, line_end;
            buffer.get_iter_at_line (out line_start, i);
            line_end = line_start;
            if (!line_end.ends_line ()) {
                line_end.forward_to_line_end ();
            }
            lines[i - start_line] = buffer.get_text (line_start, line_end, false);
        }
        
        for (int i = 0; i < lines.length; i++) {
            var line = lines[i].strip ();
            if (ordered) {
                lines[i] = "%d. %s".printf (i + 1, line);
            } else {
                lines[i] = "- " + line;
            }
        }
        
        Gtk.TextIter full_start, full_end;
        buffer.get_iter_at_line (out full_start, start_line);
        buffer.get_iter_at_line (out full_end, end_line);
        if (!full_end.ends_line ()) {
            full_end.forward_to_line_end ();
        }
        
        var new_text = string.joinv ("\n", lines);
        buffer.delete (ref full_start, ref full_end);
        buffer.insert (ref full_start, new_text, -1);
        
        apply_markdown_formatting ();
    }
    
    private bool is_already_code (Gtk.TextIter start, Gtk.TextIter end) {
        return start.has_tag (code_tag);
    }
    
    private void add_code_format (Gtk.TextIter start, Gtk.TextIter end, string text) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        buffer.insert (ref expanded.start, "`" + clean_text + "`", -1);
        
        apply_markdown_formatting ();
    }
    
    private void remove_code_format (Gtk.TextIter start, Gtk.TextIter end) {
        var expanded = expand_selection_for_asterisks (start, end);
        var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
        
        buffer.delete (ref expanded.start, ref expanded.end);
        buffer.insert (ref expanded.start, clean_text, -1);
        
        apply_markdown_formatting ();
    }
    
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
        
        if (link_popover != null) {
            if (link_popover.get_parent () != null) {
                link_popover.popdown ();
                link_popover.unparent ();
            }
            link_popover = null;
        }
    }
    
    private void create_link_popover () {
        link_entry = new Gtk.Entry () {
            placeholder_text = "https://example.com",
            width_request = 320
        };
        
        link_apply_button = new Gtk.Button.from_icon_name ("checkmark-small-symbolic") {
            tooltip_text = _("Apply")
        };
        link_apply_button.add_css_class ("suggested-action");
        
        link_remove_button = new Gtk.Button.from_icon_name ("user-trash-symbolic") {
            tooltip_text = _("Remove link")
        };
        link_remove_button.add_css_class ("destructive-action");
        
        var link_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_start = 6,
            margin_end = 6,
            margin_top = 6,
            margin_bottom = 6
        };
        
        link_box.append (link_entry);
        link_box.append (link_apply_button);
        
        link_popover = new Gtk.Popover () {
            has_arrow = false,
            autohide = true,
            child = link_box
        };
        
        link_apply_button.clicked.connect (on_link_apply_clicked);
        link_remove_button.clicked.connect (on_link_remove_clicked);
        link_entry.activate.connect (on_link_apply_clicked);
        link_entry.changed.connect (on_link_entry_changed);
    }
    
    private bool is_already_link (Gtk.TextIter start, Gtk.TextIter end) {
        return start.has_tag (link_tag);
    }
    
    private void show_add_link_popover (Gtk.TextIter iter) {
        editing_existing_link = false;
        link_entry.text = "";
        
        var link_box = (Gtk.Box) link_popover.child;
        if (link_box.get_last_child () == link_remove_button) {
            link_box.remove (link_remove_button);
        }
        if (link_box.get_last_child () != link_apply_button) {
            link_box.append (link_apply_button);
        }
        
        show_link_popover_at_iter (iter);
    }
    
    private void show_edit_link_popover (Gtk.TextIter iter) {
        editing_existing_link = true;
        var url = extract_url_from_link (iter);
        link_entry.text = url;
        
        var link_box = (Gtk.Box) link_popover.child;
        if (link_box.get_last_child () == link_apply_button) {
            link_box.remove (link_apply_button);
        }
        
        if (link_box.get_last_child () != link_remove_button) {
            link_box.append (link_remove_button);
        }
        
        show_link_popover_at_iter (iter);
    }
    
    private void show_link_popover_at_iter (Gtk.TextIter iter) {
        Gdk.Rectangle rect;
        text_view.get_iter_location (iter, out rect);
        
        int x, y;
        text_view.buffer_to_window_coords (Gtk.TextWindowType.TEXT,
                                         rect.x, rect.y,
                                         out x, out y);
        
        rect.x = x;
        rect.y = y - 12;
        
        link_popover.set_parent (text_view);
        link_popover.set_pointing_to (rect);
        link_popover.popup ();
        link_entry.grab_focus ();
    }
    
    private void on_link_apply_clicked () {
        var url = link_entry.text.strip ();
        if (url != "") {
            apply_link_format (url);
        }
        link_popover.popdown ();
    }
    
    private void on_link_remove_clicked () {
        remove_link_format ();
        link_popover.popdown ();
    }
    
    private void on_link_entry_changed () {
        if (editing_existing_link) {
            var url = link_entry.text.strip ();
            if (url != "") {
                var cursor = buffer.get_insert ();
                Gtk.TextIter iter;
                buffer.get_iter_at_mark (out iter, cursor);
                
                if (iter.has_tag (link_tag)) {
                    replace_link_url_at_cursor (iter, url);
                }
            }
        }
    }
    
    private void apply_link_format (string url) {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var expanded = expand_selection_for_asterisks (start, end);
            var clean_text = selected_link_text;
            
            buffer.delete (ref expanded.start, ref expanded.end);
            buffer.insert (ref expanded.start, "[" + clean_text + "](" + url + ")", -1);
            
            apply_markdown_formatting ();
        } else {
            var cursor = buffer.get_insert ();
            Gtk.TextIter iter;
            buffer.get_iter_at_mark (out iter, cursor);
            
            if (iter.has_tag (link_tag)) {
                replace_link_url_at_cursor (iter, url);
            }
        }
    }
    
    private void remove_link_format () {
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            var expanded = expand_selection_for_asterisks (start, end);
            var clean_text = get_clean_text_from_range (expanded.start, expanded.end);
            
            buffer.delete (ref expanded.start, ref expanded.end);
            buffer.insert (ref expanded.start, clean_text, -1);
            
            apply_markdown_formatting ();
        } else {
            var cursor = buffer.get_insert ();
            Gtk.TextIter iter;
            buffer.get_iter_at_mark (out iter, cursor);
            
            if (iter.has_tag (link_tag)) {
                remove_link_at_cursor (iter);
            }
        }
    }
    
    private string extract_url_from_link (Gtk.TextIter iter) {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, true);
        
        var cursor_offset = iter.get_offset ();
        
        try {
            var regex = new GLib.Regex ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)");
            GLib.MatchInfo match_info;
            
            if (regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (1, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    if (cursor_offset >= start_chars && cursor_offset <= end_chars) {
                        return match_info.fetch (2);
                    }
                } while (match_info.next ());
            }
            
            var plain_url_regex = new GLib.Regex ("\\b[a-zA-Z][a-zA-Z0-9+.-]*://[^\\s)]+");
            
            if (plain_url_regex.match (text, 0, out match_info)) {
                do {
                    int start_pos, end_pos;
                    match_info.fetch_pos (0, out start_pos, out end_pos);
                    
                    var start_chars = text.substring (0, start_pos).char_count ();
                    var end_chars = text.substring (0, end_pos).char_count ();
                    
                    if (cursor_offset >= start_chars && cursor_offset <= end_chars) {
                        return match_info.fetch (0);
                    }
                } while (match_info.next ());
            }
        } catch (GLib.RegexError e) {
            warning ("Error in regex: %s", e.message);
        }
        
        return "";
    }
    
    private void replace_link_url_at_cursor (Gtk.TextIter iter, string new_url) {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, true);
        
        var cursor_offset = iter.get_offset ();
        
        try {
            var regex = new GLib.Regex ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)");
            GLib.MatchInfo match_info;
            
            if (regex.match (text, 0, out match_info)) {
                do {
                    int text_start_pos, text_end_pos;
                    match_info.fetch_pos (1, out text_start_pos, out text_end_pos);
                    
                    var text_start_chars = text.substring (0, text_start_pos).char_count ();
                    var text_end_chars = text.substring (0, text_end_pos).char_count ();
                    
                    if (cursor_offset >= text_start_chars && cursor_offset <= text_end_chars) {
                        int full_start_pos, full_end_pos;
                        match_info.fetch_pos (0, out full_start_pos, out full_end_pos);
                        
                        var full_start_chars = text.substring (0, full_start_pos).char_count ();
                        var full_end_chars = text.substring (0, full_end_pos).char_count ();
                        
                        Gtk.TextIter link_start, link_end;
                        buffer.get_iter_at_offset (out link_start, full_start_chars);
                        buffer.get_iter_at_offset (out link_end, full_end_chars);
                        
                        var link_text = match_info.fetch (1);
                        
                        buffer.delete (ref link_start, ref link_end);
                        buffer.insert (ref link_start, "[" + link_text + "](" + new_url + ")", -1);
                        
                        apply_markdown_formatting ();
                        return;
                    }
                } while (match_info.next ());
            }
        } catch (GLib.RegexError e) {
            warning ("Error in regex: %s", e.message);
        }
    }
    
    private void remove_link_at_cursor (Gtk.TextIter iter) {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var text = buffer.get_text (start, end, true);
        
        var cursor_offset = iter.get_offset ();
        
        try {
            var regex = new GLib.Regex ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)");
            GLib.MatchInfo match_info;
            
            if (regex.match (text, 0, out match_info)) {
                do {
                    int text_start_pos, text_end_pos;
                    match_info.fetch_pos (1, out text_start_pos, out text_end_pos);
                    
                    var text_start_chars = text.substring (0, text_start_pos).char_count ();
                    var text_end_chars = text.substring (0, text_end_pos).char_count ();
                    
                    if (cursor_offset >= text_start_chars && cursor_offset <= text_end_chars) {
                        int full_start_pos, full_end_pos;
                        match_info.fetch_pos (0, out full_start_pos, out full_end_pos);
                        
                        var full_start_chars = text.substring (0, full_start_pos).char_count ();
                        var full_end_chars = text.substring (0, full_end_pos).char_count ();
                        
                        Gtk.TextIter link_start, link_end;
                        buffer.get_iter_at_offset (out link_start, full_start_chars);
                        buffer.get_iter_at_offset (out link_end, full_end_chars);
                        
                        var link_text = match_info.fetch (1);
                        
                        buffer.delete (ref link_start, ref link_end);
                        buffer.insert (ref link_start, link_text, -1);
                        
                        apply_markdown_formatting ();
                        return;
                    }
                } while (match_info.next ());
            }
        } catch (GLib.RegexError e) {
            warning ("Error in regex: %s", e.message);
        }
    }
    
    private void on_text_clicked (int n_press, double x, double y) {
        
        int buffer_x, buffer_y;
        text_view.window_to_buffer_coords (Gtk.TextWindowType.TEXT,
                                          (int)x, (int)y,
                                          out buffer_x, out buffer_y);
        
        Gtk.TextIter iter;
        text_view.get_iter_at_location (out iter, buffer_x, buffer_y);
        
        if (iter.has_tag (link_tag)) {
            var current_state = gesture_click.get_current_event_state ();
            
            if ((current_state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                open_link_at_iter (iter);
            } else {
                buffer.place_cursor (iter);
                show_edit_link_popover (iter);
            }
        }

    }
    
    private string normalize_url (string url) {
        var trimmed_url = url.strip ();
        
        if (trimmed_url.contains ("://")) {
            return trimmed_url;
        }
        
        if (trimmed_url.contains (".") && !trimmed_url.contains (" ")) {
            return "https://" + trimmed_url;
        }
        
        return trimmed_url;
    }
    
    private void open_link_at_iter (Gtk.TextIter iter) {
        var url = extract_url_from_link (iter);
        
        if (url != "") {
            var normalized_url = normalize_url (url);
            try {
                AppInfo.launch_default_for_uri (normalized_url, null);
            } catch (Error e) {
                Services.EventBus.get_default ().send_toast (
                    Util.get_default ().create_toast (e.message)
                );
            }
        }
    }

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
