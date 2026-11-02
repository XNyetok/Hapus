# Maintainer Guide

## Repository settings

These are enabled on [XNyetok/Havus](https://github.com/XNyetok/Havus). Keep them on, and use this list to recreate them if needed:

- **Secret scanning** with **push protection**
- **Private vulnerability reporting** (used by [SECURITY.md](../SECURITY.md))
- **Dependabot alerts** and **Dependabot security updates**
- **Automatically delete head branches** after a merge
- **Ruleset "Protect main"** on the default branch:
  - pull request required, with 0 approvals so the maintainer can merge their own PRs
  - required status checks `Scan secret` and `Build & test`, accepted only from GitHub Actions
  - no force pushes, no branch deletion, no bypass

## Git identity

This repository uses a local identity, separate from the global Git config:

```sh
git config user.name   # Debi Kurnia
git config user.email  # debi@elysiumx.org
```

On a new machine, set both before the first commit, then run `make setup` and `git config fetch.prune true`. To show commits as **Verified** on GitHub, sign them with an SSH or GPG key registered on your account (`git config commit.gpgsign true`).

## Day-to-day workflow

`main` only changes through pull requests:

```sh
git switch main && git pull
git switch -c feat/short-description
# ...work, commit in English (Conventional Commits)...
git push -u origin feat/short-description
gh pr create --fill
```

Once CI is green, squash-merge. The `--author-email` flag keeps the squash commit on the project identity:

```sh
gh pr merge --squash --author-email debi@elysiumx.org --delete-branch
```

GitHub deletes the remote branch automatically, and with `fetch.prune` enabled, the next `git pull` removes it locally too.

## Releases (currently without notarization)

1. Make sure `main` is green in CI.
2. Create and push a version tag:

   ```sh
   git tag -a v0.1.0 -m "Havus 0.1.0"
   git push origin v0.1.0
   ```

3. The **Release** workflow builds a universal, ad-hoc signed app and creates a **draft release** with `Havus-0.1.0.zip` and `Havus-0.1.0.zip.sha256`.
4. Review the draft, edit the release notes, and publish.

The app version comes from the tag name, so there's no need to edit `MARKETING_VERSION` by hand. To try it locally first, run `make release VERSION=0.1.0`; the output lands in `build/release/`.

## Upgrading to notarization

Do this once there's an Apple Developer Program membership ($99/year).

1. Create a **Developer ID Application** certificate and an **App Store Connect API key** (for `notarytool`).
2. Store them as **GitHub Secrets**, never in the repository:
   - `MACOS_CERTIFICATE_P12` (base64) and `MACOS_CERTIFICATE_PASSWORD`
   - `NOTARY_API_KEY_P8` (base64), `NOTARY_API_KEY_ID` and `NOTARY_API_ISSUER_ID`
3. In the workflow, import the certificate into a temporary keychain, then change `scripts/build-release.sh` to sign with the Developer ID (`--options runtime`), run `xcrun notarytool submit --wait`, and `xcrun stapler staple`.
4. Submit the app to Homebrew Cask. Optionally add Sparkle for auto-updates with an EdDSA-signed appcast.

After this, users' Full Disk Access permission no longer resets on every update, because the signature stays stable.

## Routine

- Review Dependabot PRs (GitHub Actions versions).
- Run `make scan` before every release.
- Update the minimum Xcode and macOS versions in README and CONTRIBUTING when the CI runners change.
