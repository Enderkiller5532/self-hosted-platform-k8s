# TeamCity

This directory contains a simple example for installing TeamCity on a Linux server.

## Create a service account

```bash
adduser teamcity
```

## Install dependencies and TeamCity

```bash
apt update && apt install wget java-common -y
cd /opt
wget https://download.jetbrains.com/teamcity/TeamCity-2022.10.1.tar.gz
tar xfz TeamCity-2022.10.1.tar.gz
wget https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.deb
dpkg --install amazon-corretto-21-x64-linux-jdk.deb
chown -R teamcity:teamcity TeamCity
```

## Start the server

```bash
su teamcity
TeamCity/bin/runAll.sh start
```

## Notes

- Make sure the server has enough CPU, memory, and disk space for TeamCity.
- Configure firewall and reverse proxy settings according to your deployment environment.
