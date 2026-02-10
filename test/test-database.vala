/*
 * Unit Tests for Database Layer
 * Tests CRUD operations, transactions, edge cases, and constraint handling
 */

private string test_db_path;
private Services.Database test_db;

void setup_test_database () {
    // Create isolated test database
    test_db_path = Path.build_filename (Environment.get_tmp_dir (), "planote_test_%d.db".printf ((int) GLib.get_real_time ()));
    
    // Initialize test database instance
    test_db = new Services.Database.with_path (test_db_path);
    test_db.init_database ();
}

void teardown_test_database () {
    // Clean up test database
    if (FileUtils.test (test_db_path, FileTest.EXISTS)) {
        FileUtils.remove (test_db_path);
    }
    // Also remove WAL files if present
    FileUtils.remove (test_db_path + "-wal");
    FileUtils.remove (test_db_path + "-shm");
}

/*
 * Project CRUD Tests
 */
void test_insert_project () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "test-project-001";
    project.name = "Test Project";
    project.color = "#FF5733";
    
    bool result = test_db.insert_project (project);
    assert (result == true);
    
    // Verify retrieval
    var projects = test_db.get_projects_collection ();
    bool found = false;
    foreach (var p in projects) {
        if (p.id == "test-project-001") {
            found = true;
            assert (p.name == "Test Project");
            assert (p.color == "#FF5733");
        }
    }
    assert (found == true);
    
    teardown_test_database ();
    print ("  ✓ test_insert_project passed\n");
}

void test_update_project () {
    setup_test_database ();
    
    // Insert
    var project = new Objects.Project ();
    project.id = "test-project-002";
    project.name = "Original Name";
    test_db.insert_project (project);
    
    // Update
    project.name = "Updated Name";
    project.color = "#00FF00";
    bool result = test_db.update_project (project);
    assert (result == true);
    
    // Verify
    var projects = test_db.get_projects_collection ();
    foreach (var p in projects) {
        if (p.id == "test-project-002") {
            assert (p.name == "Updated Name");
            assert (p.color == "#00FF00");
        }
    }
    
    teardown_test_database ();
    print ("  ✓ test_update_project passed\n");
}

void test_delete_project () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "test-project-003";
    project.name = "To Be Deleted";
    test_db.insert_project (project);
    
    bool result = test_db.delete_project (project);
    assert (result == true);
    
    // Verify not in collection
    var projects = test_db.get_projects_collection ();
    foreach (var p in projects) {
        assert (p.id != "test-project-003");
    }
    
    teardown_test_database ();
    print ("  ✓ test_delete_project passed\n");
}

/*
 * Item CRUD Tests
 */
void test_insert_item () {
    setup_test_database ();
    
    // First create a project for the item
    var project = new Objects.Project ();
    project.id = "item-test-project";
    project.name = "Item Test Project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "test-item-001";
    item.content = "Test Task Content";
    item.description = "Test description";
    item.project_id = "item-test-project";
    item.priority = 2;
    
    bool result = test_db.insert_item (item);
    assert (result == true);
    
    // Verify
    var retrieved = test_db.get_item_by_id ("test-item-001");
    assert (retrieved.content == "Test Task Content");
    assert (retrieved.priority == 2);
    
    teardown_test_database ();
    print ("  ✓ test_insert_item passed\n");
}

void test_update_item () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "item-update-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "test-item-002";
    item.content = "Original Content";
    item.project_id = "item-update-project";
    test_db.insert_item (item);
    
    // Update
    item.content = "Updated Content";
    item.checked = true;
    bool result = test_db.update_item (item);
    assert (result == true);
    
    // Verify
    var retrieved = test_db.get_item_by_id ("test-item-002");
    assert (retrieved.content == "Updated Content");
    assert (retrieved.checked == true);
    
    teardown_test_database ();
    print ("  ✓ test_update_item passed\n");
}

void test_delete_item () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "item-delete-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "test-item-003";
    item.content = "To Be Deleted";
    item.project_id = "item-delete-project";
    test_db.insert_item (item);
    
    bool result = test_db.delete_item (item);
    assert (result == true);
    
    // Verify - get_item_by_id returns empty item when not found
    var retrieved = test_db.get_item_by_id ("test-item-003");
    assert (retrieved.id == "" || retrieved.id == null);
    
    teardown_test_database ();
    print ("  ✓ test_delete_item passed\n");
}

/*
 * Edge Cases and Constraint Tests
 */
