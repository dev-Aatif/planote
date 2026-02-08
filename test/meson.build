test_caldav_integration = executable(
    'test-caldav-integration',
    'test-caldav-integration.vala',
    dependencies: [ core_dep, glib_dep ],
    install: false
)

test('caldav-integration', test_caldav_integration, timeout: 60, suite: ['integration'])

test_chrono = executable(
    'test-chrono',
    'test-chrono.vala',
    dependencies: [ core_dep, glib_dep, gee_dep ],
    install: false
)

test('chrono', test_chrono, timeout: 30, suite: ['unit'])

# Database Unit Tests
test_database = executable(
    'test-database',
    'test-database.vala',
    dependencies: [ core_dep, glib_dep, gee_dep, sqlite3_dep ],
    install: false
)

test('database', test_database, timeout: 120, suite: ['unit'])

# Store Unit Tests
test_store = executable(
    'test-store',
    'test-store.vala',
    dependencies: [ core_dep, glib_dep, gee_dep ],
    install: false
)

test('store', test_store, timeout: 60, suite: ['unit'])

# Validation Unit Tests
test_validation = executable(
    'test-validation',
    'test-validation.vala',
    dependencies: [ glib_dep ],
    install: false
)

test('validation', test_validation, timeout: 30, suite: ['unit'])

