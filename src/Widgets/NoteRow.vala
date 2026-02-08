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

public class Widgets.NoteRow : Gtk.ListBoxRow {
    public Objects.Note note { get; construct; }
    
    public signal void edit_requested ();
    public signal void expansion_changed (bool is_expanded);

    private Gtk.Label title_label;
    private Gtk.Label content_label;
    private Gtk.Label date_label;
    private Gtk.Button view_toggle_button;
    private Gtk.Box action_buttons_box;
    private Gtk.Revealer action_revealer;
    private Gtk.Box card_box;
    private bool _is_expanded = false;
    
    // Context menu
    private Gtk.Popover context_popover;
    
    public bool is_expanded {
        get { return _is_expanded; }
        set {
            if (_is_expanded != value) {
                _is_expanded = value;
                update_expansion_state ();
            }
        }
    }

    public NoteRow (Objects.Note note) {
        Object (note: note);
    }

    ~NoteRow () {
        note.updated.disconnect (update_ui);
    }
    
    public void collapse () {
        is_expanded = false;
    }

    construct {
        css_classes = { "note-card" };
        
        // Main card container with styling
        card_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        card_box.add_css_class ("note-card-inner");

        // Header row with title and action buttons
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        
        title_label = new Gtk.Label (note.title) {
            css_classes = { "note-title" },
            halign = START,
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        // Action buttons in a revealer (shown on hover)
        action_buttons_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        action_buttons_box.add_css_class ("note-action-buttons");
        
        var edit_button = new Gtk.Button () {
            icon_name = "document-edit-symbolic",
            tooltip_text = _("Edit Note"),
            valign = CENTER
        };
        edit_button.add_css_class ("note-action-btn");
        edit_button.add_css_class ("circular");
        edit_button.clicked.connect (() => {
            edit_requested ();
        });

        var delete_button = new Gtk.Button () {
            icon_name = "user-trash-symbolic",
            tooltip_text = _("Delete Note"),
            valign = CENTER
        };
        delete_button.add_css_class ("note-action-btn");
        delete_button.add_css_class ("note-action-btn-danger");
        delete_button.add_css_class ("circular");
        delete_button.clicked.connect (() => {
            show_delete_dialog ();
        });

        action_buttons_box.append (edit_button);
        action_buttons_box.append (delete_button);
        
        action_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.CROSSFADE,
            transition_duration = 150,
            reveal_child = false,
            child = action_buttons_box
        };
        
        header_box.append (title_label);
        header_box.append (action_revealer);
        
        // Content label - single label that changes properties
        content_label = new Gtk.Label (note.get_preview ()) {
            css_classes = { "note-preview" },
            halign = START,
            xalign = 0,
            yalign = 0,
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 80,
            wrap = false,
            lines = 2,
            single_line_mode = false,
            selectable = false
        };
        
        // Footer row with date and view toggle
        var footer_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            margin_top = 10
        };
        
        view_toggle_button = new Gtk.Button () {
            halign = START,
            valign = CENTER
        };
        
        var toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var toggle_icon = new Gtk.Image.from_icon_name ("go-down-symbolic");
        toggle_icon.add_css_class ("note-toggle-icon");
        var toggle_label = new Gtk.Label (_("View More"));
        toggle_box.append (toggle_label);
        toggle_box.append (toggle_icon);
        view_toggle_button.child = toggle_box;
        
        view_toggle_button.add_css_class ("note-view-toggle");
        view_toggle_button.add_css_class ("flat");
        view_toggle_button.clicked.connect (() => {
            toggle_expansion ();
        });

        date_label = new Gtk.Label (Utils.Datetime.get_relative_date_from_string (note.updated_at)) {
            css_classes = { "note-date" },
            halign = END,
            hexpand = true,
            valign = CENTER
        };
        
        footer_box.append (view_toggle_button);
        footer_box.append (date_label);
        
        // Assemble card
        card_box.append (header_box);
        card_box.append (content_label);
        card_box.append (footer_box);

