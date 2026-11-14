#!/bin/bash
#
# Build a binary Debian package and keep every generated artifact in dist/.
#
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(dpkg-parsechangelog -SVersion)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
DIST="$PWD/dist"
LOG="$DIST/dpkg-build-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$DIST"

echo "Building ircam-viewer ${VERSION} for ${ARCH}..."
dpkg-buildpackage -us -uc -b 2>&1 | tee "$LOG"

for file in \
	"../ircam-viewer_${VERSION}_${ARCH}.deb" \
	"../ircam-viewer-dbgsym_${VERSION}_${ARCH}.ddeb" \
	"../ircam-viewer_${VERSION}_${ARCH}.changes" \
	"../ircam-viewer_${VERSION}_${ARCH}.buildinfo"
do
	if [ -e "$file" ]; then
		mv -f "$file" "$DIST/"
	fi
done

echo
echo "Artifacts in $DIST:"
ls -lh "$DIST"
