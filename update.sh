#!/bin/bash

API_VERSION=$(cat API_VERSION)
FRONTEND_VERSION=$(cat FRONTEND_VERSION)
ROUTER_VERSION=$(cat ROUTER_VERSION)

echo "API_VERSION: $API_VERSION"
echo "FRONTEND_VERSION: $FRONTEND_VERSION"
echo "ROUTER_VERSION: $ROUTER_VERSION"

exit 0

if [ "$1" != '--prerelease' ] && \
   ([ "$(./semver.sh get prerelease $API_VERSION)" != '' ] || \
   [ "$(./semver.sh get prerelease $FRONTEND_VERSION)" != '' ] || \
   [ "$(./semver.sh get prerelease $ROUTER_VERSION)" != '' ])
then
    echo "INFO: Contains prerelease, ignoring";
    exit 0
fi

# Check if API_VERSION and FRONTEND_VERSION are compatible

part="major"
if [ $(./semver.sh get major $API_VERSION) -eq 0 ]; then
    part="minor"
fi

if [ $(./semver.sh get $part $API_VERSION) -ne $(./semver.sh get $part $FRONTEND_VERSION) ]; then
    echo "INFO: API_VERSION and FRONTEND_VERSION are not compatible, ignoring"
    exit
fi

# Update docker-compose.yml with new versions

cat docker-compose.tmpl.yml |
    sed "s/API_VERSION/$API_VERSION/" |
    sed "s/FRONTEND_VERSION/$FRONTEND_VERSION/" |
    sed "s/ROUTER_VERSION/$ROUTER_VERSION/" > docker-compose.yml
