# Public portfolio preparation review

Reviewed on 19 November 2026 against source baseline `988357d` (v1.35.0 plus its download documentation). This prepares a recruiter-facing source repository; it does not change GitHub visibility or publish an app to a store.

## Review performed

- Fetched available remote tags and inspected the remote branch inventory (only `main` was advertised). All locally reachable history was included: 48 reachable commits. Gitleaks 8.30.1 scanned 46 commits containing scan-relevant changes with `git --log-opts=--all --redact`; no secret findings were reported.
- Scanned the current source tree with Gitleaks and inspected the tracked-file inventory. No credential findings were reported. The downloaded scanner archive was checked against its release checksum manifest.
- Inspected historical filenames for environment files, credentials, signing keystores, databases, PDFs/resumes, APKs, logs, and personal backups. No such files were found; backup-related names were source/tests. The attached resume is outside the repository and is not versioned.
- Reviewed test timetable fixtures and current portfolio screenshots: synthetic journal records, mock calendar responses, and generic Malaysian places are used. Existing design previews are historical examples, not live personal records.
- Reviewed the GitHub release asset inventory: APKs and checksum files are the published artifact types. APKs are personal development-signed builds. This inventory review is not forensic analysis of every historical APK or attachment.
- Confirmed font attribution is retained in `assets/fonts/OFL.txt`. Dependencies keep their licenses; no blanket open-source license was assigned to the original project.
- Reviewed manifest and location/network/backup code to document actual data handling. The fingerprint of a signing certificate is public metadata, not its private key.

Secret-scan reproduction with Gitleaks 8.30.1 installed:

```bash
gitleaks git . --log-opts=--all --redact
```

Run a separate directory scan on a clean checkout for the current source. Keep scanner reports private; future reports can contain sensitive findings even when redacted.

## Preparation changes

- Replaced the long README with a portfolio overview, current synthetic screenshots, architecture links, setup steps, measured validation results, and explicit Android-only scope. Preserved detailed instructions in `USER_GUIDE.md`.
- Added privacy, security, and copyright/reuse documentation. Public visibility is for portfolio inspection; original code remains rights-reserved rather than automatically becoming open source.
- Expanded ignore rules for common secrets, signing files, local databases, logs, APKs, personal backups, attachments, and private work folders. Ignore rules do not remove previously committed files; history was reviewed separately.
- Removed the expired bootstrap upload manifest. Manual release upload automation now requires a fresh explicit manifest and grants write permission only to its upload job. Existing release tags and app behavior were preserved.

## Verification

Four existing theme/widget tests passed while regenerating the screenshots, covering both themes, navigation, persistent theme preferences, and narrow/high-contrast/large-text use. Python publishing-script syntax, fail-closed behavior with no manifest, local documentation links, ignore rules, whitespace, and static analysis were checked. Application code was not modified. The full v1.35.0 baseline previously passed 155 Flutter tests, 63 Android JVM tests, and debug/release APK builds; these counts are historical baseline evidence, not a newly rerun full suite for this documentation change.

## Visibility implications and remaining limits

- Commit author names and email addresses become public with Git history. The existing author's identity metadata was retained; no history rewrite was performed.
- Public visibility exposes earlier commits, tags, releases, Actions logs, and collaboration surfaces, not only the new README. Account-level secret protection/private vulnerability reporting should be checked in GitHub when changing visibility. A suggested repository description is: `Personal Flutter Android prayer journal with SQLite persistence, native widgets, local reminders, and automated tests.`
- Expired temporary APK links are historical delivery records, not passwords. They remain in earlier history/release notes. Recruiters can review the source without downloading APKs.
- No credential revocation or history rewrite was indicated by the scan findings. Automated secret detection cannot prove absence of every secret or private datum. This is not a dependency vulnerability audit, penetration test, legal review of all dependencies, or physical-device security certification.
- No GitHub repository setting, release artifact, or visibility was changed by this preparation. No Google Play publication is planned.
