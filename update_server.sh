#!/usr/bin/env bash
set -e

gcloud compute ssh --zone "us-west1-b" "minecraft" --command="docker pull itzg/minecraft-bedrock-server:latest && docker restart mc-server"
