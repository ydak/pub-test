#!/usr/bin/env bash
# sudo journalctl -u google-startup-scripts.service
# gcloud compute ssh --zone "us-west1-b" "minecraft" --command="docker pull itzg/minecraft-bedrock-server:latest && docker restart mc-server"
set -e

echo "========== Minecraft Server Create Start! =========="


echo -n "Please enter your server name (Default: minecraft-server): "
read -r server_name

echo -n "Please enter game mode (Default: survival) [survival or creative or adventure]: "
read -r game_mode

if [ "$game_mode" != "survival" ] && [ "$game_mode" != "creative" ] && [ "$game_mode" != "adventure" ]; then
  echo "enter correct game mode [survival] or [creative] or [adventure]."
  exit 1
fi

exit 0

echo -n "Please enter difficulty (Default: normal) [peaceful or easy or normal or hard]: "
read -r difficulty

echo -n "Allow cheat? (Default: no) [yes or no]: "
read -r allow_cheat

echo -n "Default member permission (Default: member) [visitor or member or operator]: "
read -r permission

echo -n "Enter seed (Default: random): "
read -r seed

project_id=$(gcloud projects list --format="json" | jq -r '.[].projectId')
project_num=$(gcloud projects list --format="json" | jq -r '.[].projectNumber')

# firewall =====================================================================
echo "Checking Firewall ..."
fw_minecraft=$(gcloud compute firewall-rules list --format="json" | jq -r '.[] | select(.name=="minecraft")')

if [ -z "$fw_minecraft" ]; then
  echo "Firewall minecraft is not found. Creating Firewall for Minecraft ..."
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
echo "Firewall creation done."

# GCE ==========================================================================
echo "Checking latest COS image ..."
image=$(gcloud compute images list --format="json" | jq -r '.[] | select(.family | test("cos-stable")) | .selfLink' | sed -E 's/.*(projects.*)/\1/')
echo "COS image Check Done."

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
docker run -d -it --name mc-server --restart=always -e EULA=TRUE -e GAMEMODE=$game_mode -e DIFFICULTY=$difficulty -e ALLOW_CHEATS=$allow_cheat -e DEFAULT_PLAYER_PERMISSION_LEVEL=$permission -e LEVEL_SEED=$seed -p 19132:19132/udp -v mc-volume:/data itzg/minecraft-bedrock-server:latest
" | jq -r '.[].networkInterfaces[0].accessConfigs[0].natIP')

echo "Your minecraft ip is [$external_ip]"

echo "========== All Done!! Wait for 3 minutes and access the minecraft! =========="




