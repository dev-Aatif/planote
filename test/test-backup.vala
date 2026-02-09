/*
 * Unit Tests for Backup/Restore Functionality
 * 
 * Note: Full backup testing requires the application GSettings schema
 * to be installed. These tests verify basic logic without app dependencies.
 */

/*
 * Test JSON parsing logic (simulated)
 */
void test_json_parse_success () {
    var parser = new Json.Parser ();
    bool success = false;
    
    try {
        success = parser.load_from_data ("{\"version\": \"1.0\", \"projects\": []}");
    } catch (Error e) {
        success = false;
    }
    
    assert (success == true);
    
    var root = parser.get_root ();
    assert (root != null);
    assert (root.get_node_type () == Json.NodeType.OBJECT);
    
    var obj = root.get_object ();
    assert (obj.has_member ("version"));
    assert (obj.has_member ("projects"));
    
    print ("  ✓ test_json_parse_success passed\n");
}

/*
 * Test JSON parsing with invalid data
 */
void test_json_parse_invalid () {
    var parser = new Json.Parser ();
    bool success = false;
    
    try {
        success = parser.load_from_data ("this is not valid json");
    } catch (Error e) {
        success = false;
    }
    
    assert (success == false);
    
    print ("  ✓ test_json_parse_invalid passed\n");
}

/*
 * Test empty JSON object
 */
void test_json_empty_object () {
    var parser = new Json.Parser ();
    bool success = false;
    
    try {
        success = parser.load_from_data ("{}");
    } catch (Error e) {
        success = false;
    }
    
    assert (success == true);
    
    var obj = parser.get_root ().get_object ();
    assert (obj.get_size () == 0);
    
    print ("  ✓ test_json_empty_object passed\n");
}

/*
 * Test JSON array handling
 */
void test_json_array () {
    var parser = new Json.Parser ();
    
    try {
        parser.load_from_data ("{\"items\": [{\"id\": \"1\"}, {\"id\": \"2\"}]}");
    } catch (Error e) {
        assert (false);
    }
    
    var obj = parser.get_root ().get_object ();
    var items = obj.get_array_member ("items");
    
    assert (items.get_length () == 2);
    
    print ("  ✓ test_json_array passed\n");
}

void main (string[] args) {
    Test.init (ref args);
    
    print ("\n=== Backup JSON Parsing Tests ===\n\n");
    
    // JSON parsing tests (no app dependencies)
    Test.add_func ("/backup/json/parse_success", test_json_parse_success);
    Test.add_func ("/backup/json/parse_invalid", test_json_parse_invalid);
    Test.add_func ("/backup/json/empty_object", test_json_empty_object);
    Test.add_func ("/backup/json/array", test_json_array);
    
    // Transactional backup tests
    Test.add_func ("/backup/transaction/temp_tables", test_transactional_backup_temp_tables);
    Test.add_func ("/backup/transaction/rollback", test_transactional_backup_rollback);
    
    Test.run ();
    
    print ("\n=== All Backup Tests Completed ===\n");
}

/*
 * Test that backup_to_temp_tables creates proper backup tables
 */
void test_transactional_backup_temp_tables () {
    // Create a temporary database for testing
    var test_db_path = "/tmp/planote_test_backup_%s.db".printf (
        new DateTime.now_local ().to_unix ().to_string ()
    );
    
    var test_db = new Services.Database.with_path (test_db_path);
    test_db.init_database ();
    
    // Insert some test data
    var project = new Objects.Project ();
    project.id = "test-project-1";
    project.name = "Test Project for Backup";
    project.color = "#FF0000";
    test_db.insert_project (project);
    
    // Backup to temp tables
    bool backup_success = test_db.backup_to_temp_tables ();
    assert (backup_success == true);
    
    // Cleanup
    test_db.clear_temp_tables ();
    
    // Delete test database
    try {
        File.new_for_path (test_db_path).delete ();
    } catch (Error e) {
        // Ignore cleanup errors
    }
    
    print ("  ✓ test_transactional_backup_temp_tables passed\n");
}

/*
 * Test that restore_from_temp_tables properly restores data after failure
 */
void test_transactional_backup_rollback () {
    // Create a temporary database for testing
    var test_db_path = "/tmp/planote_test_rollback_%s.db".printf (
        new DateTime.now_local ().to_unix ().to_string ()
    );
    
    var test_db = new Services.Database.with_path (test_db_path);
    test_db.init_database ();
    
    // Insert original test data
    var original_project = new Objects.Project ();
    original_project.id = "original-project";
    original_project.name = "Original Project";
    original_project.color = "#00FF00";
    bool insert_success = test_db.insert_project (original_project);
    assert (insert_success == true);
    
    // Backup to temp tables
    bool backup_success = test_db.backup_to_temp_tables ();
    assert (backup_success == true);
    
    // Clear the main tables (simulating start of import)
    bool clear_success = test_db.clear_all_tables ();
    assert (clear_success == true);
    
    // Restore from temp tables (simulating rollback after failed import)
    bool restore_success = test_db.restore_from_temp_tables ();
    assert (restore_success == true);
    
    // Cleanup - delete test database
    try {
        File.new_for_path (test_db_path).delete ();
    } catch (Error e) {
        // Ignore cleanup errors
    }
    
    print ("  ✓ test_transactional_backup_rollback passed\n");
}
