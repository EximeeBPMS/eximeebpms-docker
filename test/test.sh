#!/bin/bash -xeu

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd ${DIR}

source test_helper.sh

docker-compose up --force-recreate -d postgres mysql
./test-${DISTRO}.sh eximeebpms
./test-${DISTRO}.sh eximeebpms-mysql
./test-${DISTRO}.sh eximeebpms-postgres
./test-debug.sh eximeebpms-debug
docker-compose down -v
cd -
