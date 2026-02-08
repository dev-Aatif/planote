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
 * Input validation utilities for preventing constraint violations
 * and ensuring data integrity throughout the application.
 */
namespace Utils.Validation {
    
    /** Maximum allowed content length (100KB) */
    public const int MAX_CONTENT_LENGTH = 100000;
    
    /** Maximum allowed title length */
    public const int MAX_TITLE_LENGTH = 1000;
    
    /** Maximum allowed ID length */
    public const int MAX_ID_LENGTH = 64;
    
    /**
     * Validate an ID string.
     * @param id The ID to validate
     * @return true if valid
     */
    public bool is_valid_id (string? id) {
        if (id == null || id.length == 0) {
            return false;
        }
        if (id.length > MAX_ID_LENGTH) {
            return false;
        }
        return true;
    }
    
    /**
     * Validate priority value (must be 1-4).
     * Todoist priorities: 1 (highest) to 4 (lowest/none)
     * @param priority The priority value to validate
     * @return true if valid
     */
    public bool is_valid_priority (int priority) {
        return priority >= 1 && priority <= 4;
    }
    
    /**
     * Normalize priority to valid range.
     * @param priority Input priority
     * @return Normalized priority (clamped to 1-4)
     */
    public int normalize_priority (int priority) {
        if (priority < 1) return 4;  // Default to no priority
        if (priority > 4) return 4;
        return priority;
    }
    
    /**
     * Sanitize content string for safe storage.
     * Handles null, empty, and oversized content.
     * @param content The content to sanitize
     * @return Sanitized content
     */
    public string sanitize_content (string? content) {
        if (content == null) {
            return "";
        }
        if (content.length > MAX_CONTENT_LENGTH) {
            return content.substring (0, MAX_CONTENT_LENGTH);
        }
        return content;
    }
    
    /**
     * Sanitize a title string.
     * @param title The title to sanitize
     * @param default_title Default value if title is empty
     * @return Sanitized title
     */
    public string sanitize_title (string? title, string default_title = "Untitled") {
        if (title == null || title.strip ().length == 0) {
            return default_title;
        }
        if (title.length > MAX_TITLE_LENGTH) {
            return title.substring (0, MAX_TITLE_LENGTH);
        }
        return title;
    }
    
    /**
     * Check for circular parent-child reference.
     * @param id The item's ID
     * @param parent_id The proposed parent ID
     * @return true if the reference is valid (not circular)
     */
    public bool check_circular_reference (string id, string? parent_id) {
        if (parent_id == null || parent_id == "") {
            return true;  // No parent is valid
        }
        return id != parent_id;  // Self-reference is invalid
    }
    
    /**
     * Validate a title is not empty or whitespace-only.
     * @param title The title to validate
     * @return true if valid
     */
    public bool is_valid_title (string? title) {
        if (title == null || title.strip ().length == 0) {
            return false;
        }
        if (title.length > MAX_TITLE_LENGTH) {
            return false;
        }
        return true;
    }
    
    /**
     * Validate email format (basic validation).
     * @param email The email to validate
     * @return true if appears to be valid email format
     */
    public bool is_valid_email (string? email) {
        if (email == null || email.length == 0) {
            return false;
        }
        if (!("@" in email)) {
            return false;
        }
        var parts = email.split ("@");
        if (parts.length != 2) {
            return false;
        }
        if (parts[0].length == 0 || parts[1].length < 3) {
            return false;
        }
        if (!("." in parts[1])) {
            return false;
        }
        return true;
    }
    
    /**
     * Validate ISO date string format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS).
     * @param date_str The date string to validate
     * @return true if valid or empty (empty means no date)
     */
    public bool is_valid_date_string (string? date_str) {
        if (date_str == null || date_str.length == 0) {
            return true;  // Empty date is valid (means no date set)
        }
        if (date_str.length < 10) {
            return false;
        }
        // Basic format check: YYYY-MM-DD
        if (date_str[4] != '-' || date_str[7] != '-') {
            return false;
        }
        // Check year, month, day are digits
        for (int i = 0; i < 4; i++) {
            if (!date_str[i].isdigit ()) return false;
        }
        for (int i = 5; i < 7; i++) {
            if (!date_str[i].isdigit ()) return false;
        }
        for (int i = 8; i < 10; i++) {
            if (!date_str[i].isdigit ()) return false;
        }
        return true;
    }
    
    /**
     * Validate color hex string.
     * @param color The color string to validate
     * @return true if valid hex color (#RRGGBB or #RGB)
     */
    public bool is_valid_color (string? color) {
        if (color == null || color.length == 0) {
            return true;  // Empty is valid (means default)
        }
        if (!color.has_prefix ("#")) {
            return false;
        }
        if (color.length != 4 && color.length != 7) {
            return false;
        }
        for (int i = 1; i < color.length; i++) {
            if (!color[i].isxdigit ()) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * Sanitize a color string to valid format.
     * @param color Input color
     * @param default_color Default if invalid
     * @return Valid color string
     */
    public string sanitize_color (string? color, string default_color = "#3584E4") {
        if (is_valid_color (color)) {
            return color ?? default_color;
        }
        return default_color;
    }
}
