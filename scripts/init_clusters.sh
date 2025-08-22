#!/bin/bash
set -e

wait_for_node() {
    local node=$1
    local port=$2
    local retries=60
    local delay=2

    echo "Waiting for Redis node $node:$port to be ready..."
    while [ $retries -gt 0 ]; do
        if docker compose exec $node redis-cli -p $port ping > /dev/null 2>&1; then
            # Check cluster info as well
            cluster_info=$(docker compose exec $node redis-cli -p $port cluster info)
            echo "Redis node $node:$port is ready. Cluster info:"
            echo "$cluster_info"
            return 0
        fi
        let retries=retries-1
        echo "Waiting for node $node:$port ($retries retries left)..."
        sleep $delay
    done
    echo "Failed to connect to Redis node $node:$port"
    return 1
}

# Wait for all nodes to be ready
echo "Waiting for all Redis nodes to be ready..."
wait_for_node source-redis-node-0 8000
wait_for_node source-redis-node-1 8001
wait_for_node source-redis-node-2 8002
wait_for_node source-redis-node-3 8003
wait_for_node source-redis-node-4 8004
wait_for_node source-redis-node-5 8005

wait_for_node target-redis-node-0 7006
wait_for_node target-redis-node-1 7007
wait_for_node target-redis-node-2 7008
wait_for_node target-redis-node-3 7009
wait_for_node target-redis-node-4 7010
wait_for_node target-redis-node-5 7011

echo "All Redis nodes are ready. Creating clusters..."

# Create source cluster
echo "Creating source cluster..."
docker compose exec source-redis-node-0 redis-cli --cluster create \
    source-redis-node-0:8000 source-redis-node-1:8001 \
    source-redis-node-2:8002 source-redis-node-3:8003 \
    source-redis-node-4:8004 source-redis-node-5:8005 \
    --cluster-replicas 1 --cluster-yes

# Create target cluster
echo "Creating target cluster..."
docker compose exec target-redis-node-0 redis-cli --cluster create \
    target-redis-node-0:7006 target-redis-node-1:7007 \
    target-redis-node-2:7008 target-redis-node-3:7009 \
    target-redis-node-4:7010 target-redis-node-5:7011 \
    --cluster-replicas 1 --cluster-yes

echo "Redis clusters created successfully"

# Wait a bit for the clusters to stabilize
sleep 10

# Final cluster status check
echo "Checking final cluster status..."
echo "Source cluster status:"
docker compose exec source-redis-node-0 redis-cli -p 8000 cluster info
echo "Target cluster status:"
docker compose exec target-redis-node-0 redis-cli -p 7006 cluster info
