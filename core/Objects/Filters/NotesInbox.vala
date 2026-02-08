/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.NotesInbox : Objects.Filters.Priority {
    private static NotesInbox _instance;
    public new static NotesInbox get_default () {
        if (_instance == null) {
            _instance = new NotesInbox ();
        }
        return _instance;
    }

    public NotesInbox () {
        Object (
            view_id: "notes-inbox",
            name: _("Notes Inbox"),
            icon_name: "mail-inbox-symbolic",
            color: "blue"
        );
    }
}
