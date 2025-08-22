#!/usr/bin/env python3
import redis
from redis.cluster import RedisCluster
import sys

def get_all_keys(cluster_name, port):
    try:
        # Connect to Redis cluster
        rc = RedisCluster(host=f"{cluster_name}-redis-node-0", 
                       port=port,
                       decode_responses=True,
                       skip_full_coverage_check=True)
        
        # Get all keys using SCAN from each master node
        all_keys = set()
        
        # Get all nodes and identify masters
        nodes = []
        cluster_nodes = rc.execute_command("CLUSTER NODES")
        if isinstance(cluster_nodes, str):
            # Handle string response (old format)
            for line in cluster_nodes.split("\n"):
                if not line:
                    continue
                parts = line.split()
                if len(parts) >= 3 and "master" in parts[2]:
                    addr = parts[1].split("@")[0]
                    host, port = addr.split(":")
                    nodes.append((host, int(port)))
        else:
            # Handle dict response (new format)
            for node_id, node_info in cluster_nodes.items():
                if isinstance(node_info, dict) and ('master' in node_info.get('flags', '')):
                    # В новом формате node_id уже содержит host:port
                    host, port = node_id.split(':')
                    nodes.append((host, int(port)))
                
        print(f"Found {len(nodes)} master nodes")
        
        # Scan keys from each master
        for host, port in nodes:
            print(f"Scanning {host}:{port}...")
            node_client = redis.Redis(host=host, port=port, decode_responses=True)
            cursor = 0
            while True:
                cursor, keys = node_client.scan(cursor=cursor, count=100)
                all_keys.update(keys)
                if cursor == 0:
                    break
                    
        key_values = {}
        # Get type and value for each key using cluster connection for proper slot routing
        for key in all_keys:
            try:
                key_type = rc.type(key)
                if key_type == 'string':
                    value = rc.get(key)
                elif key_type == 'list':
                    value = rc.lrange(key, 0, -1)
                elif key_type == 'hash':
                    value = rc.hgetall(key)
                elif key_type == 'set':
                    value = list(rc.smembers(key))
                elif key_type == 'zset':
                    value = rc.zrange(key, 0, -1, withscores=True)
                else:
                    print(f"Warning: unknown type {key_type} for key {key}")
                    continue
                    
                # Get TTL for the key
                ttl = rc.ttl(key)
                key_values[key] = {
                    'type': key_type, 
                    'value': value,
                    'ttl': ttl
                }
            except Exception as e:
                print(f"Warning: error getting value for key {key}: {str(e)}")
                continue
            
        return key_values
        
    except Exception as e:
        print(f"Error accessing {cluster_name} cluster: {str(e)}", file=sys.stderr)
        sys.exit(1)

def compare_values(source_val, target_val):
    """Compare values considering different data types"""
    if isinstance(source_val, list) and isinstance(target_val, list):
        return sorted(source_val) == sorted(target_val)
    elif isinstance(source_val, dict) and isinstance(target_val, dict):
        return source_val == target_val
    else:
        return source_val == target_val

print("Scanning source cluster keys...")
source_data = get_all_keys('source', 8000)
print(f"Found {len(source_data)} keys in source cluster")

print("\nScanning target cluster keys...")
target_data = get_all_keys('target', 7006)
print(f"Found {len(target_data)} keys in target cluster")

# Compare the data
errors = []
missing_keys = set(source_data.keys()) - set(target_data.keys())
if missing_keys:
    errors.append(f"Keys missing in target: {missing_keys}")

extra_keys = set(target_data.keys()) - set(source_data.keys())
if extra_keys:
    errors.append(f"Extra keys in target: {extra_keys}")

# For keys present in both, compare types and values
common_keys = set(source_data.keys()) & set(target_data.keys())
for key in common_keys:
    source_info = source_data[key]
    target_info = target_data[key]
    
    if source_info['type'] != target_info['type']:
        errors.append(f"Type mismatch for key {key}: source={source_info['type']}, target={target_info['type']}")
        continue
        
    if not compare_values(source_info['value'], target_info['value']):
        errors.append(f"Value mismatch for key {key}:")
        errors.append(f"  Source: {source_info['value']}")
        errors.append(f"  Target: {target_info['value']}")
    
    # Compare TTL values with a tolerance of 10 seconds to account for migration time
    source_ttl = source_info['ttl']
    target_ttl = target_info['ttl']
    if abs(source_ttl - target_ttl) > 10 and not (source_ttl <= 0 and target_ttl <= 0):
        errors.append(f"TTL mismatch for key {key}:")
        errors.append(f"  Source TTL: {source_ttl}")
        errors.append(f"  Target TTL: {target_ttl}")

if not errors:
    print(f"\nVerification successful! Both clusters have {len(source_data)} keys with identical types and values.")
    print("\nTTL Statistics:")
    ttl_keys = 0
    for key in source_data:
        if source_data[key]['ttl'] > 0:
            ttl_keys += 1
            print(f"Key: {key}")
            print(f"  Source TTL: {source_data[key]['ttl']} seconds")
            print(f"  Target TTL: {target_data[key]['ttl']} seconds")
            print(f"  TTL Difference: {abs(source_data[key]['ttl'] - target_data[key]['ttl'])} seconds")
    print(f"\nTotal keys with TTL: {ttl_keys}")
    print(f"Keys without TTL: {len(source_data) - ttl_keys}")
    sys.exit(0)
else:
    print("\nVerification failed!")
    for error in errors:
        print(f"Error: {error}")
    sys.exit(1)
