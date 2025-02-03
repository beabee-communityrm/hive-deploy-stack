#!/bin/bash

VERSION=$(cat VERSION)

exit 0

if [ "$1" != '--prerelease' ] && \
   [ "$(./semver.sh get prerelease $VERSION)" != '' ]
then
    echo "INFO: Contains prerelease, ignoring";
    exit 0
fi

# Update docker-compose.yml with new versions

cat docker-compose.tmpl.yml |
    sed "s/__VERSION__/$VERSION/" > docker-compose.yml
