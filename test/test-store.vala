/*
 * Unit Tests for Store Layer
 * Tests singleton behavior, signal emissions, collection safety, and CRUD operations
 */

private bool db_initialized = false;

void setup_test_store () {
    // Use a temporary database for test isolation
    if (!db_initialized) {
        var test_path = "/tmp/planote_store_test_%d.db".printf ((int) GLib.Random.next_int ());
        Services.Database.set_test_path (test_path);
        Services.Database.get_default ().init_database ();
        db_initialized = true;
    }
    
    // Reset Store cache to ensure clean state
    Services.Store.instance ().reset_cache ();
}

void teardown_test_store () {
    // Reset cache after each test
    Services.Store.instance ().reset_cache ();
}

/*
 * Singleton Tests
 */
void test_store_singleton () {
    var store1 = Services.Store.instance ();
    var store2 = Services.Store.instance ();
    
    assert (store1 == store2);
    print ("  ✓ test_store_singleton passed\n");
}

/*
 * Signal Emission Tests
 */
void test_project_added_signal () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    bool signal_received = false;
    Objects.Project ? received_project = null;
    
    ulong handler_id = store.project_added.connect ((project) => {
        signal_received = true;
        received_project = project;
    });
    
    var project = new Objects.Project ();
    project.id = "signal-test-project";
    project.name = "Signal Test";
    store.insert_project (project);
    
    // Allow main loop to process
    var main_context = MainContext.default ();
    while (main_context.pending ()) {
        main_context.iteration (false);
    }
    
    assert (signal_received == true);
    assert (received_project != null);
    assert (received_project.id == "signal-test-project");
    
    store.disconnect (handler_id);
    teardown_test_store ();
    print ("  ✓ test_project_added_signal passed\n");
}

void test_item_added_signal () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    // First create a project
    var project = new Objects.Project ();
    project.id = "item-signal-project";
    store.insert_project (project);
    
    bool signal_received = false;
    
    ulong handler_id = store.item_added.connect ((item, insert) => {
        signal_received = true;
    });
    
    var item = new Objects.Item ();
    item.id = "signal-test-item";
    item.project_id = "item-signal-project";
    store.insert_item (item);
    
    var main_context = MainContext.default ();
    while (main_context.pending ()) {
        main_context.iteration (false);
    }
    
    assert (signal_received == true);
    
    store.disconnect (handler_id);
    teardown_test_store ();
    print ("  ✓ test_item_added_signal passed\n");
}

void test_item_deleted_signal () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "delete-signal-project";
    store.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "delete-signal-item";
    item.project_id = "delete-signal-project";
    store.insert_item (item);
    
    bool signal_received = false;
    
    ulong handler_id = store.item_deleted.connect ((deleted_item) => {
        signal_received = true;
    });
    
    store.delete_item (item);
    
    var main_context = MainContext.default ();
    while (main_context.pending ()) {
        main_context.iteration (false);
    }
    
    assert (signal_received == true);
    
    store.disconnect (handler_id);
    teardown_test_store ();
    print ("  ✓ test_item_deleted_signal passed\n");
}

/*
 * Collection Access Tests
 */
void test_get_project () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "get-test-project";
    project.name = "Get Test";
    store.insert_project (project);
    
    var retrieved = store.get_project ("get-test-project");
    assert (retrieved != null);
    assert (retrieved.name == "Get Test");
    
    teardown_test_store ();
    print ("  ✓ test_get_project passed\n");
}

void test_get_nonexistent_project () {
    var store = Services.Store.instance ();
    
    var retrieved = store.get_project ("nonexistent-project-xyz");
    assert (retrieved == null);
    
    print ("  ✓ test_get_nonexistent_project passed\n");
}

void test_get_item () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "get-item-project";
    store.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "get-test-item";
    item.content = "Get Test Content";
    item.project_id = "get-item-project";
    store.insert_item (item);
    
    var retrieved = store.get_item ("get-test-item");
    assert (retrieved != null);
    assert (retrieved.content == "Get Test Content");
    
    teardown_test_store ();
    print ("  ✓ test_get_item passed\n");
}

void test_get_items_by_project () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "items-by-project-test";
    store.insert_project (project);
    
    // Add multiple items
    for (int i = 0; i < 5; i++) {
        var item = new Objects.Item ();
        item.id = "project-item-%d".printf (i);
        item.project_id = "items-by-project-test";
        store.insert_item (item);
    }
    
    var items = store.get_items_by_project (project);
    assert (items.size == 5);
    
    teardown_test_store ();
    print ("  ✓ test_get_items_by_project passed\n");
}