void test_duplicate_id_handling () {
    setup_test_database ();
    
    var project1 = new Objects.Project ();
    project1.id = "duplicate-id";
    project1.name = "First Project";
    test_db.insert_project (project1);
    
    // Try to insert another with same ID
    var project2 = new Objects.Project ();
    project2.id = "duplicate-id";
    project2.name = "Second Project";
    bool result = test_db.insert_project (project2);
    
    // INSERT OR IGNORE should succeed without insert
    assert (result == true);
    
    // Verify first project is unchanged
    var projects = test_db.get_projects_collection ();
    int count = 0;
    foreach (var p in projects) {
        if (p.id == "duplicate-id") {
            count++;
            assert (p.name == "First Project"); // Original data kept
        }
    }
    assert (count == 1);
    
    teardown_test_database ();
    print ("  ✓ test_duplicate_id_handling passed\n");
}

void test_empty_content_handling () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "empty-content-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "empty-content-item";
    item.content = ""; // Empty content
    item.project_id = "empty-content-project";
    
    bool result = test_db.insert_item (item);
    assert (result == true);
    
    var retrieved = test_db.get_item_by_id ("empty-content-item");
    assert (retrieved.content == "");
    
    teardown_test_database ();
    print ("  ✓ test_empty_content_handling passed\n");
}

void test_special_characters_in_content () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "special-chars-project";
    test_db.insert_project (project);
    
    // Test SQL injection attempt (should be safe with prepared statements)
    var item = new Objects.Item ();
    item.id = "special-chars-item";
    item.content = "'; DROP TABLE Items; --";
    item.description = "Test with \"quotes\" and 'apostrophes'";
    item.project_id = "special-chars-project";
    
    bool result = test_db.insert_item (item);
    assert (result == true);
    
    var retrieved = test_db.get_item_by_id ("special-chars-item");
    assert (retrieved.content == "'; DROP TABLE Items; --");
    
    teardown_test_database ();
    print ("  ✓ test_special_characters_in_content passed\n");
}

void test_unicode_content () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "unicode-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "unicode-item";
    item.content = "日本語テスト 🎉 émojis и кириллица";
    item.project_id = "unicode-project";
    
    bool result = test_db.insert_item (item);
    assert (result == true);
    
    var retrieved = test_db.get_item_by_id ("unicode-item");
    assert (retrieved.content == "日本語テスト 🎉 émojis и кириллица");
    
    teardown_test_database ();
    print ("  ✓ test_unicode_content passed\n");
}

void test_large_content () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "large-content-project";
    test_db.insert_project (project);
    
    // Create 100KB of content
    var builder = new StringBuilder ();
    for (int i = 0; i < 10000; i++) {
        builder.append ("0123456789");
    }
    
    var item = new Objects.Item ();
    item.id = "large-content-item";
    item.content = builder.str;
    item.project_id = "large-content-project";
    
    bool result = test_db.insert_item (item);
    assert (result == true);
    
    var retrieved = test_db.get_item_by_id ("large-content-item");
    assert (retrieved.content.length == 100000);
    
    teardown_test_database ();
    print ("  ✓ test_large_content passed\n");
}

/*
 * Soft Delete Tests
 */
void test_soft_delete_item () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "soft-delete-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "soft-delete-item";
    item.content = "Soft Delete Test";
    item.project_id = "soft-delete-project";
    test_db.insert_item (item);
    
    // Soft delete by setting is_deleted = true
    item.is_deleted = true;
    test_db.update_item (item);
    
    // get_items_collection filters out is_deleted = 1
    var items = test_db.get_items_collection ();
    foreach (var i in items) {
        assert (i.id != "soft-delete-item");
    }
    
    // But direct query by ID should still find it
    var retrieved = test_db.get_item_by_id ("soft-delete-item");
    assert (retrieved.id == "soft-delete-item");
    assert (retrieved.is_deleted == true);
    
    teardown_test_database ();
    print ("  ✓ test_soft_delete_item passed\n");
}

/*
 * Label Tests
 */
void test_label_crud () {
    setup_test_database ();
    
    var label = new Objects.Label ();
    label.id = "test-label-001";
    label.name = "Test Label";
    label.color = "#FF0000";
    
    // Insert
    bool result = test_db.insert_label (label);
    assert (result == true);
    
    // Retrieve
    var labels = test_db.get_labels_collection ();
    bool found = false;
    foreach (var l in labels) {
        if (l.id == "test-label-001") {
            found = true;
            assert (l.name == "Test Label");
        }
    }
    assert (found == true);
    
    // Update
    label.name = "Updated Label";
    test_db.update_label (label);
    
    // Delete
    result = test_db.delete_label (label);
    assert (result == true);
    
    teardown_test_database ();
    print ("  ✓ test_label_crud passed\n");
}

/*
 * Section Tests
 */
