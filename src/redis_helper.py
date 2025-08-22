import redis
import sys
import struct
from redis.cluster import RedisCluster

INT_LEN = 4

def write_record(f, key, ttl, dump_value):
    f.write(struct.pack('>I', len(key)))
    f.write(key)
    f.write(struct.pack('>q', ttl))
    f.write(struct.pack('>I', len(dump_value)))
    f.write(dump_value)

def read_record(f):
    key_len_bytes = f.read(INT_LEN)
    if not key_len_bytes:
        return None
    key_len = struct.unpack('>I', key_len_bytes)[0]
    key = f.read(key_len)
    
    ttl_bytes = f.read(8)
    ttl = struct.unpack('>q', ttl_bytes)[0]
    
    dump_len_bytes = f.read(INT_LEN)
    dump_len = struct.unpack('>I', dump_len_bytes)[0]
    dump_value = f.read(dump_len)
    
    return key, ttl, dump_value

def dump_all_keys_to_file(host, port, output_file):
    try:
        r = RedisCluster(host=host, port=port, decode_responses=False, skip_full_coverage_check=True)
        r.ping()
        
        print(f"Connected to Redis Cluster at {host}:{port}. Starting key dump to {output_file}...")
        
        keys_dumped = 0
        with open(output_file, 'wb') as f:
            for key in r.scan_iter('*'):
                ttl = r.pttl(key)
                if ttl < 0:
                    ttl = 0
                
                dump_value = r.dump(key)
                if dump_value:
                    write_record(f, key, ttl, dump_value)
                    keys_dumped += 1
                    if keys_dumped % 100 == 0:
                        print(f" ... dumped {keys_dumped} keys")
        
        print(f"Dump complete. Total keys saved: {keys_dumped}")
    
    except Exception as e:
        sys.stderr.write(f"Error during key dump: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)

def restore_all_keys_from_file(host, port, input_file):
    try:
        r = RedisCluster(host=host, port=port, decode_responses=False, skip_full_coverage_check=True)
        r.ping()
        
        print(f"Connected to Redis Cluster at {host}:{port}. Starting key restore from {input_file}...")
        
        keys_restored = 0
        with open(input_file, 'rb') as f:
            while True:
                record = read_record(f)
                if record is None:
                    break
                
                key, ttl, dump_value = record
                
                pipe = r.pipeline(transaction=False)
                pipe.delete(key)
                pipe.restore(key, ttl, dump_value, replace=False)
                
                try:
                    pipe.execute()
                    keys_restored += 1
                    if keys_restored % 100 == 0:
                        print(f" ... restored {keys_restored} keys")
                except redis.exceptions.ResponseError as e:
                    sys.stderr.write(f"Warning: Could not restore key '{key.decode('utf-8', errors='ignore')}': {e}\n")
        
        print(f"Restore complete. Total keys processed: {keys_restored}")
    
    except Exception as e:
        sys.stderr.write(f"Error during key restore: {e}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: python3 redis_helper.py <command> [args...]\n")
        sys.stderr.write("Commands: dump <host> <port> <output_file> | restore <host> <port> <input_file>\n")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "dump":
        if len(sys.argv) != 5:
            sys.stderr.write("Usage: python3 redis_helper.py dump <host> <port> <output_file>\n")
            sys.exit(1)
        host, port, output_file = sys.argv[2], int(sys.argv[3]), sys.argv[4]
        dump_all_keys_to_file(host, port, output_file)
    
    elif command == "restore":
        if len(sys.argv) != 5:
            sys.stderr.write("Usage: python3 redis_helper.py restore <host> <port> <input_file>\n")
            sys.exit(1)
        host, port, input_file = sys.argv[2], int(sys.argv[3]), sys.argv[4]
        restore_all_keys_from_file(host, port, input_file)
    
    else:
        sys.stderr.write(f"Unknown command: {command}\n")
        sys.exit(1)