/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.NotesArchived : Objects.Filters.Priority {
    private static NotesArchived _instance;
    public new static NotesArchived get_default () {
        if (_instance == null) {
            _instance = new NotesArchived ();
        }
        return _instance;
    }

    public NotesArchived () {
        Object (
            view_id: "notes-archived",
            name: _("Archived Notes"),
            icon_name: "user-trash-symbolic",
            color: "grey"
        );
    }
}
