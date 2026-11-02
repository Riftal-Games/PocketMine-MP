#!/usr/bin/env bash
# Gives the image this run built two more tags: <repository>:<full commit sha>,
# so riftal-infra's CI can run one exact core build and never the moving bare
# tag (riftal-infra#363), and the bare <repository>, which every rig and
# bot-proofs boot (#274). Only a push to riftal tags: a pull request head is
# code no one has approved, a sha tag from one would let a pin point at it, and
# the bare tag from one would put every rig on it. Every other run still
# resolves and checks the image, so each pull_request run proves the path a
# push takes, short of the tags themselves.
#
# The riftal runners share one docker daemon, so another run can rebuild the
# bare tag at any time. The image is named by the ID the build reported, never
# by the tag, and must carry this run's revision label, or nothing is tagged.
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

# The sha tag first, so the bare tag never names a build riftal-infra cannot pin.
for TAG in "$SHA" latest; do
  docker tag "$ID" "$IMAGE:$TAG"
  TAGGED="$(docker image inspect --format '{{.Id}}' "$IMAGE:$TAG")"
  if [ "$TAGGED" != "$ID" ]; then
    echo "::error::$IMAGE:$TAG resolves to $TAGGED, not the $ID this run built"
    exit 1
  fi
  echo "tagged $ID as $IMAGE:$TAG"
done
