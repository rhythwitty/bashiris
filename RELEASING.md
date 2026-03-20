# Releasing iris

This project uses [Release Please](https://github.com/googleapis/release-please) and **Conventional Commits** to automate versioning and releases.

## The Release Workflow

1.  **Develop**: Make changes to the code.
2.  **Commit**: Use [Conventional Commit](#conventional-commits) messages.
3.  **Merge**: Push or merge your changes into the `main` branch.
4.  **Release PR**: A "Release PR" will be automatically created or updated by GitHub Actions.
5.  **Tag & Release**: When you merge the "Release PR", `.release-please-manifest.json` and `CHANGELOG.md` are updated, a Git tag is created, and a GitHub Release is published with an auto-generated changelog.

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

## Version Source of Truth

The canonical version source is `.release-please-manifest.json`.

Release Please updates this file in the Release PR:

```json
{
  ".": "1.2.0"
}
```

The `iris` dispatcher reads the version in this order:

1. `.release-please-manifest.json` next to the dispatcher, useful when running from a checked-out repo.
2. `/usr/local/lib/iris/.release-please-manifest.json`, installed by `install.sh`.

There is no separate version constant in `iris`. If the manifest is missing, `iris --version` fails with a clear error instead of reporting a stale fallback version.

## Self-Update Workflow

`iris --update` and `iris --upgrade` use the same update path:

1. Read the currently installed version from the local release manifest.
2. Fetch the remote `.release-please-manifest.json` from `main`.
3. Compare the local version with the remote version.
4. If the remote version is newer or the remote version cannot be checked, run `install.sh`.
5. `install.sh` installs:
   - the `iris` dispatcher to `/usr/local/bin/iris`
   - `.release-please-manifest.json` to `/usr/local/lib/iris/.release-please-manifest.json`
   - command scripts to `/usr/local/lib/iris/`

After a Release PR is merged, the remote manifest on `main` contains the new version. Existing installations can then detect that version and update with:

```bash
iris --upgrade
```

---

## Troubleshooting

- **The Release PR didn't update?** Ensure your commits follow the `type: message` format exactly.
- **`iris --upgrade` says already up to date unexpectedly**: Check the version in the remote `.release-please-manifest.json` on `main`. That is the version the updater compares against.
- **Manual Overrides**: If you ever need to manually adjust the version, update `.release-please-manifest.json`.
