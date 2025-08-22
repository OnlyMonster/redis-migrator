# Makefile for Redis Migrator

.PHONY: all setup test clean build save restore verify help generate migrate

# Variables
DUMP_FILE := redis_dump.txt

# Default target
.DEFAULT_GOAL := help

# Main targets
all: test

# Environment setup
setup: up
	@echo "Setup complete"

# Start clusters
up:
	docker compose up -d

	@echo "Initializing Redis clusters..."
	chmod +x ./scripts/init_clusters.sh
	./scripts/init_clusters.sh

# Stop and cleanup
down:
	docker compose down -v

clean:
	./scripts/clean-redis.sh
	@echo "Redis clusters cleaned"

# Testing and migration
test: setup clean generate save restore verify down
	@echo "Full test cycle completed"

generate:
	@echo "Generating test data..."
	docker compose exec migrator ./scripts/generate-data.sh

save:
	@echo "Saving data from source cluster..."
	docker compose exec migrator ./scripts/redis-migrator.sh --save

restore:
	@echo "Restoring data to target cluster..."
	docker compose exec migrator ./scripts/redis-migrator.sh --restore

verify:
	@echo "Verifying migration..."
	docker compose exec migrator ./scripts/verify-keys.sh
	docker compose exec migrator python3 src/verify_clusters.py

# Help
help:
	@echo "Redis Migrator - Available commands:"
	@echo "  setup         - Start Redis clusters and migrator service"
	@echo "  generate      - Create test data in source cluster"
	@echo "  save         - Save data from source cluster"
	@echo "  restore      - Restore data to target cluster"
	@echo "  verify       - Check migration consistency"
	@echo "  clean        - Remove containers and data"
	@echo "  test         - Run full test cycle"
	@echo "  migrate      - Run save and restore"
	@echo "  down         - Stop containers"
	@echo "  help         - Show this help message"