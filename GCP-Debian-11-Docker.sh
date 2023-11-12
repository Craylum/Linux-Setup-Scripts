#!/bin/bash

# Copyright (C) 2023 Thien Tran
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

#Run this after GCP-Debian-11.sh

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

# Install Docker and Docker Compose
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Fixes for user
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Docker to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Add IPV6 support to Docker (Change subnet to your liking)
echo '{
  "ipv6": true,
  "fixed-cidr-v6": "fd96:4b11:22d6:1::/64",
  "experimental": true,
  "ip6tables": true
}' | sudo tee /etc/docker/daemon.json

sudo systemctl restart docker