# Contributing

## Set up the project

Use macOS 14 or later with Swift 6 or later.

Run the test suite before you make a pull request:

```bash
swift test
git diff --check
```

Build the local application bundle when you change packaging or the app entry point:

```bash
./scripts/build_app.sh
```

## Keep changes safe to publish

Do not commit credentials, API keys, private keys, `.env` files, personal paths, scan results, screenshots of local data, or generated application bundles.

Use synthetic paths and temporary files in tests. Do not add code that uploads filenames, paths, file contents, or scan results without documenting the change and its privacy impact.

Run the public-release check before you open a pull request:

```bash
./scripts/check_public_release.sh
```

## Open a pull request

Describe the user-visible change, the tests you ran, and any macOS version or permission requirement. Keep unrelated formatting and refactoring out of the pull request.
