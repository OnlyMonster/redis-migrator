# Makefile for Redis Migrator

.PHONY: all setup test clean build save restore verify help generate migrate

# Variables
DUMP_FILE := redis_dump.bin
DOCKER_COMPOSE := docker compose

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
test: setup clean generate-data save restore verify down
	@echo "Full test cycle completed"

generate-data:
	@echo "Generating test data..."
	$(DOCKER_COMPOSE) exec migrator ./scripts/generate-data.sh
	@echo "Test data generation completed"

save:
	@echo "Saving data from source cluster..."
	$(DOCKER_COMPOSE) exec migrator ./scripts/redis-migrator.sh --save
	@echo "Data save completed"

restore:
	@echo "Restoring data to target cluster..."
	$(DOCKER_COMPOSE) exec migrator ./scripts/redis-migrator.sh --restore
	@echo "Data restore completed"

verify:
	@echo "Verifying migration..."
	$(DOCKER_COMPOSE) exec migrator ./scripts/verify-keys.sh
	$(DOCKER_COMPOSE) exec migrator python3 src/verify_clusters.py

migrate: save restore
	@echo "Migration completed successfully"

# Help
help:
	@echo "Redis Migrator - Available commands:"
	@echo ""
	@echo "Setup and Management:"
	@echo "  setup         - Initialize and start Redis clusters and migrator service"
	@echo "  down         - Stop and remove all containers"
	@echo "  clean        - Remove all data from both clusters"
	@echo ""
	@echo "Migration Commands:"
	@echo "  generate-data - Create sample test data in source cluster"
	@echo "  save         - Export data from source cluster to dump file"
	@echo "  restore      - Import data from dump file to target cluster"
	@echo "  migrate      - Run full migration (save + restore)"
	@echo "  verify       - Validate data consistency between clusters"
	@echo ""
	@echo "Testing:"
	@echo "  test         - Run complete test cycle with all steps"
	@echo "  help         - Show this help message"