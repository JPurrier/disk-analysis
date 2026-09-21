#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if git ls-files | grep -E '(^|/)(\.DS_Store|\.build/|[^/]+\.app/|[^/]+\.dSYM/)' >/dev/null; then
    echo "Generated macOS files are tracked." >&2
    exit 1
fi

if git ls-files | grep -E '(^|/)(\.env($|\.)|[^/]+\.(pem|key|p12|pfx))' >/dev/null; then
    echo "Credential-bearing file names are tracked." >&2
    exit 1
fi

if git grep -n -I -E '(-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|/(Users|home)/[A-Za-z0-9._-]{2,}[^A-Za-z0-9._-])' -- ':!agents.md' ':!.agents/**' ':!Tests/**' >/dev/null; then
    echo "Personal or secret-bearing content was found in the tracked source tree." >&2
    exit 1
fi

if git grep -n -I -E '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' -- ':!agents.md' ':!.agents/**' >/dev/null; then
    echo "An email address is present in the tracked source tree." >&2
    exit 1
fi

if ! git grep -q '<string>org.diskanalysis.DiskAnalysis</string>' -- scripts/Info.plist; then
    echo "The public bundle identifier is not configured." >&2
    exit 1
fi

echo "Public-release checks passed."
