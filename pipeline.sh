#!/bin/bash -ex

if [ -z "$SNAPSHOT" ]; then
  SNAPSHOT_ARGUMENT=""
else
  SNAPSHOT_ARGUMENT="--build-arg SNAPSHOT=${SNAPSHOT}"
fi

if [ -z "$VERSION" ]; then
  VERSION_ARGUMENT=""
else
  VERSION_ARGUMENT="--build-arg VERSION=${VERSION}"
fi

IMAGE_NAME=eximeebpms/eximeebpms-bpm-platform:${DISTRO}-${PLATFORM}

docker buildx build .                         \
    -t "${IMAGE_NAME}"                        \
    --platform linux/${PLATFORM}              \
    --build-arg DISTRO=${DISTRO}              \
    ${VERSION_ARGUMENT}                       \
    ${SNAPSHOT_ARGUMENT}                      \
    --cache-to type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
    --cache-from type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
    --load

docker inspect "${IMAGE_NAME}" | grep "Architecture" -A2
