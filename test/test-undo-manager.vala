/*
 * Unit Tests for UndoManager
 * Tests command execution, undo/redo cycles, and history management
 */

private Services.UndoManager undo_manager;

void setup_undo_manager () {
    undo_manager = Services.UndoManager.instance ();
    undo_manager.clear ();
}

/*
 * Simple test command for testing purposes
 */
public class TestCommand : Services.Command {
    private string _description;
    public int execute_count = 0;
    public int undo_count = 0;
    
    public TestCommand (string description) {
        this._description = description;
    }
    
    public override bool execute () {
        execute_count++;
        return true;
    }
    
    public override bool undo () {
        undo_count++;
        return true;
    }
    
    public override string description {
        owned get { return _description; }
    }
}

/*
 * Test basic execute and undo cycle
 */
void test_execute_and_undo () {
    setup_undo_manager ();
    
    var command = new TestCommand ("Test Command");
    
    // Execute command
    bool result = undo_manager.execute (command);
    assert (result == true);
    assert (command.execute_count == 1);
    assert (undo_manager.can_undo == true);
    assert (undo_manager.can_redo == false);
    
    // Undo command
    result = undo_manager.undo ();
    assert (result == true);
    assert (command.undo_count == 1);
    assert (undo_manager.can_undo == false);
    assert (undo_manager.can_redo == true);
    
    print ("  ✓ test_execute_and_undo passed\n");
}

/*
 * Test redo after undo
 */
void test_redo_after_undo () {
    setup_undo_manager ();
    
    var command = new TestCommand ("Redo Test");
    
    // Execute, undo, then redo
    undo_manager.execute (command);
    undo_manager.undo ();
    
    // Redo should re-execute
    bool result = undo_manager.redo ();
    assert (result == true);
    assert (command.execute_count == 2);  // Executed twice (initial + redo)
    assert (undo_manager.can_redo == false);
    assert (undo_manager.can_undo == true);
    
    print ("  ✓ test_redo_after_undo passed\n");
}

/*
 * Test that new command clears redo stack
 */
void test_new_command_clears_redo () {
    setup_undo_manager ();
    
    var command1 = new TestCommand ("Command 1");
    var command2 = new TestCommand ("Command 2");
    
    // Execute and undo first command
    undo_manager.execute (command1);
    undo_manager.undo ();
    assert (undo_manager.can_redo == true);
    
    // Execute new command - should clear redo
    undo_manager.execute (command2);
    assert (undo_manager.can_redo == false);
    
    print ("  ✓ test_new_command_clears_redo passed\n");
}

/*
 * Test history overflow (max 50 items)
 */
void test_history_overflow () {
    setup_undo_manager ();
    
    // Execute 55 commands (more than max_history of 50)
    for (int i = 0; i < 55; i++) {
        var command = new TestCommand ("Command %d".printf (i));
        undo_manager.execute (command);
    }
    
    // Should be able to undo, but oldest commands should be trimmed
    int undo_count = 0;
    while (undo_manager.can_undo) {
        undo_manager.undo ();
        undo_count++;
    }
    
    // Should have max 50 items in history
    assert (undo_count <= 50);
    
    print ("  ✓ test_history_overflow passed\n");
}

/*
 * Test command descriptions
 */
void test_command_descriptions () {
    setup_undo_manager ();
    
    var command = new TestCommand ("My Test Description");
    undo_manager.execute (command);
    
    string? desc = undo_manager.next_undo_description;
    assert (desc == "My Test Description");
    
    undo_manager.undo ();
    
    string? redo_desc = undo_manager.next_redo_description;
    assert (redo_desc == "My Test Description");
    
    print ("  ✓ test_command_descriptions passed\n");
}

/*
 * Test clear functionality
 */
void test_clear () {
    setup_undo_manager ();
    
    var command = new TestCommand ("Clear Test");
    undo_manager.execute (command);
    undo_manager.undo ();
    
    assert (undo_manager.can_redo == true);
    
    undo_manager.clear ();
    
    assert (undo_manager.can_undo == false);
    assert (undo_manager.can_redo == false);
    
    print ("  ✓ test_clear passed\n");
}

/*
 * Test multiple undo operations
 */
void test_multiple_undos () {
    setup_undo_manager ();
    
    var commands = new Gee.ArrayList<TestCommand> ();
    for (int i = 0; i < 5; i++) {
        var cmd = new TestCommand ("Command %d".printf (i));
        commands.add (cmd);
        undo_manager.execute (cmd);
    }
    
    // Undo all 5
    for (int i = 0; i < 5; i++) {
        assert (undo_manager.can_undo == true);
        undo_manager.undo ();
    }
    
    assert (undo_manager.can_undo == false);
    
    // Verify all commands were undone
    foreach (var cmd in commands) {
        assert (cmd.undo_count == 1);
    }
    
    print ("  ✓ test_multiple_undos passed\n");
}

void main (string[] args) {
    Test.init (ref args);
    
    print ("\n=== UndoManager Unit Tests ===\n\n");
    
    // Basic functionality
    Test.add_func ("/undo/basic/execute_and_undo", test_execute_and_undo);
    Test.add_func ("/undo/basic/redo_after_undo", test_redo_after_undo);
    Test.add_func ("/undo/basic/new_command_clears_redo", test_new_command_clears_redo);
    
    // History management
    Test.add_func ("/undo/history/overflow", test_history_overflow);
    Test.add_func ("/undo/history/clear", test_clear);
    Test.add_func ("/undo/history/multiple_undos", test_multiple_undos);
    
    // Descriptions
    Test.add_func ("/undo/descriptions", test_command_descriptions);
    
    Test.run ();
    
    print ("\n=== All UndoManager Tests Completed ===\n");
}
