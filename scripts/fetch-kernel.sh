#!/usr/bin/env bash
#
# Fetch the pinned Shen-Language/shen-sources kernel release, verify its
# SHA-256, and extract it unmodified into `kernel/`.
#
# USAGE
#   scripts/fetch-kernel.sh [kernel.tar.gz]
# With no argument the archive is downloaded from the GitHub release. Pass a
# local copy of the release tarball to build offline; its hash is still
# verified.
set -euo pipefail

KERNEL_VERSION="43.1"
KERNEL_TAG="shen-${KERNEL_VERSION}"
KERNEL_SHA256="900eedef44f440af78f9395ed06e689ce1604546fc309f5bc7c8bc84cc651920"
KERNEL_FOLDER="ShenOSKernel-${KERNEL_VERSION}"
KERNEL_ARCHIVE="${KERNEL_FOLDER}.tar.gz"
KERNEL_URL="https://github.com/Shen-Language/shen-sources/releases/download/${KERNEL_TAG}/${KERNEL_ARCHIVE}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ARCHIVE="${1:-}"
if [ -z "$ARCHIVE" ]; then
  echo "Downloading ${KERNEL_URL}"
  curl -fsSL "$KERNEL_URL" -o "$WORK/$KERNEL_ARCHIVE"
  ARCHIVE="$WORK/$KERNEL_ARCHIVE"
fi

if command -v sha256sum >/dev/null 2>&1; then
  GOT="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
else
  GOT="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
fi
if [ "$GOT" != "$KERNEL_SHA256" ]; then
  echo "ERROR: ${KERNEL_ARCHIVE} SHA-256 mismatch" >&2
  echo "  expected ${KERNEL_SHA256}" >&2
  echo "  got      ${GOT}" >&2
  exit 1
fi
echo "Verified ${KERNEL_ARCHIVE} (sha256 ${KERNEL_SHA256}; tag ${KERNEL_TAG})"

tar -xzf "$ARCHIVE" -C "$WORK"
if [ "$(cat "$WORK/$KERNEL_FOLDER/VERSION")" != "$KERNEL_VERSION" ]; then
  echo "ERROR: archive VERSION is not ${KERNEL_VERSION}" >&2
  exit 1
fi

rm -rf "$REPO_ROOT/kernel"
mv "$WORK/$KERNEL_FOLDER" "$REPO_ROOT/kernel"
echo "Kernel ${KERNEL_VERSION} extracted to ${REPO_ROOT}/kernel"
echo "Next: make precompile SHEN=<working-shen> && make build-sbcl"
