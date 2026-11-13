#!/usr/bin/env bash
# Fails unless the image's PHP reports ext-webrtc at 0.3.x and the server's
# boot log has no line saying the nethernet transport was skipped.
# NetherNetTransport takes webrtc >= 0.3.1 and < 0.4.0. Without the extension
# the server still reaches Done and exits 0 on RakNet alone, logging only a
# warning, so every other boot step passes on an image no NetherNet client
# can join.
#
# Usage: check-nethernet-available.sh <phpversion("webrtc") output> <boot log>
set -euo pipefail

if [ "$#" != 2 ]; then
  echo "usage: check-nethernet-available.sh <webrtc version> <boot log>" >&2
  exit 2
fi
VERSION="$1"
LOG="$2"
if [ ! -f "$LOG" ]; then
  echo "::error::no log at $LOG, so the transport check has nothing to read"
  exit 2
fi

FAILED=0
if [[ "$VERSION" =~ ^0\.3\.[0-9]+$ ]]; then
  echo "ext-webrtc $VERSION is loaded"
else
  echo "::error::the image's PHP reports ext-webrtc '$VERSION', expected 0.3.x"
  FAILED=1
fi

HITS="$(grep -nF "Transport nethernet is unavailable" "$LOG" || true)"
if [ -n "$HITS" ]; then
  echo "::error::the server skipped the nethernet transport"
  echo "$HITS"
  FAILED=1
elif ! grep -qF "Done (" "$LOG"; then
  echo "::error::$LOG never reaches Done, so the transport may not have started"
  FAILED=1
else
  echo "no skipped nethernet transport in $LOG"
fi
exit "$FAILED"
