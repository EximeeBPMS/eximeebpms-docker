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

# Fetch the distribution archive.
#
# Released versions come from the GitHub Release of the matching tag: as of 1.4.0 the server
# distributions are published as release assets, not Maven Central artifacts (BPMS-760, and the
# same place operaton publishes its own). Central keeps the consumable libraries; a 230MB
# application-server install is not something anyone resolves as a <dependency>, and staging all
# of them made the release's upload bundle too large to encode within the CI runner's memory.
#
# SNAPSHOT builds still come from Central's snapshot repository - snapshots are published by a
# plain deploy with no bundle involved, and there is no GitHub Release to attach them to.
if [ "${SNAPSHOT}" = "true" ]; then
    mvn dependency:get -B --global-settings /tmp/settings.xml \
        $PROXY \
        -DgroupId="${ARTIFACT_GROUP}" -DartifactId="${ARTIFACT}" \
        -Dversion="${ARTIFACT_VERSION}" -Dpackaging="tar.gz" -Dtransitive=false

    cambpm_distro_file=$(find /m2-repository -name "${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz" -print | head -n 1)
else
    # wget reads proxy settings from the environment, not from the -D flags Maven takes.
    if [ -n "$MAVEN_PROXY_HOST" ]; then
        proxy_auth=""
        if [ -n "$MAVEN_PROXY_USER" ]; then
            proxy_auth="${MAVEN_PROXY_USER}"
            [ -n "$MAVEN_PROXY_PASSWORD" ] && proxy_auth="${proxy_auth}:${MAVEN_PROXY_PASSWORD}"
            proxy_auth="${proxy_auth}@"
        fi
        http_proxy="http://${proxy_auth}${MAVEN_PROXY_HOST}:${MAVEN_PROXY_PORT}"
        https_proxy="$http_proxy"
        export http_proxy https_proxy
        echo "PROXY set for wget"
    fi

    cambpm_distro_file="/tmp/${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"
    wget -O "$cambpm_distro_file" \
        "https://github.com/EximeeBPMS/eximeebpms/releases/download/v${ARTIFACT_VERSION}/${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"
fi

if [ ! -s "$cambpm_distro_file" ]; then
    echo "ERROR: distribution archive for ${ARTIFACT} ${ARTIFACT_VERSION} was not downloaded"
    exit 1
fi

# Unpack distro to /eximeebpms directory
mkdir -p /eximeebpms
case ${DISTRO} in
    run*) tar xzf "$cambpm_distro_file" -C /eximeebpms;;
    *)    tar xzf "$cambpm_distro_file" -C /eximeebpms server --strip 2;;
esac
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

# Copy to correct locations depending on distro type
case ${DISTRO} in
    run*)
        cp /tmp/mysql-connector-j-${MYSQL_VERSION}.jar /eximeebpms/configuration/userlib
        cp /tmp/postgresql-${POSTGRESQL_VERSION}.jar /eximeebpms/configuration/userlib
        ;;
    tomcat*)
        cp /tmp/mysql-connector-j-${MYSQL_VERSION}.jar /eximeebpms/lib
        cp /tmp/postgresql-${POSTGRESQL_VERSION}.jar /eximeebpms/lib
        # remove default CATALINA_OPTS from environment settings
        echo "" > /eximeebpms/bin/setenv.sh
        ;;
esac
