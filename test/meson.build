# Compile GSettings schema for test environment
glib_compile_schemas = find_program('glib-compile-schemas', required: false)
schema_dir = join_paths(meson.project_build_root(), 'data')
if glib_compile_schemas.found()
    custom_target('compile-test-schemas',
        command: [glib_compile_schemas, schema_dir],
        output: 'gschemas.compiled',
        build_by_default: true,
    )
endif

# Test environment: GSettings schema location
test_env = environment()
test_env.set('GSETTINGS_SCHEMA_DIR', schema_dir)
test_env.set('GSETTINGS_BACKEND', 'memory')

test_caldav_integration = executable(
    'test-caldav-integration',
    'test-caldav-integration.vala',
    dependencies: [ core_dep, glib_dep ],
    install: false
)

test('caldav-integration', test_caldav_integration, timeout: 60, suite: ['integration'], env: test_env)

test_chrono = executable(
    'test-chrono',
    'test-chrono.vala',
    dependencies: [ core_dep, glib_dep, gee_dep ],
    install: false
)

test('chrono', test_chrono, timeout: 30, suite: ['unit'], env: test_env)

# Database Unit Tests
test_database = executable(
    'test-database',
    'test-database.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('database', test_database, timeout: 120, suite: ['unit'], env: test_env)

# Store Unit Tests
test_store = executable(
    'test-store',
    'test-store.vala',
    dependencies: [ core_dep, glib_dep, gee_dep ],
    install: false
)

test('store', test_store, timeout: 60, suite: ['unit'], env: test_env)

# Validation Unit Tests
test_validation = executable(
    'test-validation',
    'test-validation.vala',
    dependencies: [ glib_dep ],
    install: false
)

test('validation', test_validation, timeout: 30, suite: ['unit'])

# Backup Unit Tests
test_backup = executable(
    'test-backup',
    'test-backup.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, json_dep ],
    install: false
)

test('backup', test_backup, timeout: 60, suite: ['unit'], env: test_env)

# UndoManager Unit Tests
test_undo_manager = executable(
    'test-undo-manager',
    'test-undo-manager.vala',
    dependencies: [ core_dep, glib_dep, gee_dep ],
    install: false
)

test('undo-manager', test_undo_manager, timeout: 30, suite: ['unit'], env: test_env)


# Adversarial / Chaos Tests
test_adversarial = executable(
    'test-adversarial',
    'test-adversarial.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('adversarial', test_adversarial, timeout: 60, suite: ['stress'], env: test_env)

# Adversarial QA v2 — Chaos Engineering
test_adversarial_v2 = executable(
    'test-adversarial-v2',
    'test-adversarial-v2.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('adversarial-v2', test_adversarial_v2, timeout: 120, suite: ['stress'], env: test_env)

# Verification Fixes Script
test_verify_fixes = executable(
    'test-verify-fixes',
    'verify_fixes.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('verify-fixes', test_verify_fixes, timeout: 30, suite: ['verification'], env: test_env)

# Security Audit Test Suite
test_audit = executable(
    'test-audit',
    'audit_suite.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('audit', test_audit, timeout: 60, suite: ['audit'], env: test_env)
