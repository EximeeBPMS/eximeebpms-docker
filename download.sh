#!/bin/sh -ex


echo "Downloading EximeeBPMS ${VERSION} Community Edition for ${DISTRO}"
REPO="eximeebpms-bpm"
GITHUB_GROUP="public"
ARTIFACT="eximeebpms-bpm-${DISTRO}"
ARTIFACT_VERSION="${VERSION}"

# Determine if SNAPSHOT repo and version should be used
if [ "${SNAPSHOT}" = "true" ]; then
    ARTIFACT_VERSION="${VERSION}-SNAPSHOT"
fi

ARTIFACT_GROUP="org.eximeebpms.bpm.${DISTRO}"

# Download distro from GitHub Packages
PROXY=""
if [ -n "$MAVEN_PROXY_HOST" ]; then
    PROXY="-DproxySet=true"
    PROXY="$PROXY -Dhttp.proxyHost=$MAVEN_PROXY_HOST"
    PROXY="$PROXY -Dhttps.proxyHost=$MAVEN_PROXY_HOST"
    if [ -z "$MAVEN_PROXY_PORT" ]; then
        echo "ERROR: MAVEN_PROXY_PORT must be set when MAVEN_PROXY_HOST is set"
        exit 1
    fi
    PROXY="$PROXY -Dhttp.proxyPort=$MAVEN_PROXY_PORT"
    PROXY="$PROXY -Dhttps.proxyPort=$MAVEN_PROXY_PORT"
    echo "PROXY set Maven proxyHost and proxyPort"
    if [ -n "$MAVEN_PROXY_USER" ]; then
        PROXY="$PROXY -Dhttp.proxyUser=$MAVEN_PROXY_USER"
        PROXY="$PROXY -Dhttps.proxyUser=$MAVEN_PROXY_USER"
        echo "PROXY set Maven proxyUser"
    fi
    if [ -n "$MAVEN_PROXY_PASSWORD" ]; then
        PROXY="$PROXY -Dhttp.proxyPassword=$MAVEN_PROXY_PASSWORD"
        PROXY="$PROXY -Dhttps.proxyPassword=$MAVEN_PROXY_PASSWORD"
        echo "PROXY set Maven proxyPassword"
    fi
fi

# GitHub Packages URL with repository
mvn dependency:get -B --global-settings /tmp/settings.xml \
    $PROXY \
    -DgroupId="${ARTIFACT_GROUP}" -DartifactId="${ARTIFACT}" \
    -Dversion="${ARTIFACT_VERSION}" -Dpackaging="tar.gz" -Dtransitive=false

cambpm_distro_file=$(find /m2-repository -name "${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz" -print | head -n 1)

# Unpack distro to /eximeebpms directory
mkdir -p /eximeebpms
tar xzf "$cambpm_distro_file" -C /eximeebpms
cp /tmp/eximeebpms-${DISTRO}.sh /eximeebpms/eximeebpms.sh

# download and register database drivers from GitHub Packages
mvn dependency:get -B --global-settings /tmp/settings.xml \
    $PROXY \
    -DgroupId="org.eximeebpms.bpm" -DartifactId="eximeebpms-database-settings" \
    -Dversion="${ARTIFACT_VERSION}" -Dpackaging="pom" -Dtransitive=false

cambpmdbsettings_pom_file=$(find /m2-repository -name "eximeebpms-database-settings-${ARTIFACT_VERSION}.pom" -print | head -n 1)
if [ -z "$MYSQL_VERSION" ]; then
    MYSQL_VERSION=$(xmlstarlet sel -t -v //_:version.mysql "$cambpmdbsettings_pom_file")
fi
if [ -z "$POSTGRESQL_VERSION" ]; then
    POSTGRESQL_VERSION=$(xmlstarlet sel -t -v //_:version.postgresql "$cambpmdbsettings_pom_file")
fi

mvn dependency:copy -B \
    $PROXY \
    -Dartifact="com.mysql:mysql-connector-j:${MYSQL_VERSION}:jar" \
    -DoutputDirectory=/tmp/
mvn dependency:copy -B \
    $PROXY \
    -Dartifact="org.postgresql:postgresql:${POSTGRESQL_VERSION}:jar" \
    -DoutputDirectory=/tmp/

# Place drivers in run-specific location
cp /tmp/mysql-connector-j-${MYSQL_VERSION}.jar /eximeebpms/configuration/userlib
cp /tmp/postgresql-${POSTGRESQL_VERSION}.jar /eximeebpms/configuration/userlib
