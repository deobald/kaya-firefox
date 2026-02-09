# Plan: Automate Firefox Extension Signing

## Context

Kaya's Firefox extension needs to be signed before it can be installed by users. Mozilla requires all extensions to be signed, even self-distributed ones. This plan evaluates the available signing approaches and recommends the best option(s) for automation.

## Available Signing Methods

Mozilla offers four methods for signing Firefox extensions:

### 1. Manual Web Upload via AMO Developer Hub

**How it works:** Log in to https://addons.mozilla.org/developers/, upload a `.zip`/`.xpi` manually through the web UI, fill in metadata, and wait for signing.

**Pros:**
- Simple, no tooling required
- Full control over metadata and screenshots via the web UI

**Cons:**
- Entirely manual -- cannot be scripted or run in CI
- Requires a human to click through the web form for every release
- Signing can take up to 24 hours (or longer if selected for manual review)

**Automation potential:** None. This is a non-starter for automated signing.

### 2. `web-ext sign` CLI Command

**How it works:** The `web-ext` npm tool includes a `sign` subcommand that packages and submits the extension to AMO for signing, all from the command line. It accepts a `--channel` flag (`listed` or `unlisted`) and requires AMO API credentials (`--api-key` and `--api-secret`).

For `listed` extensions, it creates or updates the AMO listing. For `unlisted` extensions, it downloads a signed `.xpi` file directly.

First-time submissions require an `--amo-metadata` JSON file containing summary, categories, and license. Subsequent version updates only require bumping the version in `manifest.json`.

**Pros:**
- Single command: `web-ext sign --channel=listed --api-key=... --api-secret=...`
- Trivially scriptable in CI (GitHub Actions, GitLab CI, etc.)
- Handles packaging, upload, and download of signed artifact
- Well-documented, actively maintained by Mozilla
- `--approval-timeout` flag lets the CI job wait for signing to complete
- Works for both listed (AMO) and unlisted (self-distributed) channels
- Wraps the v5 API internally, so you get API power with CLI simplicity

