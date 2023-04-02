#!/usr/bin/env bash

set -eu

#minecraft_version=1.19.72.01
#server_name=ydak_minecraft
#game_mode=survival
#difficulty=easy
#allow_cheats=false
#permission=member
#seed=

project_id=$(gcloud projects list --format="json" | jq -r '.[].projectId')
project_num=$(gcloud projects list --format="json" | jq -r '.[].projectNumber')

# firewall =====================================================================
fw_minecraft=$(gcloud compute firewall-rules list --format="json" | jq -r '.[] | select(.name=="minecraft")')

if [ -z "$fw_minecraft" ]; then
  gcloud compute --project="$project_id" \
  firewall-rules create minecraft \
  --description=minecraft \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:19132,udp:19132 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=minecraft
fi

# GCE ==========================================================================
image=$(gcloud compute images list --format="json" | jq -r '.[] | select(.family | test("^ubuntu-[0-9]+-lts$"))' | jq -rs 'sort_by(.family) | reverse | .[].selfLink' | head -1 | sed -E 's/.*(projects.*)/\1/')

gcloud compute instances create minecraft \
  --project="$project_id" \
  --zone=us-west1-b \
  --machine-type=e2-micro \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account="$project_num-compute@developer.gserviceaccount.com" \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --tags=minecraft \
  --create-disk=auto-delete=yes,boot=yes,device-name=minecraft,image=$image,mode=rw,size=10,type="projects/$project_id/zones/us-west1-b/diskTypes/pd-standard" --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring \
  --reservation-affinity=any \
  --metadata=startup-script="#!/bin/bash
dd if=/dev/zero of=/swap bs=1M count=4096 && \
mkswap /swap && \
swapon /swap && \
chmod -R 600 /swap && \
echo '/swapfile none swap sw 0 0' >> /etc/fstab && \
mkdir /var/minecraft && \
cd /var/minecraft/ && \
docker volume create mc-volume && \
docker run -d -it --name mc-server -e EULA=TRUE -p 19132:19132/udp -v mc-volume:/data itzg/minecraft-bedrock-server
"
