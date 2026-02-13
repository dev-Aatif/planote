# Planote Testing Guide

Ensuring the stability and reliability of Planote is critical. This guide explains how to run the test suite and add new tests.

## 🧪 Running Tests

Planote uses the GLib testing framework. Tests are defined in the `test/` directory.

### Run All Tests
To run the full test suite, use `meson test` from the build directory:

```bash
cd build
meson test
```

### Verbose Output
To see detailed output (useful for debugging failures):

```bash
meson test -v
```

### Running Specific Tests
You can run a specific test suite by name. Check `meson.build` or test output for suite names.

```bash
meson test planote-unit-tests
```

## 📂 Test Structure

Tests are located in the `test/` directory and typically mirror the structure of the `core/` directory.

-   **`test/test-database.vala`**: Tests for `Services.Database`.
-   **`test/test-store.vala`**: Tests for `Services.Store` (Data handling, Caching).
-   **`test/test-undomanager.vala`**: Tests for Undo/Redo functionality.
-   **`test/test-adversarial.vala`**: Chaos/Adversarial tests for edge cases and robustness.

## 🐛 Debugging Tips

-   **Logs**: Use `debug()`, `message()`, or `warning()` in Vala code to print logs. Run the app/tests from the terminal to see them.
-   **GDB**: You can run tests under GDB if needed:
    ```bash
    meson test --gdb planote-unit-tests
    ```
-   **DB Inspection**: For database-related issues, you can inspect the SQLite database file created during testing (often in a temporary directory or the build folder).
