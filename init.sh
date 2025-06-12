#!/bin/bash

# install docker 

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl lsb-release gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Change docker network pool

DOCKER_NPOOL=/etc/docker/daemon.json

if [ -f $DOCKER_NPOOL ]; then
  sudo rm $DOCKER_NPOOL
  echo "Deleted existing out.conf"
fi

config="{
  \"default-address-pools\": [
    {
      \"base\": \"172.22.0.0/16\",
      \"size\": 30
    }
  ]
}"

echo "$config" | sudo tee $DOCKER_NPOOL >> /dev/null

# Install envoy proxy

wget -O- https://apt.envoyproxy.io/signing.key | sudo gpg --dearmor -o /etc/apt/keyrings/envoy-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/envoy-keyring.gpg] https://apt.envoyproxy.io bookworm main" | sudo tee /etc/apt/sources.list.d/envoy.list
sudo apt-get update
sudo apt-get install envoy
envoy="$(which envoy)"
sudo mkdir -p /etc/envoy
cat ./configs/envoy.yaml | sudo tee /etc/envoy/envoy.yaml > /dev/null
sudo mkdir -p /etc/systemd/system
cat ./configs/envoy.service | sudo tee /etc/systemd/system/envoy.service > /dev/null

sudo systemctl enable envoy
sudo systemctl start envoy

# Disable systemd-resolved

sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

sudo rm /etc/resolv.conf
cat <<EOF | sudo tee /etc/resolv.conf
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF

# Install PowerDNS and configure

sudo apt-get install pdns-server pdns-backend-sqlite3 sqlite3
sudo systemctl start pdns
sudo mkdir -p /etc/powerdns
cat ./configs/pdns.conf | sudo tee /etc/powerdns/pdns.conf > /dev/null
sudo chmod +r /etc/powerdns/pdns.conf

sudo mkdir -p /var/lib/powerdns
sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
sudo chown -R pdns:pdns /var/lib/powerdns

sudo systemctl restart pdns

# Create DNS zone

curl -X POST \
  -H 'X-API-Key: 75af7d4994df9ddc97b43b6466b75b567bb2ea33d88d4a2830f7567cdcd1' \
  -H 'Content-Type: application/json' \
  -d '{
        "name": "lab.devaraj.me.",
        "kind": "Native",
        "masters": [],
        "nameservers": [
          "ns1.cloudflare.com.",
          "ns2.cloudflare.com."
        ]
      }' \
  http://127.0.0.1:8081/api/v1/servers/localhost/zones

# Install redis 

curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt-get update
sudo apt-get install redis
sudo systemctl enable redis-server
sudo systemctl start redis-server