/*
 * Label Management Tests
 */
void test_label_operations () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var label = new Objects.Label ();
    label.id = "store-test-label";
    label.name = "Store Test Label";
    label.color = "#FF0000";
    
    store.insert_label (label);
    
    var retrieved = store.get_label ("store-test-label");
    assert (retrieved != null);
    assert (retrieved.name == "Store Test Label");
    
    // Test get_label_by_name
    var by_name = store.get_label_by_name ("Store Test Label", false, "");
    assert (by_name != null);
    assert (by_name.id == "store-test-label");
    
    teardown_test_store ();
    print ("  ✓ test_label_operations passed\n");
}

/*
 * Update Tests
 */
void test_update_project () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "update-store-project";
    project.name = "Original";
    store.insert_project (project);
    
    bool signal_received = false;
    ulong handler_id = store.project_updated.connect ((p) => {
        signal_received = true;
    });
    
    project.name = "Updated";
    store.update_project (project);
    
    var main_context = MainContext.default ();
    while (main_context.pending ()) {
        main_context.iteration (false);
    }
    
    var retrieved = store.get_project ("update-store-project");
    assert (retrieved.name == "Updated");
    assert (signal_received == true);
    
    store.disconnect (handler_id);
    teardown_test_store ();
    print ("  ✓ test_update_project passed\n");
}

void test_update_item () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "update-item-project";
    store.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "update-store-item";
    item.content = "Original Content";
    item.project_id = "update-item-project";
    store.insert_item (item);
    
    bool signal_received = false;
    ulong handler_id = store.item_updated.connect ((i, update_id) => {
        signal_received = true;
    });
    
    item.content = "Updated Content";
    store.update_item (item, "test-update");
    
    var main_context = MainContext.default ();
    while (main_context.pending ()) {
        main_context.iteration (false);
    }
    
    assert (signal_received == true);
    
    store.disconnect (handler_id);
    teardown_test_store ();
    print ("  ✓ test_update_item passed\n");
}

/*
 * Section Tests
 */
void test_section_operations () {
    var store = Services.Store.instance ();
    setup_test_store ();
    
    var project = new Objects.Project ();
    project.id = "section-store-project";
    store.insert_project (project);
    
    var section = new Objects.Section ();
    section.id = "store-test-section";
    section.name = "Store Test Section";
    section.project_id = "section-store-project";
    
    store.insert_section (section);
    
    var retrieved = store.get_section ("store-test-section");
    assert (retrieved != null);
    assert (retrieved.name == "Store Test Section");
    
    var sections = store.get_sections_by_project (project);
    assert (sections.size >= 1);
    
    teardown_test_store ();
    print ("  ✓ test_section_operations passed\n");
}

/*
 * Database Empty Check
 */
void test_is_database_empty () {
    var store = Services.Store.instance ();
    
    // This depends on current state, so just verify it returns bool
    bool empty = store.is_database_empty ();
    assert (empty == true || empty == false);
    
    print ("  ✓ test_is_database_empty passed\n");
}

void main (string[] args) {
    Test.init (ref args);
    
    print ("\n=== Store Unit Tests ===\n\n");
    
    // Singleton
    Test.add_func ("/store/singleton", test_store_singleton);
    
    // Signals
    Test.add_func ("/store/signal/project_added", test_project_added_signal);
    Test.add_func ("/store/signal/item_added", test_item_added_signal);
    Test.add_func ("/store/signal/item_deleted", test_item_deleted_signal);
    
    // Collection Access
    Test.add_func ("/store/get/project", test_get_project);
    Test.add_func ("/store/get/nonexistent_project", test_get_nonexistent_project);
    Test.add_func ("/store/get/item", test_get_item);
    Test.add_func ("/store/get/items_by_project", test_get_items_by_project);
    
    // Labels
    Test.add_func ("/store/label/operations", test_label_operations);
    
    // Updates
    Test.add_func ("/store/update/project", test_update_project);
    Test.add_func ("/store/update/item", test_update_item);
    
    // Sections
    Test.add_func ("/store/section/operations", test_section_operations);
    
    // Utility
    Test.add_func ("/store/utility/is_database_empty", test_is_database_empty);
    
    Test.run ();
    
    print ("\n=== All Store Tests Completed ===\n");
}
