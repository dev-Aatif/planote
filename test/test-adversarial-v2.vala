/*
 * Adversarial QA Test Suite v2 — Chaos Engineering for Planote
 *
 * Categories: State Corruption (SC), Constraint Violation (CV),
 *             Recovery & Persistence (RP), Cache Coherence (CC),
 *             Undo/Redo Integrity (UR)
 *
 * Pattern: All tests use set_test_path + singleton DB to avoid
 * the cross-instance deadlock in _fill_item → Store.get_labels_by_item_labels.
 */

private string test_db_path;
private int pass_count = 0;
private int fail_count = 0;

// ─── Setup / Teardown ──────────────────────────────────────────────

void setup () {
    test_db_path = GLib.Environment.get_current_dir () + "/test_adv2_%d.db".printf ((int) GLib.get_real_time ());
    GLib.FileUtils.unlink (test_db_path);
    Services.Database.set_test_path (test_db_path);
    Services.Database.get_default ().init_database ();
    Services.Store.instance ().reset_cache ();
}

void teardown () {
    Services.Database.get_default ().close_database ();
    Services.Store.hard_reset ();
    GLib.FileUtils.unlink (test_db_path);
    GLib.FileUtils.unlink (test_db_path + "-wal");
    GLib.FileUtils.unlink (test_db_path + "-shm");
}

void log_result (string name, bool passed, string detail = "") {
    if (passed) {
        pass_count++;
        message ("  ✅ PASS: %s", name);
    } else {
        fail_count++;
        message ("  ❌ FAIL: %s — %s", name, detail);
    }
}

Objects.Project make_project (string id, string name) {
    var p = new Objects.Project ();
    p.id = id;
    p.name = name;
    return p;
}

Objects.Item make_item (string id, string content, string project_id, string parent_id = "") {
    var item = new Objects.Item ();
    item.id = id;
    item.content = content;
    item.project_id = project_id;
    item.parent_id = parent_id;
    return item;
}

Services.Database db () {
    return Services.Database.get_default ();
}

Services.Store store () {
    return Services.Store.instance ();
}

int count_project_items (string project_id) {
    int n = 0;
    foreach (var item in db ().get_items_collection ()) {
        if (item.project_id == project_id) n++;
    }
    return n;
}

// ─── SC: State Corruption ──────────────────────────────────────────

/*
 * SC-1: FK cascade on project delete removes items + sections
 */
