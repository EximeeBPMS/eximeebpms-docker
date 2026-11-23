#!/bin/bash -eux

VERSION=${VERSION:-$(grep VERSION= Dockerfile | head -n1 | cut -d = -f 2)}
DISTRO=${DISTRO:-$(grep DISTRO= Dockerfile | cut -d = -f 2)}
SNAPSHOT=${SNAPSHOT:-$(grep SNAPSHOT= Dockerfile | cut -d = -f 2)}
PLATFORMS=${PLATFORMS:-linux/amd64}
# 'false' publishes the version tags only, so republishing an older version leaves `latest` where it is.
TAG_LATEST=${TAG_LATEST:-true}
case "${TAG_LATEST}" in
    true|false) ;;
    *) echo "TAG_LATEST must be 'true' or 'false', got '${TAG_LATEST}'" >&2; exit 1 ;;
esac

IMAGE='ghcr.io/eximeebpms/eximeebpms-bpm-platform'

function build_and_push {
    local tags=("$@")
    printf -v tag_arguments -- "--tag $IMAGE:%s " "${tags[@]}"
    docker buildx build .               \
        $tag_arguments                  \
        --build-arg DISTRO=${DISTRO}    \
        --build-arg VERSION=${VERSION}  \
        --platform $PLATFORMS           \
        --push

      echo "Tags released:" >> $GITHUB_STEP_SUMMARY
      printf -- "- $IMAGE:%s\n" "${tags[@]}" >> $GITHUB_STEP_SUMMARY
}

## check whether the CE image for distro was already released and exit in that case
#if [ $(docker manifest inspect $IMAGE:${DISTRO}-${VERSION} > /dev/null ; echo $?) == '0' ]; then
#    echo "Not pushing already released CE image"
#    exit 0
#fi

echo "${GHCR_PASSWORD}" | docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin

tags=()
tags+=("${DISTRO}-${VERSION}")
if [ "${TAG_LATEST}" == "true" ]; then
  tags+=("${DISTRO}-latest")
  if [ "$DISTRO" == "run" ]; then
    tags+=("latest")
  fi
fi

build_and_push "${tags[@]}"
