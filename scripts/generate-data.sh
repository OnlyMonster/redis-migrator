#!/bin/sh

set -e

SOURCE_REDIS_HOST="${REDIS_HOST:-source-redis-node-0}"
SOURCE_REDIS_PORT="${REDIS_PORT:-8000}"

echo "Populating source Redis cluster at ${SOURCE_REDIS_HOST}:${SOURCE_REDIS_PORT} with 100 sample keys..."

execute_redis_command() {
  redis-cli -c -h "${SOURCE_REDIS_HOST}" -p "${SOURCE_REDIS_PORT}" "$@"
}

echo "Adding 20 String keys (10 with TTL)..."
for i in $(seq 1 20); do
  if [ $i -le 10 ]; then
    execute_redis_command SET "string:key:${i}" "value_for_string_${i}" EX $((3600 * i))
  else
    execute_redis_command SET "string:key:${i}" "value_for_string_${i}"
  fi
done

echo "Adding 20 List keys..."
for i in $(seq 1 20); do
  execute_redis_command DEL "list:key:${i}" > /dev/null
  execute_redis_command LPUSH "list:key:${i}" "item_${i}_a" "item_${i}_b" "item_${i}_c"
done

echo "Adding 20 Hash keys (10 with TTL)..."
for i in $(seq 1 20); do
  execute_redis_command HSET "hash:key:${i}" "field1" "value_${i}_field1" "field2" "value_${i}_field2"
  if [ $i -le 10 ]; then
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