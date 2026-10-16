# Releasing iris

This project uses [Release Please](https://github.com/googleapis/release-please) and **Conventional Commits**.

## Source of truth

- `.release-please-manifest.json` is the canonical version file.
- `CHANGELOG.md` is generated from the release history.
- `iris` reads the installed manifest first and does **not** rely on a separate hardcoded version constant.

## Release flow

1. Make and commit changes on a feature branch.
2. Use Conventional Commit messages.
3. Merge to `main`.
4. GitHub Actions creates or updates the Release PR.
5. Merge the Release PR.
6. Release Please updates `.release-please-manifest.json`, `CHANGELOG.md`, tags the release, and publishes the GitHub Release.

## Conventional Commits

| Prefix | Bump | Notes |
|---|---|---|
| `feat:` | Minor | New feature |
| `fix:` | Patch | Bug fix |
| `perf:` | Patch | Performance improvement |
| `feat!:` / `fix!:` | Major | Breaking change |
| `chore:` / `docs:` / `refactor:` / `style:` / `test:` | None | No version bump |

### Examples

```bash
git commit -m "fix: handle missing port argument in kill-port"
git commit -m "feat: add verify-ssh command"
git commit -m "feat!: redesign dispatcher output"
```

## Self-update

`iris --update` and `iris --upgrade`:

1. Read the installed version from the local manifest.
2. Fetch the remote `.release-please-manifest.json` from `main`.
3. Compare versions.
4. Run `install.sh` if an update is available.

`install.sh` installs:

- the `iris` dispatcher to `/usr/local/bin/iris`
- `.release-please-manifest.json` to `/usr/local/lib/iris/.release-please-manifest.json`
- command scripts to `/usr/local/lib/iris/`

## Troubleshooting

- **Release PR not created**: Check that commits use Conventional Commit format.
- **`iris --upgrade` says up to date unexpectedly**: Compare the local and remote `.release-please-manifest.json` values.
- **Manual version edits**: Update `.release-please-manifest.json`; do not add a separate version constant.
