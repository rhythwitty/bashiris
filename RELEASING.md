# Releasing iris

This project uses [Release Please](https://github.com/googleapis/release-please) and **Conventional Commits** to automate versioning and releases.

## The Release Workflow

1.  **Develop**: Make changes to the code.
2.  **Commit**: Use [Conventional Commit](#conventional-commits) messages.
3.  **Merge**: Push or merge your changes into the `main` branch.
4.  **Release PR**: A "Release PR" will be automatically created or updated by GitHub Actions.
5.  **Tag & Release**: When you merge the "Release PR", the version in `iris` is automatically updated, a Git tag is created, and a GitHub Release is published with an auto-generated changelog.

---

## Conventional Commits

The version bump is determined by the prefix of your commit messages:

| Prefix | Type of Change | Version Bump |
|---|---|---|
| `feat:` | A new feature | **Minor** (e.g., 1.0.0 → 1.1.0) |
| `fix:` | A bug fix | **Patch** (e.g., 1.0.0 → 1.0.1) |
| `perf:` | Performance improvement | **Patch** |
| `feat!:` / `fix!:` | **BREAKING CHANGE** | **Major** (e.g., 1.0.0 → 2.0.0) |
| `chore:` / `docs:` | Maintenance or documentation | **None** |

### Examples

**New feature:**
```bash
git commit -m "feat: add support for check-power on Linux"
```

**Bug fix:**
```bash
git commit -m "fix: resolve timeout in download-yt"
```

**Breaking change:**
```bash
git commit -m "feat!: rename iris to something-else"
```

---

## Troubleshooting

- **The Release PR didn't update?** Ensure your commits follow the `type: message` format exactly.
- **Manual Overrides**: If you ever need to manually adjust the version, update `.release-please-manifest.json` and the `IRIS_VERSION` in the `iris` file.
