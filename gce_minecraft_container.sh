#!/usr/bin/env bash
# sudo journalctl -u google-startup-scripts.service
set -eu

echo "Minecraft Server Create Start!"

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
echo "Checking Firewall ..."
fw_minecraft=$(gcloud compute firewall-rules list --format="json" | jq -r '.[] | select(.name=="minecraft")')

if [ -z "$fw_minecraft" ]; then
  echo "Firewall is not found. Creating Firewall for Minecraft ..."
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
echo "Firewall Check Done."

# GCE ==========================================================================
echo "Checking latest COS image ..."
image=$(gcloud compute images list --format="json" | jq -r '.[] | select(.family | test("cos-stable")) | .selfLink' | sed -E 's/.*(projects.*)/\1/')

echo "Creating GCE for minecraft ..."

external_ip=$(gcloud compute instances create minecraft \
  --format="json" \
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
mkdir /var/minecraft && \
cd /var/minecraft/ && \
docker volume create mc-volume && \
docker run -d -it --name mc-server -e EULA=TRUE -p 19132:19132/udp -v mc-volume:/data itzg/minecraft-bedrock-server
" | jq -r '.[].networkInterfaces[0].accessConfigs[0].natIP')

echo "All Done!! Wait for 5 minutes and access the minecraft!"

echo "Your minecraft ip is [$external_ip]"


