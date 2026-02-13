# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-13

### Added
-   **Simplified Note Editor**: A focused, distraction-free writing experience.
-   **Headings Support**: H1-H6 heading styles for structuring notes.
-   **Security Hardening**: Improved input validation and SQL injection protection.

### Changed
-   **Editor UX**: Removed complex formatting options to streamline the note-taking process.
-   **Database Schema**: Enforced Foreign Key constraints for better data integrity.
-   **Undo/Redo**: Completely rewritten UndoManager for reliability and state consistency.

### Fixed
-   **Critical**: Fixed "Silent Insert Failures" (Duplicate ID) bug.
-   **Critical**: Fixed Undo/Redo identity bug that caused state corruption.
-   **Critical**: Fixed Restore Deletion Order logic.
-   **Security**: Addressed potential XSS vulnerabilities in Markdown link processing.
-   **UI**: Fixed sidebar/navigation glitches on startup.

### Removed
-   **Formatting Options**: Bold, Italic, Strikethrough, Lists, Links, and Code formatting have been removed from the Note Editor to simplify the user experience.
