# Security

This is a personal portfolio application, not a production service. Source publication does not certify security or suitability for sensitive use.

## Reporting

Do not put exploit details, credentials, real prayer records, exemption dates, location data, or backups in a public issue. Use GitHub's private vulnerability reporting if it is enabled, or contact the owner through the GitHub profile to arrange a private report. No dedicated security inbox or response-time guarantee is provided.

## Development practices

- Keep tokens, `.env` files, signing keys, `key.properties`, databases, personal backups, and device logs outside Git.
- Inspect the full reachable Git history, not only the current files, before public publication. Rotate any real credential found; deleting it from the latest commit is insufficient.
- Existing APKs use a development signing certificate for personal update compatibility. Its fingerprint is public metadata, not a secret. Keystore files are not versioned. Do not treat these APKs as production-signed releases.
- Never paste real backup content into a test fixture. Public test data must be synthetic.
- No dependency vulnerability audit or penetration test is implied by the secret scan. Dependencies and operating-system behavior need ongoing review.

See [the publication review](docs/PUBLICATION_REVIEW.md) for audit scope and limitations.
