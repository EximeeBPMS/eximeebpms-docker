#!/bin/bash -eux

EE=${EE:-false}
VERSION=${VERSION:-$(grep VERSION= Dockerfile | head -n1 | cut -d = -f 2)}
DISTRO=${DISTRO:-$(grep DISTRO= Dockerfile | cut -d = -f 2)}
SNAPSHOT=${SNAPSHOT:-$(grep SNAPSHOT= Dockerfile | cut -d = -f 2)}
PLATFORMS=${PLATFORMS:-linux/amd64}

IMAGE='ghcr.io/eximeebpms/eximeebpms-bpm-platform'

function build_and_push {
    local tags=("$@")
    printf -v tag_arguments -- "--tag $IMAGE:%s " "${tags[@]}"
    docker buildx build .               \
        $tag_arguments                  \
        --build-arg DISTRO=${DISTRO}    \
        --build-arg EE=${EE}            \
        --build-arg VERSION=${VERSION}  \
        --platform $PLATFORMS           \
        --push

      echo "Tags released:" >> $GITHUB_STEP_SUMMARY
      printf -- "- $IMAGE:%s\n" "${tags[@]}" >> $GITHUB_STEP_SUMMARY
}

if [ "${EE}" = "true" ]; then
    echo "Not pushing EE image to docker hub"
    exit 0
fi

# check whether the CE image for distro was already released and exit in that case
if [ $(docker manifest inspect $IMAGE:${DISTRO}-${VERSION} > /dev/null ; echo $?) == '0' ]; then
    echo "Not pushing already released CE image"
    exit 0
fi

echo "${GHCR_PASSWORD}" | docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin

tags=()

if [ "${SNAPSHOT}" = "true" ]; then
    tags+=("${DISTRO}-${VERSION}-SNAPSHOT")
    tags+=("${DISTRO}-SNAPSHOT")

    if [ "${DISTRO}" = "tomcat" ]; then
        tags+=("${VERSION}-SNAPSHOT")
        tags+=("SNAPSHOT")
    fi
else
    tags+=("${DISTRO}-${VERSION}")
    if [ "${DISTRO}" = "tomcat" ]; then
        tags+=("${VERSION}")
    fi
fi

# Latest Docker image is created and pushed just once when a new version is relased.
# Latest tag refers to the latest minor release of EximeeBPMS.
# https://github.com/EximeeBPMS/eximeebpms-docker/blob/next/README.md#supported-tagsreleases
# The 1st condition matches only when the version branch is the same as the main branch.
git fetch origin next
if [ $(git rev-parse HEAD) = $(git rev-parse FETCH_HEAD) ] && [ "${SNAPSHOT}" = "false" ]; then
    # tagging image as latest
    tags+=("${DISTRO}-latest")
    tags+=("${DISTRO}")
    if [ "${DISTRO}" = "tomcat" ]; then
        tags+=("latest")
    fi
fi

build_and_push "${tags[@]}"
