/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.AllNotes : Objects.Filters.Priority {
    private static AllNotes _instance;
    public new static AllNotes get_default () {
        if (_instance == null) {
            _instance = new AllNotes ();
        }
        return _instance;
    }

    public AllNotes () {
        Object (
            view_id: "all-notes",
            name: _("All Notes"),
            icon_name: "note-multiple-symbolic",
            color: "blue"
        );
    }
}
