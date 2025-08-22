#!/bin/bash
set -x

NODE_NAME=$1
PORT=$2
TIMEOUT=${3:-120}
COMPOSE_FILE=${4:-docker-compose.cluster.yml}

echo "Waiting for Redis Cluster on ${NODE_NAME}:${PORT} to be healthy..."

ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  CLUSTER_INFO=$(docker compose -f ${COMPOSE_FILE} exec -T ${NODE_NAME} redis-cli -c -p ${PORT} CLUSTER INFO 2>/dev/null)
  CLUSTER_STATE=$(echo "$CLUSTER_INFO" | grep cluster_state | cut -d: -f2 | tr -d '\r')
  CLUSTER_NODES=$(echo "$CLUSTER_INFO" | grep cluster_known_nodes | cut -d: -f2 | tr -d '\r')

  if [ "$CLUSTER_STATE" = "ok" ] && [ "$CLUSTER_NODES" = "6" ]; then
    echo "Redis Cluster on ${NODE_NAME}:${PORT} is healthy."
    exit 0
  fi

  echo "Waiting for Redis Cluster on ${NODE_NAME}:${PORT} to be healthy... (State: ${CLUSTER_STATE:-unknown}, Nodes: ${CLUSTER_NODES:-unknown})"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  docker compose -f ${COMPOSE_FILE} ps
done

echo "Redis Cluster on ${NODE_NAME}:${PORT} did not become healthy within ${TIMEOUT} seconds."
exit 1
