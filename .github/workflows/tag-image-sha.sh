#!/usr/bin/env bash
# Gives the image this run built one more tag, <repository>:<full commit sha>,
# so riftal-infra's CI can run one exact core build (riftal-infra#363). Only a
# push to riftal tags: a pull request head is code no one has approved, and a
# sha tag from one would let a pin point at it. Every other run still resolves
# and checks the image, so each pull_request run proves the path a push takes,
# short of the tag itself.
#
# Each runner's sidecar daemon holds the pinned tags, and the conductor's
# set-pins and sync-images own every one of them, so the sha tag is the only
# one this adds. An existing sha tag is never moved: it may already be
# riftal-infra's pin, and the image it names passed every smoke step in the
# run that tagged it. One at another ID is left as it is, with a warning.
#
# The image is named by the ID the build reported, never by a tag, and must
# carry this run's revision label, or nothing is tagged.
#
# Nothing here removes a tag. riftal-infra pins one sha tag, and only a
# cleanup that knows which one may ever remove the others.
#
# Usage: tag-image-sha.sh <repository> <image id>
# Reads GITHUB_EVENT_NAME, GITHUB_REF and GITHUB_SHA, which Actions sets.
set -euo pipefail

if [ "$#" != 2 ]; then
  echo "usage: tag-image-sha.sh <repository> <image id>" >&2
  exit 2
fi
IMAGE="$1"
BUILT="$2"
EVENT="${GITHUB_EVENT_NAME:-}"
REF="${GITHUB_REF:-}"
SHA="${GITHUB_SHA:-}"
LABEL=org.opencontainers.image.revision

if ! [[ "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::GITHUB_SHA '$SHA' is not a full commit sha, so no tag can name it"
  exit 1
fi

if ! [[ "$BUILT" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "::error::'$BUILT' is not a sha256 image ID, so it cannot pin the image this run built"
  exit 1
fi

if ! ID="$(docker image inspect --format '{{.Id}}' "$BUILT")" || [ -z "$ID" ]; then
  echo "::error::no image $BUILT on this daemon to tag"
  exit 1
fi

REVISION="$(docker image inspect --format "{{index .Config.Labels \"$LABEL\"}}" "$ID")"
if [ "$REVISION" != "$SHA" ]; then
  echo "::error::$ID has $LABEL '$REVISION', not this run's $SHA; it is not the image this run built, so it is not tagged"
  exit 1
fi

if [ "$EVENT" != push ] || [ "$REF" != refs/heads/riftal ]; then
  echo "$ID is built from $SHA; not tagging it, this is a $EVENT run on $REF and only a push to riftal is tagged"
  exit 0
fi

TAG="$IMAGE:$SHA"
ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT
if HELD="$(docker image inspect --format '{{.Id}}' "$TAG" 2>"$ERR")"; then
  if [ "$HELD" = "$ID" ]; then
    echo "$TAG already names $ID, so it is left as it is"
  else
    echo "::warning::$TAG already names $HELD, not the $ID this run built; it is left as it is, since it may be riftal-infra's pin"
  fi
  exit 0
fi
# Any lookup failure but an absent tag stops here, so a daemon error never
# reads as a free name.
if ! grep -qF 'No such image' "$ERR"; then
  echo "::error::could not look up $TAG: $(cat "$ERR")"
  exit 1
fi

docker tag "$ID" "$TAG"
TAGGED="$(docker image inspect --format '{{.Id}}' "$TAG")"
if [ "$TAGGED" != "$ID" ]; then
  echo "::error::$TAG resolves to $TAGGED, not the $ID this run built"
  exit 1
fi
echo "tagged $ID as $TAG"