void test_sc1_cascade_delete () {
    setup ();

    var project = make_project ("sc1-p", "SC1");
    db ().insert_project (project);

    var sec = new Objects.Section ();
    sec.id = "sc1-s";
    sec.name = "S";
    sec.project_id = "sc1-p";
    db ().insert_section (sec);

    for (int i = 0; i < 5; i++) {
        db ().insert_item (make_item ("sc1-i%d".printf (i), "T%d".printf (i), "sc1-p"));
    }

    int before = count_project_items ("sc1-p");
    db ().delete_project (project);
    int after = count_project_items ("sc1-p");

    var secs = db ().get_sections_collection ();
    bool sec_gone = true;
    foreach (var s in secs) { if (s.project_id == "sc1-p") sec_gone = false; }

    bool passed = (before == 5) && (after == 0) && sec_gone;
    log_result ("SC-1: FK cascade on project delete", passed,
        "before=%d after=%d sec_gone=%s".printf (before, after, sec_gone.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * SC-2: Rapid insert/delete interleaving — exact count
 */
void test_sc2_rapid_insert_delete () {
    setup ();

    var p = make_project ("sc2-p", "SC2");
    db ().insert_project (p);

    for (int i = 0; i < 20; i++) {
        db ().insert_item (make_item ("sc2-i%d".printf (i), "T%d".printf (i), "sc2-p"));
    }
    for (int i = 0; i < 20; i += 2) {
        var del = new Objects.Item ();
        del.id = "sc2-i%d".printf (i);
        db ().delete_item (del);
    }

    int remaining = count_project_items ("sc2-p");
    bool passed = (remaining == 10);
    log_result ("SC-2: Rapid insert/delete", passed, "expected=10 actual=%d".printf (remaining));
    assert (passed);
    teardown ();
}

/*
 * SC-3: Delete parent item → children orphaned (no FK on parent_id)
 */
void test_sc3_orphaned_children () {
    setup ();

    var p = make_project ("sc3-p", "SC3");
    db ().insert_project (p);
    db ().insert_item (make_item ("sc3-parent", "Parent", "sc3-p"));
    for (int i = 0; i < 3; i++) {
        db ().insert_item (make_item ("sc3-c%d".printf (i), "Child%d".printf (i), "sc3-p", "sc3-parent"));
    }

    var del = new Objects.Item ();
    del.id = "sc3-parent";
    db ().delete_item (del);

    var parent_check = db ().get_item_by_id ("sc3-parent");
    bool parent_gone = (parent_check.id == "" || parent_check.id == null);

    int children = 0;
    for (int i = 0; i < 3; i++) {
        var c = db ().get_item_by_id ("sc3-c%d".printf (i));
        if (c.id != "" && c.id != null) children++;
    }
    // No FK on parent_id → children ORPHANED (3 remain) — this is a documented blind spot
    bool passed = parent_gone && (children == 3);
    log_result ("SC-3: Parent delete → 3 orphaned children", passed,
        "parent_gone=%s children=%d".printf (parent_gone.to_string (), children));
    assert (passed);
    teardown ();
}

// ─── CV: Constraint Violation ──────────────────────────────────────

/*
 * CV-1: Item FK violation — non-existent project_id
 */
void test_cv1_fk_item () {
    setup ();
    bool result = db ().insert_item (make_item ("cv1-x", "Orphan", "nonexistent-proj"));
    bool passed = !result;
    log_result ("CV-1: FK violation item", passed, "insert=%s".printf (result.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * CV-2: Section FK violation — non-existent project_id
 */
void test_cv2_fk_section () {
    setup ();
    var sec = new Objects.Section ();
    sec.id = "cv2-s";
    sec.name = "S";
    sec.project_id = "nonexistent-proj";
    bool result = db ().insert_section (sec);
    bool passed = !result;
    log_result ("CV-2: FK violation section", passed, "insert=%s".printf (result.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * CV-3: Empty content is allowed (empty string ≠ NULL)
 */
void test_cv3_empty_content () {
    setup ();
    var p = make_project ("cv3-p", "CV3");
    db ().insert_project (p);

    bool result = db ().insert_item (make_item ("cv3-e", "", "cv3-p"));
    var fetched = db ().get_item_by_id ("cv3-e");
    bool passed = result && (fetched.id == "cv3-e");
    log_result ("CV-3: Empty content accepted", passed,
        "insert=%s id='%s'".printf (result.to_string (), fetched.id ?? "null"));
    assert (passed);
    teardown ();
}

/*
 * CV-4: Batch insert with one duplicate → entire transaction rolls back
 */
void test_cv4_batch_duplicate () {
    setup ();
    var p = make_project ("cv4-p", "CV4");
    db ().insert_project (p);
    db ().insert_item (make_item ("cv4-existing", "Original", "cv4-p"));

    var batch = new Gee.ArrayList<Objects.Item> ();
    batch.add (make_item ("cv4-b0", "B0", "cv4-p"));
    batch.add (make_item ("cv4-existing", "Duplicate!", "cv4-p")); // duplicate
    batch.add (make_item ("cv4-b2", "B2", "cv4-p"));

    bool result = db ().insert_items_transaction (batch);

    var orig = db ().get_item_by_id ("cv4-existing");
    bool orig_intact = (orig.content == "Original");

    var b0 = db ().get_item_by_id ("cv4-b0");
    bool b0_absent = (b0.id == "" || b0.id == null);

    var b2 = db ().get_item_by_id ("cv4-b2");
    bool b2_absent = (b2.id == "" || b2.id == null);

    bool passed = !result && orig_intact && b0_absent && b2_absent;
    log_result ("CV-4: Batch duplicate → rollback all", passed,
        "tx=%s orig=%s b0=%s b2=%s".printf (
            result.to_string (), orig_intact.to_string (),
            b0_absent.to_string (), b2_absent.to_string ()));
    assert (passed);
    teardown ();
}

// ─── RP: Recovery & Persistence ────────────────────────────────────

/*
 * RP-1: Backup → clear → restore → verify
 */
void test_rp1_backup_restore () {
    setup ();
    var p = make_project ("rp1-p", "Backup");
    p.color = "#AA00FF";
    db ().insert_project (p);
    db ().insert_item (make_item ("rp1-i", "BackupItem", "rp1-p"));

    bool backup = db ().backup_to_temp_tables ();
    bool clear = db ().clear_all_tables ();
    bool is_empty = (db ().get_projects_collection ().size == 0);
    bool restore = db ().restore_from_temp_tables ();

    bool proj_ok = false;
    foreach (var pp in db ().get_projects_collection ()) {
        if (pp.id == "rp1-p" && pp.name == "Backup") proj_ok = true;
    }
    var ri = db ().get_item_by_id ("rp1-i");
    bool item_ok = (ri.id == "rp1-i" && ri.content == "BackupItem");
    db ().clear_temp_tables ();

    bool passed = backup && clear && is_empty && restore && proj_ok && item_ok;
    log_result ("RP-1: Backup → restore cycle", passed,
        "backup=%s clear=%s empty=%s restore=%s proj=%s item=%s".printf (
            backup.to_string (), clear.to_string (), is_empty.to_string (),
            restore.to_string (), proj_ok.to_string (), item_ok.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * RP-2: Transaction rollback preserves original data
 */
void test_rp2_rollback () {
    setup ();
    var p = make_project ("rp2-p", "RP2");
    db ().insert_project (p);
    db ().insert_item (make_item ("rp2-existing", "Pre-existing", "rp2-p"));

    bool tx = db ().run_transaction (() => {
        db ().insert_item (make_item ("rp2-new", "Should rollback", "rp2-p"));
        return false; // force rollback
    });

    var check_new = db ().get_item_by_id ("rp2-new");
    bool new_gone = (check_new.id == "" || check_new.id == null);

    var check_orig = db ().get_item_by_id ("rp2-existing");
    bool orig_ok = (check_orig.id == "rp2-existing" && check_orig.content == "Pre-existing");

    bool passed = !tx && new_gone && orig_ok;
    log_result ("RP-2: Transaction rollback", passed,
        "tx=%s new_gone=%s orig=%s".printf (tx.to_string (), new_gone.to_string (), orig_ok.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * RP-3: Double init_database — idempotent
 */
void test_rp3_idempotent () {
    setup ();
    var p = make_project ("rp3-p", "Idempotent");
    db ().insert_project (p);
    db ().init_database ();

    bool survived = false;
    foreach (var pp in db ().get_projects_collection ()) {
        if (pp.id == "rp3-p") survived = true;
    }
    bool insert_ok = db ().insert_item (make_item ("rp3-after", "Post-reinit", "rp3-p"));

    bool passed = survived && insert_ok;
    log_result ("RP-3: Re-init idempotency", passed,
        "survived=%s insert=%s".printf (survived.to_string (), insert_ok.to_string ()));
    assert (passed);
    teardown ();
}

// ─── CC: Cache Coherence ───────────────────────────────────────────

/*
 * CC-1: Direct DB write → Store cache miss until reset
 */
void test_cc1_cache_miss () {
    setup ();
    store ().insert_project (make_project ("cc1-p", "CC1"));
    db ().insert_item (make_item ("cc1-hidden", "Invisible", "cc1-p")); // bypass Store

    bool hidden = (store ().get_item ("cc1-hidden") == null);
    store ().reset_cache ();
    var after = store ().get_item ("cc1-hidden");
    bool visible = (after != null && after.id == "cc1-hidden");

    bool passed = hidden && visible;
    log_result ("CC-1: DB write → cache miss → reset fixes", passed,
        "hidden=%s visible=%s".printf (hidden.to_string (), visible.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * CC-2: Direct DB delete → Store stale cache → reset fixes
 */
void test_cc2_stale_cache () {
    setup ();
    store ().insert_project (make_project ("cc2-p", "CC2"));
    store ().insert_item (make_item ("cc2-stale", "StaleItem", "cc2-p"));

    bool before = (store ().get_item ("cc2-stale") != null);

    // Delete directly from DB
    var del = new Objects.Item ();
    del.id = "cc2-stale";
    db ().delete_item (del);

    bool still_cached = (store ().get_item ("cc2-stale") != null);
    var from_db = db ().get_item_by_id ("cc2-stale");
    bool gone_db = (from_db.id == "" || from_db.id == null);

    store ().reset_cache ();
    bool fixed = (store ().get_item ("cc2-stale") == null);

    bool passed = before && still_cached && gone_db && fixed;
    log_result ("CC-2: DB delete → stale cache → reset fixes", passed,
        "before=%s stale=%s gone=%s fixed=%s".printf (
            before.to_string (), still_cached.to_string (),
            gone_db.to_string (), fixed.to_string ()));
    assert (passed);
    teardown ();
}

/*
 * CC-3: reset_cache → fresh reload matches DB
 */
void test_cc3_reload () {
    setup ();
    store ().insert_project (make_project ("cc3-p", "CC3"));
    for (int i = 0; i < 5; i++) {
        store ().insert_item (make_item ("cc3-i%d".printf (i), "T%d".printf (i), "cc3-p"));
    }

    int before = 0;
    foreach (var item in store ().items) { if (item.project_id == "cc3-p") before++; }

    store ().reset_cache ();

    int after = 0;
    foreach (var item in store ().items) { if (item.project_id == "cc3-p") after++; }

    bool passed = (before == 5) && (after == 5);
    log_result ("CC-3: Reset cache → fresh reload", passed,
        "before=%d after=%d".printf (before, after));
    assert (passed);
    teardown ();
}

// ─── UR: Undo/Redo Integrity ──────────────────────────────────────

/*
 * UR-1: AddItemCommand → undo → item gone from DB
 */
void test_ur1_undo_add () {
    setup ();
    store ().insert_project (make_project ("ur1-p", "UR1"));

    var item = make_item ("ur1-i", "Undoable", "ur1-p");
    var mgr = Services.UndoManager.instance ();
    mgr.clear ();

    var cmd = new Services.AddItemCommand (item, true);
    bool exec_ok = mgr.execute (cmd);

    var in_db = db ().get_item_by_id ("ur1-i");
    bool exists = (in_db.id == "ur1-i");

    bool undo_ok = mgr.undo ();

    var after = db ().get_item_by_id ("ur1-i");
    bool gone = (after.id == "" || after.id == null);

    bool passed = exec_ok && exists && undo_ok && gone;
    log_result ("UR-1: Undo AddItemCommand → DB deletion", passed,
        "exec=%s exists=%s undo=%s gone=%s".printf (
            exec_ok.to_string (), exists.to_string (),
            undo_ok.to_string (), gone.to_string ()));
    assert (passed);
    mgr.clear ();
    teardown ();
}

/*
 * UR-2: DeleteItemCommand → undo → item restored in DB
 */
void test_ur2_undo_delete () {
    setup ();
    store ().insert_project (make_project ("ur2-p", "UR2"));
    store ().insert_item (make_item ("ur2-i", "Restorable", "ur2-p"));

    bool exists = (db ().get_item_by_id ("ur2-i").id == "ur2-i");

    var mgr = Services.UndoManager.instance ();
    mgr.clear ();

    // We need to get the item from the Store (not create a new one)
    // to ensure the DeleteItemCommand has the right object
    var item_ref = store ().get_item ("ur2-i");
    var cmd = new Services.DeleteItemCommand (item_ref);
    bool exec_ok = mgr.execute (cmd);

    var after_del = db ().get_item_by_id ("ur2-i");
    bool gone = (after_del.id == "" || after_del.id == null);

    bool undo_ok = mgr.undo ();

    var after_undo = db ().get_item_by_id ("ur2-i");
    bool restored = (after_undo.id == "ur2-i");

    bool passed = exists && exec_ok && gone && undo_ok && restored;
    log_result ("UR-2: Undo DeleteItemCommand → DB restore", passed,
        "exists=%s exec=%s gone=%s undo=%s restored=%s".printf (
            exists.to_string (), exec_ok.to_string (),
            gone.to_string (), undo_ok.to_string (),
            restored.to_string ()));
    assert (passed);
    mgr.clear ();
    teardown ();
}

// ─── Main ──────────────────────────────────────────────────────────

int main (string[] args) {
    Test.init (ref args);
    GLib.Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    message ("╔══════════════════════════════════════════════════════════╗");
    message ("║  Adversarial QA v2 — Chaos Engineering Suite            ║");
    message ("╚══════════════════════════════════════════════════════════╝");

    // SC
    Test.add_func ("/adversary/v2/sc1_cascade", test_sc1_cascade_delete);
    Test.add_func ("/adversary/v2/sc2_rapid", test_sc2_rapid_insert_delete);
    Test.add_func ("/adversary/v2/sc3_orphans", test_sc3_orphaned_children);
    // CV
    Test.add_func ("/adversary/v2/cv1_fk_item", test_cv1_fk_item);
    Test.add_func ("/adversary/v2/cv2_fk_sec", test_cv2_fk_section);
    Test.add_func ("/adversary/v2/cv3_empty", test_cv3_empty_content);
    Test.add_func ("/adversary/v2/cv4_batch_dup", test_cv4_batch_duplicate);
    // RP
    Test.add_func ("/adversary/v2/rp1_backup", test_rp1_backup_restore);
    Test.add_func ("/adversary/v2/rp2_rollback", test_rp2_rollback);
    Test.add_func ("/adversary/v2/rp3_idempotent", test_rp3_idempotent);
    // CC
    Test.add_func ("/adversary/v2/cc1_miss", test_cc1_cache_miss);
    Test.add_func ("/adversary/v2/cc2_stale", test_cc2_stale_cache);
    Test.add_func ("/adversary/v2/cc3_reload", test_cc3_reload);
    // UR
    Test.add_func ("/adversary/v2/ur1_undo_add", test_ur1_undo_add);
    Test.add_func ("/adversary/v2/ur2_undo_del", test_ur2_undo_delete);

    int result = Test.run ();

    message ("═════════════════════════════════════════════════════════");
    message ("  RESULTS: %d passed, %d failed", pass_count, fail_count);
    message ("═════════════════════════════════════════════════════════");

    return result;
}
