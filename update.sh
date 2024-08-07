#!/bin/bash

exit 0;

API_VERSION=$(cat API_VERSION)
FRONTEND_VERSION=$(cat FRONTEND_VERSION)
ROUTER_VERSION=$(cat ROUTER_VERSION)

echo "API_VERSION: $API_VERSION"
echo "FRONTEND_VERSION: $FRONTEND_VERSION"
echo "ROUTER_VERSION: $ROUTER_VERSION"

# Check if API_VERSION and FRONTEND_VERSION are compatible

part="major"
if [ $(./semver.sh get major ${API_VERSION:1}) -eq 0 ]; then
    part="minor"
fi

if [ $(./semver.sh get $part ${API_VERSION:1}) -ne $(./semver.sh get $part ${FRONTEND_VERSION:1}) ]; then
    echo "API_VERSION and FRONTEND_VERSION are not compatible, ignoring"
    exit
fi

# Update docker-compose.yml with new versions

cat docker-compose.tmpl.yml |
    sed "s/API_VERSION/$API_VERSION/" |
    sed "s/FRONTEND_VERSION/$FRONTEND_VERSION/" |
    sed "s/ROUTER_VERSION/$ROUTER_VERSION/" > docker-compose.yml
