#!/bin/sh

# generate-data.sh
# This script populates the source Redis cluster with 100 sample data keys.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Use environment variables if they are set, otherwise use default values.
# This makes the script configurable for different environments (e.g., Docker Compose).
SOURCE_REDIS_HOST="${REDIS_HOST:-source-redis-node-0}"
SOURCE_REDIS_PORT="${REDIS_PORT:-8000}"

echo "Populating source Redis cluster at ${SOURCE_REDIS_HOST}:${SOURCE_REDIS_PORT} with 100 sample keys..."

# Function to execute redis-cli commands in CLUSTER MODE (-c)
execute_redis_command() {
  # The -c flag is CRITICAL. It enables cluster mode, which automatically
  # follows MOVED redirects to the correct node.
  redis-cli -c -h "${SOURCE_REDIS_HOST}" -p "${SOURCE_REDIS_PORT}" "$@"
}

echo "Adding 20 String keys (10 with TTL)..."
for i in $(seq 1 20); do
  if [ $i -le 10 ]; then
    # First 10 keys with TTL (varying from 1 hour to 10 hours)
    execute_redis_command SET "string:key:${i}" "value_for_string_${i}" EX $((3600 * i))
  else
    # Last 10 keys without TTL
    execute_redis_command SET "string:key:${i}" "value_for_string_${i}"
  fi
done

echo "Adding 20 List keys..."
for i in $(seq 1 20); do
  # It's better to clean up old keys before adding new ones
  execute_redis_command DEL "list:key:${i}" > /dev/null
  execute_redis_command LPUSH "list:key:${i}" "item_${i}_a" "item_${i}_b" "item_${i}_c"
done

echo "Adding 20 Hash keys (10 with TTL)..."
for i in $(seq 1 20); do
  execute_redis_command HSET "hash:key:${i}" "field1" "value_${i}_field1" "field2" "value_${i}_field2"
  if [ $i -le 10 ]; then
    # First 10 keys with TTL (varying from 2 hours to 20 hours)
    execute_redis_command EXPIRE "hash:key:${i}" $((7200 * i))
  fi
done

echo "Adding 20 Set keys..."
for i in $(seq 1 20); do
  execute_redis_command DEL "set:key:${i}" > /dev/null
  execute_redis_command SADD "set:key:${i}" "member_${i}_a" "member_${i}_b" "member_${i}_c"
done

echo "Adding 20 ZSet (Sorted Set) keys..."
for i in $(seq 1 20); do
  execute_redis_command DEL "zset:key:${i}" > /dev/null
  execute_redis_command ZADD "zset:key:${i}" "$((i * 10))" "zmember_${i}_a" "$((i * 10 + 5))" "zmember_${i}_b"
done

echo "Data generation complete. 100 keys were successfully created across the cluster."