**Cons:**
- Requires Node.js in the CI environment (it's an npm package)
- For listed extensions, signing may take time (auto-approval is common but not guaranteed)
- Less granular control than the raw API (e.g., cannot manage screenshots or detailed listing metadata beyond what `--amo-metadata` supports)

**Automation potential:** Excellent. This is purpose-built for CI/CD pipelines.

### 3. AMO Add-on API v5 (REST API)

**How it works:** Direct HTTP calls to `https://addons.mozilla.org/api/v5/addons/`. You POST an upload, create an addon or version, and poll for signing status. Authentication is via JWT using the same API key/secret pair as `web-ext sign`.

**Pros:**
- Maximum programmatic control over every aspect of the listing
- Can manage screenshots, detailed descriptions, localization, etc.
- Language-agnostic (any HTTP client works)

**Cons:**
- Requires implementing the full upload/poll/download flow yourself
- JWT token generation, multipart uploads, polling logic, error handling -- all custom code
- Substantially more work to build and maintain than `web-ext sign`
- `web-ext sign` already wraps this API, so you'd be reimplementing its internals

**Automation potential:** High, but unnecessary complexity. Only justified if you need API features that `web-ext sign` doesn't expose (e.g., managing translations, screenshots, or detailed listing metadata programmatically).

### 4. Signing API v4 (Legacy/Frozen)

**How it works:** The older signing API. Still functional but frozen -- no new features will be added.

**Pros:**
- Still works

**Cons:**
- Frozen; will eventually be deprecated
- Cannot create new listed extensions (only update existing ones)
- Superseded by v5 in every way

**Automation potential:** Do not use. It's a dead end.

## Recommendation

**Primary: `web-ext sign` (Method 2)**

This is the clear winner for Kaya's use case. The argument:

1. **Minimal effort, maximum automation.** A single CLI command handles packaging, uploading, signing, and downloading the signed artifact. A GitHub Actions workflow can be written in ~20 lines.

2. **Both channels supported.** Kaya will be listed on AMO (for discoverability) and the same tool will produce unlisted/self-distributed signed builds for bundling with the native daemon installers (DEB, RPM, MSI, PKG).

3. **CI/CD native.** API credentials are stored as GitHub repository secrets. The workflow triggers on version tags (e.g., `v1.2.0`), runs `web-ext sign` twice (once listed, once unlisted), and attaches the signed `.xpi` artifacts to a GitHub Release.

4. **No custom code to maintain.** The v5 REST API (Method 3) is powerful but overkill -- `web-ext sign` already wraps it. Writing and maintaining custom API integration code is unjustifiable when a first-party CLI tool exists.

5. **Kaya already needs `web-ext` anyway.** The `web-ext` tool is also used for `web-ext lint`, `web-ext build`, and `web-ext run` during development. Adding `sign` to the workflow is natural.

**Secondary: AMO API v5 (Method 3), only if needed later**

If Kaya eventually needs to programmatically manage localized descriptions, screenshots, or other rich AMO listing metadata as part of the release pipeline, the v5 API can supplement `web-ext sign`. But this is a future concern, not a launch concern.

## Decided Details

- **AMO account:** https://addons.mozilla.org/en-US/firefox/user/19731633/
- **CI system:** GitHub Actions
- **Both channels:** Listed (AMO public listing) and unlisted (bundled with DEB/RPM/MSI/PKG installers)

## Proposed CI Workflow

A GitHub Actions workflow (`.github/workflows/sign-extension.yml`):

```
Trigger: push tag matching v*.*.*

Jobs:
  sign-extension:
    Steps:
      1. Checkout repository
      2. Install Node.js
      3. Install web-ext (npm install -g web-ext)
      4. Run web-ext lint --source-dir=extension/
      5. Sign for AMO (listed):
           web-ext sign --channel=listed \
             --api-key=${{ secrets.AMO_API_KEY }} \
             --api-secret=${{ secrets.AMO_API_SECRET }} \
             --amo-metadata=extension/amo-metadata.json \
             --source-dir=extension/
      6. Sign for self-distribution (unlisted):
           web-ext sign --channel=unlisted \
             --api-key=${{ secrets.AMO_API_KEY }} \
             --api-secret=${{ secrets.AMO_API_SECRET }} \
             --source-dir=extension/
      7. Upload unlisted signed .xpi as build artifact
      8. Attach unlisted .xpi to GitHub Release

  build-installers (needs: sign-extension):
    strategy:
      matrix:
        target: [deb, rpm, msi, pkg]
    Steps:
      1. Download unlisted signed .xpi from sign-extension artifacts
      2. Build native daemon installer for target platform
      3. Bundle the signed .xpi into the installer
      4. Upload installer as GitHub Release artifact
```

### Credentials Required

- **AMO API Key (JWT issuer):** Generated at https://addons.mozilla.org/en-US/developers/addon/api/key/
- **AMO API Secret (JWT secret):** Generated at the same page
- Both stored as GitHub repository secrets: `AMO_API_KEY`, `AMO_API_SECRET`

### AMO Metadata File

A one-time `extension/amo-metadata.json` is needed for the first listed submission:

```json
{
  "version": { "license": "AGPL-3.0-only" },
  "listed": {
    "categories": ["bookmarks"],
    "summary": { "en-US": "Save bookmarks, quotes, and images with Save Button" }
  }
}
```

### Why Both Listed and Unlisted?

**Listed (`--channel=listed`):**
- Users discover and install Save Button from AMO
- AMO handles automatic updates -- no custom update mechanism needed
- The CLAUDE.md spec says "prepared for publishing on https://addons.mozilla.org"

**Unlisted (`--channel=unlisted`):**
- Produces a signed `.xpi` file that can be bundled inside platform installers
- The DEB, RPM, MSI, and PKG packages for the native sync daemon can include the extension
- Users who install the daemon get the extension without visiting AMO
- Note: unlisted extensions do not receive automatic updates from AMO, so the installer would install the version it ships with; users could later switch to the AMO-listed version for auto-updates

### Note on Unlisted Update Mechanism

Unlisted extensions bundled with installers will not auto-update via AMO. Two options:

1. **Rely on the installer:** When the user updates the native daemon (via apt/dnf/brew/chocolatey), the new installer bundles the latest signed `.xpi`. This is the simplest approach and consistent with how the daemon is already distributed.

2. **`update_url` in `manifest.json`:** The extension's `browser_specific_settings.gecko.update_url` can point to a JSON file hosted on savebutton.com that tells Firefox where to download new versions. This adds a self-hosted update server concern but decouples extension updates from daemon updates.

Option 1 is recommended for simplicity at launch. Option 2 can be added later if needed.

## Resolved: Listed Signing Re-enabled in CI

The `Sign for AMO (listed)` step was temporarily commented out because the first listed submission was stuck in AMO's manual review queue, causing `web-ext sign --channel=listed` to block indefinitely. The first version (0.1.2) was submitted manually via the AMO Developer Hub. Listed signing has been re-enabled as of v0.1.4.
