/*
 * Unit Tests for Input Validation
 * Tests input sanitization, bounds checking, and constraint validation
 */

/*
 * ID Validation Tests
 */
void test_valid_id_formats () {
    // Valid IDs
    assert (is_valid_id ("abc123") == true);
    assert (is_valid_id ("a") == true);
    assert (is_valid_id ("12345678") == true);
    assert (is_valid_id ("uuid-style-id-here") == true);
    assert (is_valid_id ("com.example.test") == true);
    
    print ("  ✓ test_valid_id_formats passed\n");
}

void test_invalid_id_formats () {
    // Invalid IDs
    assert (is_valid_id ("") == false);
    assert (is_valid_id (null) == false);
    
    // Too long (> 64 chars)
    var long_id = new StringBuilder ();
    for (int i = 0; i < 100; i++) {
        long_id.append ("x");
    }
    assert (is_valid_id (long_id.str) == false);
    
    print ("  ✓ test_invalid_id_formats passed\n");
}

/*
 * Priority Validation Tests
 */
void test_valid_priorities () {
    assert (is_valid_priority (1) == true);  // PRIORITY_1 (high)
    assert (is_valid_priority (2) == true);  // PRIORITY_2 (medium)
    assert (is_valid_priority (3) == true);  // PRIORITY_3 (low)
    assert (is_valid_priority (4) == true);  // PRIORITY_4 (none)
    
    print ("  ✓ test_valid_priorities passed\n");
}

void test_invalid_priorities () {
    assert (is_valid_priority (0) == false);
    assert (is_valid_priority (-1) == false);
    assert (is_valid_priority (5) == false);
    assert (is_valid_priority (100) == false);
    assert (is_valid_priority (int.MIN) == false);
    assert (is_valid_priority (int.MAX) == false);
    
    print ("  ✓ test_invalid_priorities passed\n");
}

/*
 * Content Sanitization Tests
 */
void test_null_content_sanitization () {
    string? result = sanitize_content (null);
    assert (result == "");
    
    print ("  ✓ test_null_content_sanitization passed\n");
}

void test_empty_content_sanitization () {
    string result = sanitize_content ("");
    assert (result == "");
    
    print ("  ✓ test_empty_content_sanitization passed\n");
}

void test_normal_content_unchanged () {
    string result = sanitize_content ("Normal content here");
    assert (result == "Normal content here");
    
    print ("  ✓ test_normal_content_unchanged passed\n");
}

void test_large_content_truncation () {
    // Create content larger than MAX_CONTENT_LENGTH
    var builder = new StringBuilder ();
    for (int i = 0; i < 15000; i++) {
        builder.append ("0123456789");  // 150KB
    }
    
    string result = sanitize_content (builder.str);
    assert (result.length == MAX_CONTENT_LENGTH);
    
    print ("  ✓ test_large_content_truncation passed\n");
}

void test_whitespace_content_preserved () {
    string result = sanitize_content ("   spaces   \n\ttabs\n");
    assert (result == "   spaces   \n\ttabs\n");
    
    print ("  ✓ test_whitespace_content_preserved passed\n");
}

/*
 * Circular Reference Detection Tests
 */
void test_self_reference_detected () {
    // An item referencing itself as parent
    assert (check_circular_reference ("item-1", "item-1") == false);
    
    print ("  ✓ test_self_reference_detected passed\n");
}

void test_valid_parent_reference () {
    // Different parent ID is valid
    assert (check_circular_reference ("item-1", "item-2") == true);
    assert (check_circular_reference ("a", "b") == true);
    
    print ("  ✓ test_valid_parent_reference passed\n");
}

void test_empty_parent_reference () {
    // Empty parent_id is not valid (no parent)
    assert (check_circular_reference ("item-1", "") == false);
    
    print ("  ✓ test_empty_parent_reference passed\n");
}

/*
 * Title Validation Tests
 */
void test_valid_titles () {
    assert (is_valid_title ("My Title") == true);
    assert (is_valid_title ("A") == true);
    assert (is_valid_title ("Title with 123 numbers") == true);
    assert (is_valid_title ("日本語タイトル") == true);
    
    print ("  ✓ test_valid_titles passed\n");
}

void test_invalid_titles () {
    assert (is_valid_title ("") == false);
    assert (is_valid_title (null) == false);
    assert (is_valid_title ("   ") == false);  // Whitespace only
    
    // Too long
    var long_title = new StringBuilder ();
    for (int i = 0; i < 200; i++) {
        long_title.append ("word ");
    }
    assert (is_valid_title (long_title.str) == false);
    
    print ("  ✓ test_invalid_titles passed\n");
}

/*
 * Email Validation Tests (for Todoist accounts)
 */
