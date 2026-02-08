/*
 * Copyright © 2026 Planote Contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.NotesToday : Objects.Filters.Priority {
    private static NotesToday _instance;
    public new static NotesToday get_default () {
        if (_instance == null) {
            _instance = new NotesToday ();
        }
        return _instance;
    }

    public NotesToday () {
        Object (
            view_id: "notes-today",
            name: _("Notes Today"),
            icon_name: "go-today-symbolic",
            color: "green"
        );
    }
}
