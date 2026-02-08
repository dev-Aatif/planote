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
    
    Test.run ();
    
    print ("\n=== All Backup Tests Completed ===\n");
}