void test_valid_emails () {
    assert (is_valid_email ("user@example.com") == true);
    assert (is_valid_email ("user.name@domain.org") == true);
    assert (is_valid_email ("user+tag@example.co.uk") == true);
    
    print ("  ✓ test_valid_emails passed\n");
}

void test_invalid_emails () {
    assert (is_valid_email ("") == false);
    assert (is_valid_email ("notanemail") == false);
    assert (is_valid_email ("@nodomain") == false);
    assert (is_valid_email ("no@tld") == false);
    
    print ("  ✓ test_invalid_emails passed\n");
}

/*
 * Date String Validation Tests
 */
void test_valid_date_strings () {
    assert (is_valid_date_string ("2024-03-15") == true);
    assert (is_valid_date_string ("2024-12-31T23:59:59") == true);
    
    print ("  ✓ test_valid_date_strings passed\n");
}

void test_invalid_date_strings () {
    assert (is_valid_date_string ("") == true);  // Empty is valid (no date)
    assert (is_valid_date_string ("not-a-date") == false);
    assert (is_valid_date_string ("2024/03/15") == false);  // Wrong format
    
    print ("  ✓ test_invalid_date_strings passed\n");
}

/* 
 * Validation Helper Functions
 * These would ideally be in Utils/Validation.vala
 */

const int MAX_CONTENT_LENGTH = 100000;
const int MAX_TITLE_LENGTH = 1000;
const int MAX_ID_LENGTH = 64;

bool is_valid_id (string? id) {
    if (id == null || id.length == 0) {
        return false;
    }
    if (id.length > MAX_ID_LENGTH) {
        return false;
    }
    return true;
}

bool is_valid_priority (int priority) {
    return priority >= 1 && priority <= 4;
}

string sanitize_content (string? content) {
    if (content == null) {
        return "";
    }
    if (content.length > MAX_CONTENT_LENGTH) {
        return content.substring (0, MAX_CONTENT_LENGTH);
    }
    return content;
}

bool check_circular_reference (string id, string parent_id) {
    if (parent_id == "" || parent_id == null) {
        return false;  // No parent reference
    }
    return id != parent_id;
}

bool is_valid_title (string? title) {
    if (title == null || title.strip ().length == 0) {
        return false;
    }
    if (title.length > MAX_TITLE_LENGTH) {
        return false;
    }
    return true;
}

bool is_valid_email (string? email) {
    if (email == null || email.length == 0) {
        return false;
    }
    // Basic email validation
    if (!("@" in email)) {
        return false;
    }
    var parts = email.split ("@");
    if (parts.length != 2) {
        return false;
    }
    if (parts[1].length < 3 || !("." in parts[1])) {
        return false;
    }
    return true;
}

bool is_valid_date_string (string? date_str) {
    if (date_str == null || date_str.length == 0) {
        return true;  // Empty date is valid (no date set)
    }
    // Basic ISO date format check
    if (date_str.length < 10) {
        return false;
    }
    // Check for YYYY-MM-DD format
    if (date_str[4] != '-' || date_str[7] != '-') {
        return false;
    }
    return true;
}

void main (string[] args) {
    Test.init (ref args);
    
    print ("\n=== Validation Unit Tests ===\n\n");
    
    // ID Validation
    Test.add_func ("/validation/id/valid_formats", test_valid_id_formats);
    Test.add_func ("/validation/id/invalid_formats", test_invalid_id_formats);
    
    // Priority Validation
    Test.add_func ("/validation/priority/valid", test_valid_priorities);
    Test.add_func ("/validation/priority/invalid", test_invalid_priorities);
    
    // Content Sanitization
    Test.add_func ("/validation/content/null", test_null_content_sanitization);
    Test.add_func ("/validation/content/empty", test_empty_content_sanitization);
    Test.add_func ("/validation/content/normal", test_normal_content_unchanged);
    Test.add_func ("/validation/content/large", test_large_content_truncation);
    Test.add_func ("/validation/content/whitespace", test_whitespace_content_preserved);
    
    // Circular Reference
    Test.add_func ("/validation/circular/self", test_self_reference_detected);
    Test.add_func ("/validation/circular/valid", test_valid_parent_reference);
    Test.add_func ("/validation/circular/empty", test_empty_parent_reference);
    
    // Title Validation
    Test.add_func ("/validation/title/valid", test_valid_titles);
    Test.add_func ("/validation/title/invalid", test_invalid_titles);
    
    // Email Validation
    Test.add_func ("/validation/email/valid", test_valid_emails);
    Test.add_func ("/validation/email/invalid", test_invalid_emails);
    
    // Date String Validation
    Test.add_func ("/validation/date/valid", test_valid_date_strings);
    Test.add_func ("/validation/date/invalid", test_invalid_date_strings);
    
    Test.run ();
    
    print ("\n=== All Validation Tests Completed ===\n");
}
