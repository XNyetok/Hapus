# Security Policy

Havus deletes files, so a security bug here can mean **lost user data**. Your report matters.

## Supported versions

Until 1.0, only the latest release receives security fixes.

## Reporting a vulnerability

**Please don't report security issues in public issues.**

1. Preferred: **GitHub Private Vulnerability Reporting**. Open the *Security* tab and choose *Report a vulnerability*.
2. Or email **debi@elysiumx.org** with the subject `[SECURITY] Havus`.

Include the Havus and macOS versions, steps to reproduce, and the impact. Please leave out personal data that isn't needed.

We aim to reply within 7 days, keep you posted on progress, and ship a fix as fast as the severity requires. If you'd like, we'll credit you in the release notes.

## In scope

- Havus deleting or moving files outside the locations it should touch (path traversal, symlinks, race conditions).
- A cleanup rule that deletes user data that can't be regenerated.
- Ways for a third party to make Havus delete files.
- Ways to make Havus turn off, turn on or load a launch agent other than the one the user chose (Jalan Otomatis).
- Secrets or credentials accidentally committed to this repository.

## Out of scope

- Gatekeeper warnings because releases aren't notarized yet (a known limitation).
- Bugs in macOS itself.
