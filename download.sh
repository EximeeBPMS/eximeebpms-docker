#!/bin/sh -ex

# Determine GitHub Packages URL parameters
if [ "${EE}" = "true" ]; then
    echo "Downloading EximeeBPMS ${VERSION} Enterprise Edition for ${DISTRO}"
    REPO="private"
    GITHUB_GROUP="private"
    ARTIFACT="eximeebpms-bpm-ee-${DISTRO}"
    if [ "${DISTRO}" = "run" ]; then
      ARTIFACT="eximeebpms-bpm-run-ee"
    fi
    ARTIFACT_VERSION="${VERSION}-ee"
else
    echo "Downloading EximeeBPMS ${VERSION} Community Edition for ${DISTRO}"
    REPO="eximeebpms-bpm"
    GITHUB_GROUP="public"
    ARTIFACT="eximeebpms-bpm-${DISTRO}"
    ARTIFACT_VERSION="${VERSION}"
fi

# Determine if SNAPSHOT repo and version should be used
if [ ${SNAPSHOT} = "true" ]; then
    if [ "${EE}" = "false" ]; then
        REPO="${REPO}-snapshots"
    fi
    ARTIFACT_VERSION="${VERSION}-SNAPSHOT"
fi

# Determine artifact group
case ${DISTRO} in
    wildfly*) GROUP="wildfly" ;;
    *) GROUP="${DISTRO}" ;;
esac
ARTIFACT_GROUP="org.eximeebpms.bpm.${GROUP}"

# Download distro from GitHub Packages
PROXY=""
if [ -n "$MAVEN_PROXY_HOST" ] ; then
    PROXY="-DproxySet=true"
    PROXY="$PROXY -Dhttp.proxyHost=$MAVEN_PROXY_HOST"
    PROXY="$PROXY -Dhttps.proxyHost=$MAVEN_PROXY_HOST"
    if [ -z "$MAVEN_PROXY_PORT" ] ; then
        echo "ERROR: MAVEN_PROXY_PORT must be set when MAVEN_PROXY_HOST is set"
        exit 1
    fi
    PROXY="$PROXY -Dhttp.proxyPort=$MAVEN_PROXY_PORT"
    PROXY="$PROXY -Dhttps.proxyPort=$MAVEN_PROXY_PORT"
    echo "PROXY set Maven proxyHost and proxyPort"
    if [ -n "$MAVEN_PROXY_USER" ] ; then
        PROXY="$PROXY -Dhttp.proxyUser=$MAVEN_PROXY_USER"
        PROXY="$PROXY -Dhttps.proxyUser=$MAVEN_PROXY_USER"
        echo "PROXY set Maven proxyUser"
    fi
    if [ -n  "$MAVEN_PROXY_PASSWORD" ] ; then
        PROXY="$PROXY -Dhttp.proxyPassword=$MAVEN_PROXY_PASSWORD"
        PROXY="$PROXY -Dhttps.proxyPassword=$MAVEN_PROXY_PASSWORD"
        echo "PROXY set Maven proxyPassword"
    fi
fi

# GitHub Packages URL with repository
mvn dependency:get -U -B --global-settings /tmp/settings.xml \
    $PROXY \
    -DremoteRepositories="github-packages::::https://maven.pkg.github.com/EximeeBPMS/eximeebpms" \
    -DgroupId="${ARTIFACT_GROUP}" -DartifactId="${ARTIFACT}" \
    -Dversion="${ARTIFACT_VERSION}" -Dpackaging="tar.gz" -Dtransitive=false

cambpm_distro_file=$(find /m2-repository -name "${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz" -print | head -n 1)

# Unpack distro to /eximeebpms directory
mkdir -p /eximeebpms
case ${DISTRO} in
    run*) tar xzf "$cambpm_distro_file" -C /eximeebpms;;
    *)    tar xzf "$cambpm_distro_file" -C /eximeebpms server --strip 2;;
esac
cp /tmp/eximeebpms-${GROUP}.sh /eximeebpms/eximeebpms.sh

# download and register database drivers from GitHub Packages
mvn dependency:get -U -B --global-settings /tmp/settings.xml \
    $PROXY \
    -DremoteRepositories="github-packages::::https://maven.pkg.github.com/EximeeBPMS/eximeebpms" \
    -DgroupId="org.eximeebpms.bpm" -DartifactId="eximeebpms-database-settings" \
    -Dversion="${ARTIFACT_VERSION}" -Dpackaging="pom" -Dtransitive=false

cambpmdbsettings_pom_file=$(find /m2-repository -name "eximeebpms-database-settings-${ARTIFACT_VERSION}.pom" -print | head -n 1)
if [ -z "$MYSQL_VERSION" ]; then
    MYSQL_VERSION=$(xmlstarlet sel -t -v //_:version.mysql $cambpmdbsettings_pom_file)
fi
if [ -z "$POSTGRESQL_VERSION" ]; then
    POSTGRESQL_VERSION=$(xmlstarlet sel -t -v //_:version.postgresql $cambpmdbsettings_pom_file)
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
    wildfly*)
        cat <<-EOF > batch.cli
batch
embed-server --std-out=echo

module add --name=com.mysql.mysql-connector-j --slot=main --resources=/tmp/mysql-connector-j-${MYSQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=mysql:add(driver-name="mysql",driver-module-name="com.mysql.mysql-connector-j",driver-xa-datasource-class-name=com.mysql.cj.jdbc.MysqlXADataSource)

module add --name=org.postgresql.postgresql --slot=main --resources=/tmp/postgresql-${POSTGRESQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=postgresql:add(driver-name="postgresql",driver-module-name="org.postgresql.postgresql",driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)

run-batch
EOF
        /eximeebpms/bin/jboss-cli.sh --file=batch.cli
        rm -rf /eximeebpms/standalone/configuration/standalone_xml_history/current/*
        ;;
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

# download Prometheus JMX Exporter
mvn dependency:copy -B \
    $PROXY \
    -Dartifact="io.prometheus.jmx:jmx_prometheus_javaagent:${JMX_PROMETHEUS_VERSION}:jar" \
    -DoutputDirectory=/tmp/

mkdir -p /eximeebpms/javaagent
cp /tmp/jmx_prometheus_javaagent-${JMX_PROMETHEUS_VERSION}.jar /eximeebpms/javaagent/jmx_prometheus_javaagent.jar
