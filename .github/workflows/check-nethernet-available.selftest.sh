#!/usr/bin/env bash
# Runs check-nethernet-available.sh against fixture versions and logs, so a
# pattern that no longer matches fails here rather than letting a RakNet-only
# image pass the boot step.
set -uo pipefail

CHECK="$(dirname "$0")/check-nethernet-available.sh"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
FAILED=0

DONE='[12:00:02.000] [Server thread/INFO]: Done (1.234s)! For help, type "help" or "?"'
SKIPPED='[12:00:01.000] [Server thread/WARNING]: Transport nethernet is unavailable and will be skipped: the axolotl-pm/ext-webrtc extension is not loaded'
DEPRECATED='[12:00:01.000] [Server thread/WARNING]: RakNet is deprecated and will be removed in a future release. Please use NetherNet instead.'

expect() {
  local want="$1" name="$2" version="$3" got=0
  shift 3
  printf '[12:00:00.000] [Server thread/INFO]: Starting server\n' > "$DIR/$name.log"
  printf '%s\n' "$@" >> "$DIR/$name.log"
  bash "$CHECK" "$version" "$DIR/$name.log" > /dev/null 2>&1 || got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL $name: exit $got, expected $want"
    FAILED=1
  else
    echo "ok   $name"
  fi
}

expect 0 nethernet-started 0.3.1 "$DEPRECATED" "$DONE"
expect 0 later-patch 0.3.12 "$DONE"
expect 1 no-extension "" "$SKIPPED" "$DEPRECATED" "$DONE"
expect 1 extension-but-skipped 0.3.1 "$SKIPPED" "$DONE"
expect 1 skipped-with-other-reason 0.3.1 '[12:00:01.000] [Server thread/WARNING]: Transport nethernet is unavailable and will be skipped: ext-webrtc ^0.3.1 is required (found 0.2.0)' "$DONE"
expect 1 extension-missing-log-clean "" "$DONE"
expect 1 extension-too-old 0.2.9 "$DONE"
expect 1 extension-below-minimum-patch 0.3.0 "$DONE"
expect 1 extension-too-new 0.4.0 "$DONE"
expect 1 version-with-suffix 0.3.1-dev "$DONE"
expect 1 never-done 0.3.1 "$DEPRECATED"

got=0
bash "$CHECK" 0.3.1 "$DIR/missing.log" > /dev/null 2>&1 || got=$?
if [ "$got" != 2 ]; then
  echo "FAIL missing-log: exit $got, expected 2"
  FAILED=1
else
  echo "ok   missing-log"
fi

got=0
bash "$CHECK" 0.3.1 > /dev/null 2>&1 || got=$?
if [ "$got" != 2 ]; then
  echo "FAIL one-argument: exit $got, expected 2"
  FAILED=1
else
  echo "ok   one-argument"
fi

exit "$FAILED"
