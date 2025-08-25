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
make generate-data

# Perform full migration
make migrate    # equivalent to: make save && make restore

# Verify migration results
make verify

# Stop and clean up
make down      # stop all containers
make clean     # remove all data from clusters
```

## Production Usage

### Migration Between Physical Clusters

For migrating data between two physical Redis clusters in different environments:

1. Clone the repository on the source machine:
   ```bash
   git clone <repository-url>
   cd redis-migrator
   ```
2. Init config.env:
   ```bash
   ./scripts/redis-migrator.sh --init
   ```
3. Edit the `config.env` file to point to your source cluster:
   ```bash
   # Address of any node in the source Redis Cluster
   SOURCE_NODE="source-redis-node-0:8000"

   # Address of any node in the target Redis Cluster
   TARGET_NODE="target-redis-node-0:7006"

   # File to use for saving and restoring data (binary format)
   DUMP_FILE="redis_dump.bin"
   ```
4. Init Python env and install requirements modules:
   ```
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```
5. Save data from the source cluster:
   ```bash
   ./scripts/redis-migrator.sh --save
   ```
   This will create `redis_dump.bin` with all your data.

6. Transfer the dump file to the target machine:
   ```bash
   scp redis_dump.bin user@target-machine:/path/to/redis-migrator/
   ```

7. On the target machine, clone the repository and edit `config.env`:
   ```bash
   TARGET_REDIS_HOST=target-cluster-ip
   TARGET_REDIS_PORT=6379
   TARGET_REDIS_PASSWORD=your_password # if authentication is enabled
   ```

8. Restore data to the target cluster:
   ```bash
   ./scripts/redis-migrator.sh --restore
   ```

9. Verify the migration. Since direct verification between physically separated clusters is not possible, 
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
# Cluster connection settings
SOURCE_REDIS_HOST=source-redis-node-0  # Host of source Redis cluster
SOURCE_REDIS_PORT=8000                 # Port of source Redis cluster
TARGET_REDIS_HOST=target-redis-node-0  # Host of target Redis cluster
TARGET_REDIS_PORT=7000                 # Port of target Redis cluster

# Migration settings
MIGRATION_FILE=redis_dump.bin          # Binary dump file name

# Authentication (if needed)
SOURCE_REDIS_PASSWORD=                 # Source cluster password
TARGET_REDIS_PASSWORD=                 # Target cluster password

# Note: The following features are planned for future releases:
# - SSL/TLS support for secure connections
# - Batch processing for large datasets
# - Parallel migration for improved performance
# - Memory usage control and monitoring
```

### Make Commands

The following commands are available for managing the migration process in a Docker environment:

#### Setup and Management
- `make setup` - Initialize and start Redis clusters and migrator service
- `make down` - Stop and remove all containers
- `make clean` - Remove all data from both clusters

#### Migration Commands
- `make generate-data` - Create sample test data in source cluster
- `make save` - Export data from source cluster to dump file
- `make restore` - Import data from dump file to target cluster
- `make migrate` - Run full migration (save + restore)
- `make verify` - Validate data consistency between clusters

#### Testing
- `make test` - Run complete test cycle with all steps
- `make help` - Show available commands and their descriptions

For physical cluster migration, use the scripts directly as shown in the [Production Usage](#production-usage) section.

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
- No SSL/TLS поддержка в текущей версии
- Нет пакетной обработки (batch processing)
- Нет параллельной миграции
- Нет контроля использования памяти

## Roadmap

Планируемые улучшения:
1. Добавить поддержку SSL/TLS для безопасного соединения
2. Реализовать пакетную обработку для больших наборов данных
3. Добавить параллельную миграцию для ускорения процесса
4. Реализовать контроль использования памяти
5. Улучшить обработку аутентификации

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
