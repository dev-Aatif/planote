/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.NotesLabels : Objects.Filters.Priority {
    private static NotesLabels _instance;
    public new static NotesLabels get_default () {
        if (_instance == null) {
            _instance = new NotesLabels ();
        }
        return _instance;
    }

    public NotesLabels () {
        Object (
            view_id: "notes-labels",
            name: _("Notes Labels"),
            icon_name: "tag-symbolic",
            color: "yellow"
        );
    }
}
