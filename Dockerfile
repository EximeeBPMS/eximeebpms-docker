FROM alpine:3.18 AS builder

ARG VERSION=0.9.0
ARG DISTRO=tomcat
ARG SNAPSHOT=true

ARG EE=false
ARG USER
ARG PASSWORD

ARG MAVEN_PROXY_HOST
ARG MAVEN_PROXY_PORT
ARG MAVEN_PROXY_USER
ARG MAVEN_PROXY_PASSWORD

ARG POSTGRESQL_VERSION
ARG MYSQL_VERSION

ARG JMX_PROMETHEUS_VERSION=0.12.0

RUN apk add --no-cache \
        bash \
        ca-certificates \
        maven \
        tar \
        wget \
        xmlstarlet

COPY settings.xml download.sh eximeebpms-run.sh eximeebpms-tomcat.sh eximeebpms-wildfly.sh  /tmp/
COPY .m2 / /m2-repository/

RUN /tmp/download.sh
COPY eximeebpms-lib.sh /eximeebpms/


##### FINAL IMAGE #####

FROM alpine:3.18

ARG VERSION=0.9.0

ENV DB_DRIVER=
ENV DB_URL=
ENV DB_USERNAME=
ENV DB_PASSWORD=
ENV DB_CONN_MAXACTIVE=20
ENV DB_CONN_MINIDLE=5
ENV DB_CONN_MAXIDLE=20
ENV DB_VALIDATE_ON_BORROW=false
ENV DB_VALIDATION_QUERY="SELECT 1"
ENV SKIP_DB_CONFIG=
ENV WAIT_FOR=
ENV WAIT_FOR_TIMEOUT=30
ENV TZ=UTC
ENV DEBUG=false
ENV JAVA_OPTS=""
ENV JMX_PROMETHEUS=false
ENV JMX_PROMETHEUS_CONF=/eximeebpms/javaagent/prometheus-jmx.yml
ENV JMX_PROMETHEUS_PORT=9404

EXPOSE 8080 8000 9404

# Downgrading wait-for-it is necessary until this PR is merged
# https://github.com/vishnubob/wait-for-it/pull/68
RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        openjdk17-jre-headless \
        tzdata \
        tini \
        xmlstarlet \
    && curl -o /usr/local/bin/wait-for-it.sh \
      "https://raw.githubusercontent.com/vishnubob/wait-for-it/a454892f3c2ebbc22bd15e446415b8fcb7c1cfa4/wait-for-it.sh" \
    && chmod +x /usr/local/bin/wait-for-it.sh

RUN addgroup -g 1000 -S eximeebpms && \
    adduser -u 1000 -S eximeebpms -G eximeebpms -h /eximeebpms -s /bin/bash -D eximeebpms
WORKDIR /eximeebpms
USER eximeebpms

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./eximeebpms.sh"]

COPY --chown=eximeebpms:eximeebpms --from=builder /eximeebpms .