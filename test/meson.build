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