        // Wrap in padding container
        var padding_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_start = 4,
            margin_end = 4,
            margin_top = 4,
            margin_bottom = 4
        };
        padding_box.append (card_box);
        
        child = padding_box;

        // Hover controller for showing action buttons
        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.enter.connect ((x, y) => {
            action_revealer.reveal_child = true;
            add_css_class ("note-card-hover");
        });
        motion_controller.leave.connect (() => {
            action_revealer.reveal_child = false;
            remove_css_class ("note-card-hover");
        });
        add_controller (motion_controller);
        
        // Right-click context menu
        setup_context_menu ();

        note.updated.connect (update_ui);
    }
    
    private void toggle_expansion () {
        is_expanded = !is_expanded;
        expansion_changed (is_expanded);
    }
    
    private void setup_context_menu () {
        // Right-click gesture
        var right_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        right_click.pressed.connect ((n_press, x, y) => {
            show_context_menu ((int) x, (int) y);
        });
        add_controller (right_click);
    }
    
    private void show_context_menu (int x, int y) {
        // Clean up old popover if exists
        if (context_popover != null) {
            context_popover.unparent ();
            context_popover = null;
        }
        
        // Create menu items
        var edit_item = new Widgets.ContextMenu.MenuItem (_("Edit Note"), "edit-symbolic");
        var view_item = new Widgets.ContextMenu.MenuItem (
            _is_expanded ? _("View Less") : _("View More"), 
            _is_expanded ? "view-conceal-symbolic" : "view-reveal-symbolic"
        );
        var copy_item = new Widgets.ContextMenu.MenuItem (_("Copy Content"), "edit-copy-symbolic");
        var delete_item = new Widgets.ContextMenu.MenuItem (_("Delete Note"), "user-trash-symbolic");
        delete_item.add_css_class ("menu-item-danger");
        
        var menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_box.margin_top = menu_box.margin_bottom = 3;
        menu_box.append (edit_item);
        menu_box.append (view_item);
        menu_box.append (copy_item);
        menu_box.append (new Widgets.ContextMenu.MenuSeparator ());
        menu_box.append (delete_item);
        
        context_popover = new Gtk.Popover () {
            has_arrow = true,
            child = menu_box,
            position = Gtk.PositionType.BOTTOM,
            width_request = 200
        };
        
        context_popover.set_parent (this);
        context_popover.pointing_to = { x, y, 1, 1 };
        context_popover.popup ();
        
        // Connect signals
        edit_item.clicked.connect (() => {
            context_popover.popdown ();
            edit_requested ();
        });
        
        view_item.clicked.connect (() => {
            context_popover.popdown ();
            toggle_expansion ();
        });
        
        copy_item.clicked.connect (() => {
            context_popover.popdown ();
            var clipboard = get_clipboard ();
            clipboard.set_text (note.content);
            Services.EventBus.get_default ().send_toast (
                Util.get_default ().create_toast (_("Content copied"))
            );
        });
        
        delete_item.clicked.connect (() => {
            context_popover.popdown ();
            show_delete_dialog ();
        });
    }
    
    private void show_delete_dialog () {
        var dialog = new Adw.AlertDialog (
            _("Delete Note?"),
            _("Are you sure you want to delete \"%s\"? This action cannot be undone.").printf (note.title)
        );
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("delete", _("Delete"));
        dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";
        
        dialog.response.connect ((response) => {
            if (response == "delete") {
                Services.Store.instance ().delete_note (note);
            }
        });
        
        dialog.present ((Gtk.Window) get_root ());
    }
    
    private void update_expansion_state () {
        // Get toggle button children
        var toggle_box = view_toggle_button.child as Gtk.Box;
        Gtk.Label? toggle_label = null;
        Gtk.Image? toggle_icon = null;
        
        if (toggle_box != null) {
            var child = toggle_box.get_first_child ();
            while (child != null) {
                if (child is Gtk.Label) {
                    toggle_label = child as Gtk.Label;
                } else if (child is Gtk.Image) {
                    toggle_icon = child as Gtk.Image;
                }
                child = child.get_next_sibling ();
            }
        }
        
        if (_is_expanded) {
            // Show full content - no ellipsis, enable wrapping
            content_label.ellipsize = Pango.EllipsizeMode.NONE;
            content_label.wrap = true;
            content_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            content_label.max_width_chars = -1;
            content_label.lines = -1;
            content_label.label = note.content;
            content_label.add_css_class ("note-preview-expanded");
            
            // Update toggle button
            if (toggle_label != null) {
                toggle_label.label = _("View Less");
            }
            if (toggle_icon != null) {
                toggle_icon.icon_name = "go-up-symbolic";
            }
            
            view_toggle_button.add_css_class ("note-view-toggle-active");
            add_css_class ("note-card-expanded");
        } else {
            // Show truncated preview
            content_label.ellipsize = Pango.EllipsizeMode.END;
            content_label.wrap = false;
            content_label.max_width_chars = 80;
            content_label.lines = 2;
            content_label.label = note.get_preview ();
            content_label.remove_css_class ("note-preview-expanded");
            
            // Update toggle button
            if (toggle_label != null) {
                toggle_label.label = _("View More");
            }
            if (toggle_icon != null) {
                toggle_icon.icon_name = "go-down-symbolic";
            }
            
            view_toggle_button.remove_css_class ("note-view-toggle-active");
            remove_css_class ("note-card-expanded");
        }
    }

    private void update_ui () {
        title_label.label = note.title;
        if (_is_expanded) {
            content_label.label = note.content;
        } else {
            content_label.label = note.get_preview ();
        }
        date_label.label = Utils.Datetime.get_relative_date_from_string (note.updated_at);
    }
}
