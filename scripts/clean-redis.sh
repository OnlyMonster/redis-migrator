#!/bin/bash

# clean-redis.sh
# Flushes all data from all master nodes in both source and target Redis clusters.

set -e
set -o pipefail

echo "Flushing all data from source Redis cluster..."
SOURCE_MASTER_NODES=$(docker compose exec -T source-redis-node-0 redis-cli -c -p 8000 cluster nodes | grep master | awk '{print $2}' | cut -d '@' -f 1)
for NODE in ${SOURCE_MASTER_NODES}; do
  NODE_HOST=$(echo "${NODE}" | cut -d ':' -f 1)
  NODE_PORT=$(echo "${NODE}" | cut -d ':' -f 2)
  echo "Flushing ${NODE_HOST}:${NODE_PORT}..."
  docker compose exec -T "${NODE_HOST}" redis-cli -p "${NODE_PORT}" FLUSHALL
done
echo "Source Redis cluster flushed."

echo "Flushing all data from target Redis cluster..."
TARGET_MASTER_NODES=$(docker compose exec -T target-redis-node-0 redis-cli -c -p 7006 cluster nodes | grep master | awk '{print $2}' | cut -d '@' -f 1)
for NODE in ${TARGET_MASTER_NODES}; do
  NODE_HOST=$(echo "${NODE}" | cut -d ':' -f 1)
  NODE_PORT=$(echo "${NODE}" | cut -d ':' -f 2)
  echo "Flushing ${NODE_HOST}:${NODE_PORT}..."
  docker compose exec -T "${NODE_HOST}" redis-cli -p "${NODE_PORT}" FLUSHALL
done
echo "Target Redis cluster flushed."

echo "All Redis clusters flushed successfully."