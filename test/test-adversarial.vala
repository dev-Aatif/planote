/*
 * Test-Adversary: Chaos Engineering for Planote
 */

void setup_adversarial () {
    stdout.printf ("DEBUG: Entering setup_adversarial\n");
    string test_db_path = GLib.Environment.get_current_dir () + "/test_adversarial.db";
    stdout.printf ("DEBUG: DB Path: %s\n", test_db_path);
    GLib.FileUtils.unlink (test_db_path);
    
    stdout.printf ("DEBUG: Setting test path\n");
    Services.Database.set_test_path (test_db_path);
    
    stdout.printf ("DEBUG: initializing database\n");
    Services.Database.get_default ().init_database ();
    
    stdout.printf ("DEBUG: resetting cache\n");
    Services.Store.instance ().reset_cache ();
    
    // Create default project for tests
    var project = new Objects.Project ();
    project.id = "inbox";
    project.name = "Inbox";
    Services.Store.instance ().insert_project (project);
    
    stdout.printf ("DEBUG: setup complete\n");
}

void teardown_adversarial () {
     stdout.printf ("DEBUG: Teardown started\n");
     Services.Database.get_default ().close_database ();
     Services.Store.hard_reset (); 
     string test_db_path = GLib.Environment.get_current_dir () + "/test_adversarial.db";
     GLib.FileUtils.unlink (test_db_path);
     stdout.printf ("DEBUG: Teardown complete\n");
}

int main (string[] args) {
    stdout.printf ("DEBUG: Main started\n");
    Test.init (ref args);

    // Setup test environment
    GLib.Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    // TEST 1: Rapid Fire / Constraints
    /*
    Test.add_func ("/adversary/rapid_fire", () => { 
        setup_adversarial ();
        message ("Starting Rapid Fire Test...");
        
        int total_ops = 50;
        
        for (int i = 0; i < total_ops; i++) {
            var item = new Objects.Item ();
            item.title = "Rapid Item %d".printf (i);
            Services.Store.instance ().add_item (item);
            
            if (i % 10 == 0) {
                // Switch project simulation
                Services.Store.instance ().get_items_by_project ("proj_%d".printf (i % 5));
            }
        }
        
        message ("Rapid Fire Test Completed.");
        teardown_adversarial ();
    });
    */

    // TEST 2: Payload / Constraints
    Test.add_func ("/adversary/large_payload", () => {
         setup_adversarial ();
         message ("Starting Large Payload Test...");
         string huge_string = string.nfill (1024 * 1024, 'A'); // 1MB
         
         var item = new Objects.Item ();
         item.id = Uuid.string_random ();
         item.content = huge_string;
         item.project_id = "inbox";
         
         Services.Store.instance ().insert_item (item);
         
         var fetched = Services.Store.instance ().get_item (item.id);
         if (fetched != null) {
             stdout.printf ("DEBUG: Fetched length: %d\n", fetched.content.length);
         } else {
             stdout.printf ("DEBUG: Item rejected as expected\n");
         }
         assert (fetched == null);
         message ("Large Payload handled gracefully (rejected).");
         teardown_adversarial ();
    });
    
     Test.add_func ("/adversary/sql_injection", () => {
         setup_adversarial ();
         message ("Starting SQL Injection Test...");
         
         var item = new Objects.Item ();
         item.id = Uuid.string_random ();
         // Attempt to close the quote and delete the table
         item.content = "'); DROP TABLE Items; --"; 
         item.project_id = "inbox";
         
         Services.Store.instance ().insert_item (item);
         
         // Verify table still exists
         var item2 = new Objects.Item ();
         item2.id = Uuid.string_random ();
         item2.content = "Check";
         item2.project_id = "inbox";
         Services.Store.instance ().insert_item (item2);
         
         var fetched = Services.Store.instance ().get_item (item2.id);
         assert (fetched != null);
         message ("SQL Injection resisted.");
         teardown_adversarial ();
    });

    return Test.run ();
}
