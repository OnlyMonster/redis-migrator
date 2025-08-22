#!/bin/sh
# Verify that data was successfully migrated between Redis clusters

set -e

function get_master_nodes() {
    local cluster_name=$1
    local initial_port=$2
    redis-cli -h ${cluster_name}-redis-node-0 -p ${initial_port} CLUSTER NODES | grep master | awk '{print $2}' | cut -d '@' -f 1
}

function count_keys_by_type() {
    local node=$1
    local port=$2
    local type=$3
    local prefix="${type}:key:"
    
    # Get all keys of specific type using pattern matching
    keys=$(redis-cli -h ${node} -c -p ${port} --raw keys "${prefix}*")
    if [ -z "$keys" ]; then
        echo "0"
        return
    fi
    
    # Count the keys
    count=$(echo "$keys" | wc -l)
    echo "$count"
}

echo "Verifying source cluster..."
source_masters=$(get_master_nodes "source" "8000")

echo "Source cluster master nodes:"
total_source_strings=0
total_source_lists=0
total_source_hashes=0
total_source_sets=0
total_source_zsets=0

for node in $source_masters; do
    host=$(echo $node | cut -d ':' -f1)
    port=$(echo $node | cut -d ':' -f2)
    echo "Checking $host:$port..."
    
    strings=$(count_keys_by_type "$host" "$port" "string")
    lists=$(count_keys_by_type "$host" "$port" "list")
    hashes=$(count_keys_by_type "$host" "$port" "hash")
    sets=$(count_keys_by_type "$host" "$port" "set")
    zsets=$(count_keys_by_type "$host" "$port" "zset")
    
    echo "  Strings: $strings"
    echo "  Lists: $lists"
    echo "  Hashes: $hashes"
    echo "  Sets: $sets"
    echo "  Sorted Sets: $zsets"
    
    total_source_strings=$((total_source_strings + strings))
    total_source_lists=$((total_source_lists + lists))
    total_source_hashes=$((total_source_hashes + hashes))
    total_source_sets=$((total_source_sets + sets))
    total_source_zsets=$((total_source_zsets + zsets))
done

echo -e "\nSource cluster totals:"
echo "  Total Strings: $total_source_strings"
echo "  Total Lists: $total_source_lists"
echo "  Total Hashes: $total_source_hashes"
echo "  Total Sets: $total_source_sets"
echo "  Total Sorted Sets: $total_source_zsets"
total_source=$((total_source_strings + total_source_lists + total_source_hashes + total_source_sets + total_source_zsets))
echo "  Total Keys: $total_source"

echo -e "\nVerifying target cluster..."
target_masters=$(get_master_nodes "target" "7006")

echo "Target cluster master nodes:"
total_target_strings=0
total_target_lists=0
total_target_hashes=0
total_target_sets=0
total_target_zsets=0

for node in $target_masters; do
    host=$(echo $node | cut -d ':' -f1)
    port=$(echo $node | cut -d ':' -f2)
    echo "Checking $host:$port..."
    
    strings=$(count_keys_by_type "$host" "$port" "string")
    lists=$(count_keys_by_type "$host" "$port" "list")
    hashes=$(count_keys_by_type "$host" "$port" "hash")
    sets=$(count_keys_by_type "$host" "$port" "set")
    zsets=$(count_keys_by_type "$host" "$port" "zset")
    
    echo "  Strings: $strings"
    echo "  Lists: $lists"
    echo "  Hashes: $hashes"
    echo "  Sets: $sets"
    echo "  Sorted Sets: $zsets"
    
    total_target_strings=$((total_target_strings + strings))
    total_target_lists=$((total_target_lists + lists))
    total_target_hashes=$((total_target_hashes + hashes))
    total_target_sets=$((total_target_sets + sets))
    total_target_zsets=$((total_target_zsets + zsets))
done

echo -e "\nTarget cluster totals:"
echo "  Total Strings: $total_target_strings"
echo "  Total Lists: $total_target_lists"
echo "  Total Hashes: $total_target_hashes"
echo "  Total Sets: $total_target_sets"
echo "  Total Sorted Sets: $total_target_zsets"
total_target=$((total_target_strings + total_target_lists + total_target_hashes + total_target_sets + total_target_zsets))
echo "  Total Keys: $total_target"

echo -e "\nComparing clusters:"
errors=0

if [ $total_source_strings -ne $total_target_strings ]; then
    echo "❌ String count mismatch: source=$total_source_strings, target=$total_target_strings"
    errors=$((errors + 1))
else
    echo "✅ String counts match: $total_source_strings"
fi

if [ $total_source_lists -ne $total_target_lists ]; then
    echo "❌ List count mismatch: source=$total_source_lists, target=$total_target_lists"
    errors=$((errors + 1))
else
    echo "✅ List counts match: $total_source_lists"
fi

if [ $total_source_hashes -ne $total_target_hashes ]; then
    echo "❌ Hash count mismatch: source=$total_source_hashes, target=$total_target_hashes"
    errors=$((errors + 1))
else
    echo "✅ Hash counts match: $total_source_hashes"
fi

if [ $total_source_sets -ne $total_target_sets ]; then
    echo "❌ Set count mismatch: source=$total_source_sets, target=$total_target_sets"
    errors=$((errors + 1))
else
    echo "✅ Set counts match: $total_source_sets"
fi

if [ $total_source_zsets -ne $total_target_zsets ]; then
    echo "❌ Sorted Set count mismatch: source=$total_source_zsets, target=$total_target_zsets"
    errors=$((errors + 1))
else
    echo "✅ Sorted Set counts match: $total_source_zsets"
fi

if [ $total_source -ne $total_target ]; then
    echo "❌ Total key count mismatch: source=$total_source, target=$total_target"
    errors=$((errors + 1))
else
    echo "✅ Total key counts match: $total_source"
fi

if [ $errors -eq 0 ]; then
    echo -e "\n✅ Verification successful! All key counts match."
    exit 0
else
    echo -e "\n❌ Verification failed! Found $errors mismatches."
    exit 1
fi
