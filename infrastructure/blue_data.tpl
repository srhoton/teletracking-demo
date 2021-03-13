#!/bin/bash
echo "starting user config"

export DEBIAN_FRONTEND=noninteractive
echo "doing update"
apt-get -qy update
echo "doing upgrade"
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade
echo "doing docker install"
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" install docker.io
echo "enabling docker"
systemctl enable docker
echo "starting docker"
systemctl start docker
echo "pulling image"
docker pull sprhoto/blue-machine:latest
echo "running image"
docker run -d --name blue-machine -p 8080:80 sprhoto/blue-machine:latest
echo "Completed." 
