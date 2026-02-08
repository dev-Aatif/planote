/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.NotesPinboard : Objects.Filters.Priority {
    private static NotesPinboard _instance;
    public new static NotesPinboard get_default () {
        if (_instance == null) {
            _instance = new NotesPinboard ();
        }
        return _instance;
    }

    public NotesPinboard () {
        Object (
            view_id: "notes-pinboard",
            name: _("Notes Pinboard"),
            icon_name: "pin-symbolic",
            color: "red"
        );
    }
}
