/*
 * Security Audit Test Suite for Planote
 */

public class AuditSuite : GLib.Object {
    
    public static void setup_audit () {
        string test_db_path = "/tmp/planote_audit_%d.db".printf ((int) GLib.Random.next_int ());
        Services.Database.set_test_path (test_db_path);
        Services.Database.get_default ().init_database ();
        Services.Store.instance ().reset_cache ();
        
        // Ensure default project exists
        var project = new Objects.Project ();
        project.id = "inbox";
        project.name = "Inbox";
        Services.Store.instance ().insert_project (project);
    }
    
    public static void teardown_audit () {
        Services.Database.get_default ().close_database ();
        Services.Store.hard_reset ();
    }

    public static int main (string[] args) {
        Test.init (ref args);
        
        GLib.Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

        // TEST 1: XSS / Script Injection in Item Content
        Test.add_func ("/audit/xss_injection", () => {
            setup_audit ();
            
            var item = new Objects.Item ();
            item.id = Uuid.string_random ();
            item.content = "<script>alert('XSS')</script>";
            item.project_id = "inbox";
            
            Services.Store.instance ().insert_item (item);
            
            var fetched = Services.Store.instance ().get_item (item.id);
            assert (fetched != null);
            assert (fetched.content == "<script>alert('XSS')</script>"); 
            
            // Use global namespace for MarkdownProcessor
            var processor = MarkdownProcessor.get_default ();
            string html = processor.markup_string (fetched.content);
            
            // Expectation: < should be &lt;
            assert (html.contains ("&lt;script&gt;"));
            assert (!html.contains ("<script>"));
            
            teardown_audit ();
        });
        
        // TEST 2: Path Traversal in Attachments
        Test.add_func ("/audit/path_traversal", () => {
            setup_audit ();
            
            // Create parent item first
            var item = new Objects.Item ();
            item.id = "temp_item";
            item.content = "Attachment Parent";
            item.project_id = "inbox";
            Services.Store.instance ().insert_item (item);
            
            var attachment = new Objects.Attachment ();
            attachment.id = Uuid.string_random ();
            attachment.item_id = "temp_item";
            // Attempt traverse
            attachment.file_path = "../../../../../etc/passwd"; 
            attachment.file_name = "passwd";
            attachment.file_size = 100;
            attachment.file_type = "text/plain";
            
            // Verify if DB accepts this (It likely does as there's no validation in insert_attachment we saw)
            bool success = Services.Database.get_default ().insert_attachment (attachment);
            assert (success == true);
            
            var attachments = Services.Database.get_default ().get_attachments_collection ();
            bool found = false;
            foreach (var att in attachments) {
                if (att.id == attachment.id && att.file_path == "../../../../../etc/passwd") {
                    found = true;
                    break;
                }
            }
            assert (found == true);
            
            // Findings: The logic accepts relative traversal paths. 
            // Security relies on how file_path is consumed (File.new_for_path vs File.new_for_uri etc)
            
            teardown_audit (); 
        });

        // TEST 3: SQL Injection (Second Pass)
        Test.add_func ("/audit/sql_injection_ex", () => {
            setup_audit ();
            
            var project = new Objects.Project ();
            project.id = "proj_sql_inj";
            project.name = "My Project'; DROP TABLE Items; --";
            
            Services.Store.instance ().insert_project (project);
            
            // Verify project exists with that name
            var fetched = Services.Store.instance ().get_project ("proj_sql_inj");
            assert (fetched != null);
            assert (fetched.name == "My Project'; DROP TABLE Items; --");
            
            // Verify Items table still exists
            var item = new Objects.Item ();
            item.id = Uuid.string_random ();
            item.content = "Survivor";
            item.project_id = "inbox";
            
            bool success = Services.Database.get_default ().insert_item (item);
            assert (success == true);
            
            teardown_audit ();
        });

         // TEST 4: Undo/Redo Identity & State
        Test.add_func ("/audit/undo_redo_identity", () => {
            setup_audit ();
            
            var item = new Objects.Item ();
            item.id = Uuid.string_random ();
            item.content = "Original Content";
            item.project_id = "inbox";
            
            Services.Store.instance ().insert_item (item);
            
            // Simulate Delete Command logic (which uses clone)
            var original_clone = item.clone ();
            assert (original_clone.id == item.id);
            assert (original_clone.content == item.content);
            
            // Verify deep copy properties if any (e.g. DueDate)
            assert (original_clone.due != item.due); // Objects should be different instances
            
            // Modify original
            item.content = "Modified Content";
            
            // Clone should remain "Original Content"
            assert (original_clone.content == "Original Content");
            
            teardown_audit ();
        });

        return Test.run ();
    }
}
