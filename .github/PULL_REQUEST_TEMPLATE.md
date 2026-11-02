## Summary

<!-- What changed and why? Link related issues, e.g. "Closes #12". -->

## How to test

<!-- Steps to verify this change. -->

## Checklist

- [ ] `make test` passes and the app builds
- [ ] Tested on macOS version: <!-- fill in -->
- [ ] No secrets, certificates, Team IDs or personal data in this change
- [ ] Every file removal goes through `FileRemover` (no direct `FileManager.removeItem`/`trashItem` calls)
- [ ] New or changed cleanup rules include evidence that they're safe, plus tests
- [ ] UI text is casual Indonesian, addressing the user as "kamu" (see the glossary in CONTRIBUTING.md)
