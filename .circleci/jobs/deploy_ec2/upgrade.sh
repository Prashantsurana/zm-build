#!/bin/bash

set -euo pipefail

[ -d .circleci ] || exit 1
[ "$APP1_SSH_USER" ] || exit 1;
[ "$APP1_SSH_HOST" ] || exit 1;
[ "$APP1_ADMIN_PASS" ] || exit 1;

source .circleci/get-env.sh;

SSH_OPTS=(
   "-o" "UserKnownHostsFile=/dev/null"
   "-o" "StrictHostKeyChecking=no"
   "-o" "CheckHostIP=no"
   "-o" "ServerAliveInterval=100"
)

Rsync()
{
   rsync -e "ssh ${SSH_OPTS[*]}" "$@"
}

Ssh()
{
   ssh "${SSH_OPTS[@]}" "$@"
}

DIR=$(echo ../BUILDS/UBUNTU16_64* | head -1); [ -d "$DIR" ] || exit 1;

#Rsync --delete -avz ~/zm-build "$APP1_SSH_USER@$APP1_SSH_HOST:"
Rsync --delete -avz "$DIR/" "$APP1_SSH_USER@$APP1_SSH_HOST:BUILD/"
Rsync .circleci/jobs/deploy_ec2/upgrade.conf.in "$APP1_SSH_USER@$APP1_SSH_HOST:BUILD/upgrade.conf.in"

Ssh "$APP1_SSH_USER@$APP1_SSH_HOST" -- "DOMAIN_NAME=$APP1_SSH_HOST" "ADMIN_PASS=$APP1_ADMIN_PASS" bash -s <<"SCRIPT_EOM"
set -euxo pipefail

for archives in $HOME/BUILD/archives/*
do
   echo "deb [trusted=yes] file://$archives ./"
done | sudo tee /etc/apt/sources.list.d/zimbra-local.list
sudo apt-get update -qq

echo -----------------------------------
echo Uncompress tarball
echo -----------------------------------

tar -C ~/WDIR -xzf BUILD/zcs-*.tgz

echo -----------------------------------
echo Upgrade/Install
echo -----------------------------------

cd ~/WDIR/zcs-*/;
sudo ./install.sh ~/BUILD/upgrade.conf.in

echo -----------------------------------
echo UPGRADE FINISHED
echo -----------------------------------
SCRIPT_EOM

echo DEPLOY FINISHED - https://$APP1_SSH_HOST/
