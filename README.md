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
│   ├── redis-migrator.sh # Main migration script
│   └── verify-keys.sh   # Migration verification
├── redis-cluster/      # Redis configuration
│   ├── source-redis-node-*.conf # Source cluster configs
│   └── target-redis-node-*.conf # Target cluster configs
├── docker-compose.yml  # Docker services definition
└── Makefile           # Build and automation commands
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
# or
./scripts/generate-data.sh

# Perform test migration
make migrate
# or
./scripts/redis-migrator.sh --save && ./scripts/redis-migrator.sh --restore

# Verify migration results
make verify
```

## Production Usage

### Save Data from Source Cluster

1. Configure source cluster connection in `docker-compose.yml`:
   ```yaml
   source-redis-node-0:
     ports:
       - "8000:8000"  # Adjust port as needed
   ```

2. Run save operation:
   ```bash
   make save
   # or
   ./scripts/redis-migrator.sh --save
   ```

3. Backup the generated dump file:
   ```bash
   cp redis_dump.txt /path/to/backup/
   ```

### Restore Data to Target Cluster

1. Copy dump file to target server:
   ```bash
   scp redis_dump.txt user@target-server:/path/to/redis-migrator/
   ```

2. Configure target cluster connection in `docker-compose.yml`:
   ```yaml
   target-redis-node-0:
     ports:
       - "7000:7000"  # Adjust port as needed
   ```

3. Run restore operation:
   ```bash
   make restore
   # or
   ./scripts/redis-migrator.sh --restore
   ```

### Verification

After migration, verify data consistency:
```bash
make verify
# or
./scripts/verify-keys.sh && python3 src/verify_clusters.py
```

## Configuration

### Environment Variables

Create `config.env` to override defaults:
```bash
SOURCE_REDIS_HOST=source-redis-node-0
SOURCE_REDIS_PORT=8000
TARGET_REDIS_HOST=target-redis-node-0
TARGET_REDIS_PORT=7000
MIGRATION_FILE=redis_dump.txt
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

- No TTL migration support
- Memory requirements for dump file
- Requires sufficient disk space

## Troubleshooting

### Common Issues

1. Cluster Connection Errors:
   ```bash
   # Check cluster status
   docker compose exec source-redis-node-0 redis-cli -p 8000 cluster info
   ```

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