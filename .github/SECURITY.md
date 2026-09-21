# Security policy

## Report a vulnerability privately

Use GitHub's private vulnerability reporting for this repository when it is available. Do not open a public issue for an unpatched vulnerability.

Include the affected file or release, the steps needed to reproduce the problem, the impact, and a safe proof of concept. Do not include passwords, tokens, private keys, personal files, or unredacted scan output.

If private vulnerability reporting is unavailable, contact the repository maintainers through GitHub before publishing technical details.

## Scope

Reports about filesystem access, path handling, cleanup actions, local data exposure, build scripts, and release artifacts are in scope.

The app is local-only and is not notarized by this repository. macOS permission prompts, local files selected by the user, and issues that require the user to approve an action are not vulnerabilities by themselves.
