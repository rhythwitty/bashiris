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

**Patch Bump (v1.0.0 → v1.0.1)**
Use `fix:` for bug fixes or `perf:` for performance improvements.
```bash
git commit -m "fix: handle missing port argument in kill-port"
git commit -m "perf: optimize script discovery speed in iris"
```

**Minor Bump (v1.0.0 → v1.1.0)**
Use `feat:` for new features or significant enhancements.
```bash
git commit -m "feat: add iris --upgrade alias"
git commit -m "feat: add check-power command for macOS"
```

**Major Bump (v1.0.0 → v2.0.0)**
Add a `!` after the type (e.g., `feat!:`) to indicate a breaking change.
```bash
git commit -m "feat!: redesign iris dispatcher to use /usr/local/lib"
git commit -m "fix!: remove support for legacy bash versions"
```

**No Bump (Internal Changes)**
Use `chore:`, `docs:`, `refactor:`, `style:`, or `test:`. These appear in the changelog but don't trigger a version increase.
```bash
git commit -m "docs: update README with installation instructions"
git commit -m "chore: update release-please configuration"
git commit -m "refactor: simplify argument parsing in download-yt"
```

---

## How Versioning is Calculated

GitHub Actions looks at **all commits** since the last release to determine the single next version:

- If there is at least one `! (breaking change)`, it performs a **Major** bump.
- Otherwise, if there is at least one `feat:`, it performs a **Minor** bump.
- Otherwise, if there is at least one `fix:` or `perf:`, it performs a **Patch** bump.

**Scenario Example:**
If you push these three commits to `main`:
1. `fix: fix a tiny typo`
2. `feat: add a massive new feature`
3. `chore: update gitignore`

The result will be a **Minor** bump (v1.0.0 → v1.1.0), because the `feat:` takes precedence over the `fix:`.

---

## Troubleshooting

- **The Release PR didn't update?** Ensure your commits follow the `type: message` format exactly.
- **Manual Overrides**: If you ever need to manually adjust the version, update `.release-please-manifest.json` and the `IRIS_VERSION` in the `iris` file.
