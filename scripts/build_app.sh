#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "🔨 Building DiskAnalysis release binary..."
swift build -c release

RELEASE_BIN="${ROOT_DIR}/.build/release/DiskAnalysis"
APP_DIR="${ROOT_DIR}/DiskAnalysis.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${RELEASE_BIN}" "${MACOS_DIR}/DiskAnalysis"
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "🔏 Ad-hoc signing application bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "✅ Done! Standalone macOS application bundle ready at: ${APP_DIR}"
