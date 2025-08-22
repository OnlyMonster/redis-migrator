# Redis Cluster Data Migration Tool

This project provides a solution for migrating data between two Redis Clusters using a file-based approach, all managed within a Docker Compose environment. The tool supports all Redis data types and ensures correct key distribution across cluster nodes.

## Project Structure

```
redis-migrator/
├── src/                 # Source code
│   ├── redis_helper.py  # Core migration logic
│   └── verify_clusters.py # Cluster verification
├── scripts/             # Shell scripts
│   ├── clean-redis.sh   # Cluster cleanup
│   ├── generate-data.sh # Sample data generation
│   ├── init_clusters.sh # Cluster initialization
│   ├── redis-migrator.sh # Main migration script
│   └── verify-keys.sh   # Migration verification
├── config/             # Configuration files
│   └── redis-cluster/  # Redis cluster configuration
│       ├── source-redis-node-*.conf # Source cluster configs
│       └── target-redis-node-*.conf # Target cluster configs
├── docker-compose.yml  # Docker services definition
├── Dockerfile         # Migrator service definition
├── requirements.txt   # Python dependencies
└── Makefile          # Build and automation commands
```

## Getting Started

## Prerequisites

- Docker and Docker Compose v2+
- Make (optional)

## Quick Start with Docker Compose

### 1. Local Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd redis-migrator

# Start Redis clusters and migrator service
make setup
# or
docker compose up -d
```

This will:
- Start two Redis clusters (source and target) with 6 nodes each
- Configure cluster mode automatically
- Start the migrator service

### 2. Test Migration Process

```bash
# Generate test data in source cluster
make generate
# or
./scripts/generate-data.sh

# Perform test migration
make save 
make restore
# or
./scripts/redis-migrator.sh --save && ./scripts/redis-migrator.sh --restore

# Verify migration results
make verify

# Stop Redis clusters and migrator service
make down
```

## Production Usage

### Migration Between Physical Clusters

For migrating data between two physical Redis clusters in different environments:

1. Clone the repository on the source machine:
   ```bash
   git clone <repository-url>
   cd redis-migrator
   ```

2. Edit the `config.env` file to point to your source cluster:
   ```bash
   SOURCE_REDIS_HOST=source-cluster-ip
   SOURCE_REDIS_PORT=6379
   SOURCE_REDIS_PASSWORD=your_password # if authentication is enabled
   ```

3. Save data from the source cluster:
   ```bash
   ./scripts/redis-migrator.sh --save
   ```
   This will create `redis_dump.bin` with all your data.

4. Transfer the dump file to the target machine:
   ```bash
   scp redis_dump.bin user@target-machine:/path/to/redis-migrator/
   ```

5. On the target machine, clone the repository and edit `config.env`:
   ```bash
   TARGET_REDIS_HOST=target-cluster-ip
   TARGET_REDIS_PORT=6379
   TARGET_REDIS_PASSWORD=your_password # if authentication is enabled
   ```

6. Restore data to the target cluster:
   ```bash
   ./scripts/redis-migrator.sh --restore
   ```

7. Verify the migration. Since direct verification between physically separated clusters is not possible, 
   you can use these alternative approaches:

   a. Compare key counts and types:
   ```bash
   # On source machine
   ./scripts/verify-keys.sh --source-only > source_stats.txt
   
   # On target machine
   ./scripts/verify-keys.sh --target-only > target_stats.txt
   
   # Compare the statistics files
   diff source_stats.txt target_stats.txt
   ```

   b. Sample-based verification:
   ```bash
   # Generate list of random keys from source
   redis-cli -h source-cluster-ip -p 6379 --scan --pattern '*' | shuf -n 100 > sample_keys.txt
   
   # Check these specific keys in both clusters and compare values
   ./scripts/verify-keys.sh --keys-file sample_keys.txt
   ```

   c. Application-level verification:
   - Run your application's test suite against the new cluster
   - Monitor error rates and performance metrics
   - Gradually shift read traffic to verify data consistency

### Tips for Physical Cluster Migration
- Ensure network connectivity and firewall rules between the migrator and both clusters
- Use private network addresses when possible
- Monitor cluster memory and disk space during migration
- Consider running a test migration with a subset of keys first
- Take backup of target cluster before migration
- Consider using `screen` or `tmux` for long-running migrations


## Configuration

### Environment Variables

Create `config.env` to override defaults:
```bash
# Local development defaults
SOURCE_REDIS_HOST=source-redis-node-0
SOURCE_REDIS_PORT=8000
TARGET_REDIS_HOST=target-redis-node-0
TARGET_REDIS_PORT=7000
MIGRATION_FILE=redis_dump.bin

# Optional authentication
SOURCE_REDIS_PASSWORD=your_source_password
TARGET_REDIS_PASSWORD=your_target_password

# Optional SSL/TLS configuration
SOURCE_REDIS_SSL=true
TARGET_REDIS_SSL=true
SOURCE_REDIS_CERT_PATH=/path/to/source/cert.pem
TARGET_REDIS_CERT_PATH=/path/to/target/cert.pem

# Optional performance tuning
BATCH_SIZE=1000        # Number of keys to process in one batch
PARALLEL_JOBS=4        # Number of parallel migration jobs
MAX_MEMORY_PERCENT=80  # Maximum memory usage percentage
```

### Make Commands

- `make setup`: Start Redis clusters
- `make generate-data`: Create test data
- `make save`: Save source cluster data
- `make restore`: Restore data to target cluster
- `make verify`: Verify migration
- `make clean`: Clean all data and containers

## Supported Data Types

- Strings
- Lists
- Hashes
- Sets
- Sorted Sets (ZSets)

## Security Considerations

- No FLUSHALL on target cluster
- Recommended: Backup target cluster before restore
- Check disk space for dump file
- Configure firewall rules for Redis ports
- Use strong Redis passwords in production

## Limitations

- Memory requirements for dump file
- Requires sufficient disk space
- Large TTL values (>2^63-1 ms, ~292 years) may be truncated

## Features

- Full TTL support for all keys
- Atomic key restoration with original TTL values
- Batch processing for efficient migration
- Error handling and progress reporting

## Troubleshooting

### Common Issues

1. Cluster Connection Errors:
   ```bash
   # Check cluster status (local development)
   docker compose exec source-redis-node-0 redis-cli -p 8000 cluster info
   
   # Check cluster status (physical clusters)
   redis-cli -h source-cluster-ip -p 6379 cluster info
   redis-cli -h target-cluster-ip -p 6379 cluster info
   ```

2. Verification in Physical Clusters:
   - If clusters are in different networks, use the separate verification methods described above
   - Keep source cluster running until verification is complete
   - Consider maintaining temporary read-only access to source cluster during verification

2. Memory Issues:
   - Increase Docker memory limit
   - Use smaller batch sizes

### Logs

View logs for debugging:
```bash
# Migrator service logs
docker compose logs migrator

# Redis node logs
docker compose logs source-redis-node-0
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Create Pull Request

## License

[MIT License](LICENSE)