void test_section_crud () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "section-test-project";
    test_db.insert_project (project);
    
    var section = new Objects.Section ();
    section.id = "test-section-001";
    section.name = "Test Section";
    section.project_id = "section-test-project";
    
    // Insert
    bool result = test_db.insert_section (section);
    assert (result == true);
    
    // Retrieve
    var sections = test_db.get_sections_collection ();
    bool found = false;
    foreach (var s in sections) {
        if (s.id == "test-section-001") {
            found = true;
            assert (s.name == "Test Section");
        }
    }
    assert (found == true);
    
    // Update
    section.name = "Updated Section";
    test_db.update_section (section);
    
    // Delete
    result = test_db.delete_section (section);
    assert (result == true);
    
    teardown_test_database ();
    print ("  ✓ test_section_crud passed\n");
}

/*
 * Note & Notebook Tests
 */
void test_notebook_crud () {
    setup_test_database ();
    
    // Create a source first (FK constraint on source_id)
    var source = new Objects.Source ();
    source.id = "test-source-notebook";
    source.display_name = "Test Source";
    test_db.insert_source (source);
    
    var notebook = new Objects.Notebook ();
    notebook.id = "test-notebook-001";
    notebook.name = "Test Notebook";
    notebook.color = "#00FF00";
    notebook.source_id = "test-source-notebook";
    
    bool result = test_db.insert_notebook (notebook);
    assert (result == true);
    
    var notebooks = test_db.get_notebooks_collection ();
    bool found = false;
    foreach (var n in notebooks) {
        if (n.id == "test-notebook-001") {
            found = true;
            assert (n.name == "Test Notebook");
        }
    }
    assert (found == true);
    
    teardown_test_database ();
    print ("  ✓ test_notebook_crud passed\n");
}

void test_note_crud () {
    setup_test_database ();
    
    // Create a source first (FK constraint on notebook's source_id)
    var source = new Objects.Source ();
    source.id = "test-source-note";
    source.display_name = "Test Source";
    test_db.insert_source (source);
    
    var notebook = new Objects.Notebook ();
    notebook.id = "note-test-notebook";
    notebook.name = "Note Test Notebook";
    notebook.source_id = "test-source-note";
    test_db.insert_notebook (notebook);
    
    var note = new Objects.Note ();
    note.id = "test-note-001";
    note.title = "Test Note Title";
    note.content = "Test note content with **markdown**";
    note.notebook_id = "note-test-notebook";
    note.source_id = "test-source-note";
    
    bool result = test_db.insert_note (note);
    assert (result == true);
    
    var notes = test_db.get_notes_collection ();
    bool found = false;
    foreach (var n in notes) {
        if (n.id == "test-note-001") {
            found = true;
            assert (n.title == "Test Note Title");
        }
    }
    assert (found == true);
    
    teardown_test_database ();
    print ("  ✓ test_note_crud passed\n");
}

/*
 * Reminder Tests
 */
void test_reminder_crud () {
    setup_test_database ();
    
    var project = new Objects.Project ();
    project.id = "reminder-test-project";
    test_db.insert_project (project);
    
    var item = new Objects.Item ();
    item.id = "reminder-test-item";
    item.project_id = "reminder-test-project";
    test_db.insert_item (item);
    
    var reminder = new Objects.Reminder ();
    reminder.id = "test-reminder-001";
    reminder.item_id = "reminder-test-item";
    
    bool result = test_db.insert_reminder (reminder);
    assert (result == true);
    
    var reminders = test_db.get_reminders_by_item_id ("reminder-test-item");
    assert (reminders.size == 1);
    assert (reminders[0].id == "test-reminder-001");
    
    teardown_test_database ();
    print ("  ✓ test_reminder_crud passed\n");
}

void main (string[] args) {
    Test.init (ref args);
    
    print ("\n=== Database Unit Tests ===\n\n");
    
    // Project Tests
    Test.add_func ("/database/project/insert", test_insert_project);
    Test.add_func ("/database/project/update", test_update_project);
    Test.add_func ("/database/project/delete", test_delete_project);
    
    // Item Tests
    Test.add_func ("/database/item/insert", test_insert_item);
    Test.add_func ("/database/item/update", test_update_item);
    Test.add_func ("/database/item/delete", test_delete_item);
    
    // Edge Cases
    Test.add_func ("/database/edge/duplicate_id", test_duplicate_id_handling);
    Test.add_func ("/database/edge/empty_content", test_empty_content_handling);
    Test.add_func ("/database/edge/special_chars", test_special_characters_in_content);
    Test.add_func ("/database/edge/unicode", test_unicode_content);
    Test.add_func ("/database/edge/large_content", test_large_content);
    
    // Soft Delete
    Test.add_func ("/database/softdelete/item", test_soft_delete_item);
    
    // Other Objects
    Test.add_func ("/database/label/crud", test_label_crud);
    Test.add_func ("/database/section/crud", test_section_crud);
    Test.add_func ("/database/notebook/crud", test_notebook_crud);
    Test.add_func ("/database/note/crud", test_note_crud);
    Test.add_func ("/database/reminder/crud", test_reminder_crud);
    
    Test.run ();
    
    print ("\n=== All Database Tests Completed ===\n");
}
