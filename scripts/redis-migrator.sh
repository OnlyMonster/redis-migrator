#!/bin/sh

# redis-migrator.sh
# A robust script for migrating data between Redis Clusters.
# It acts as a wrapper for a powerful Python helper script.

set -e
set -o pipefail

# --- Configuration ---
# Default values. Can be overridden by config.env.
SOURCE_NODE="source-redis-node-0:8000"
TARGET_NODE="target-redis-node-0:7006"
DUMP_FILE="redis_dump.bin" # The dump file is now binary

# Load configuration from config.env if it exists
if [ -f "config.env" ]; then
  echo "Loading configuration from config.env..."
  # shellcheck source=/dev/null
  source config.env
fi

# --- Functions ---

show_help() {
  echo "Usage: $0 [COMMAND]"
  echo ""
  echo "A script for migrating data between Redis Clusters using a Python helper."
  echo ""
  echo "Commands:"
  echo "  --help      Show this help message."
  echo "  --init      Create an example config.env file."
  echo "  --save      Dump data from the source cluster to a binary file."
  echo "  --restore   Restore data from a binary file to the target cluster."
}

check_dependencies() {
  # The only dependencies for this wrapper are python3 and the helper script.
  if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed or not in PATH."
    exit 1
  fi
  if [ ! -f "/app/src/redis_helper.py" ]; then
    echo "Error: The helper script /app/src/redis_helper.py was not found."
    exit 1
  fi
}

# Function to SAVE data by delegating to the Python script
save_data() {
  local source_host="${SOURCE_NODE%:*}"
  local source_port="${SOURCE_NODE#*:}"

  echo "Delegating data save to redis_helper.py..."
  # The Python script handles everything: scanning, dumping, and writing the binary file.
  python3 /app/src/redis_helper.py dump "${source_host}" "${source_port}" "${DUMP_FILE}"
}

# Function to RESTORE data by delegating to the Python script
restore_data() {
  if [ ! -f "${DUMP_FILE}" ]; then
    echo "Error: Dump file ${DUMP_FILE} not found."
    exit 1
  fi

  local target_host="${TARGET_NODE%:*}"
  local target_port="${TARGET_NODE#*:}"

  echo "Delegating data restore to redis_helper.py..."
  # The Python script handles everything: reading the binary file and restoring keys.
  python3 /app/src/redis_helper.py restore "${target_host}" "${target_port}" "${DUMP_FILE}"
}

# --- Main Logic ---

check_dependencies

if [ $# -eq 0 ]; then
    echo "Error: No command provided."
    show_help
    exit 1
fi

case "$1" in
  --help)
    show_help
    ;;
  --init)
    echo "Creating example config file: config.env"
    cat << EOF > config.env
# Address of any node in the source Redis Cluster
SOURCE_NODE="source-redis-node-0:8000"

# Address of any node in the target Redis Cluster
TARGET_NODE="target-redis-node-0:7006"

# File to use for saving and restoring data (binary format)
DUMP_FILE="redis_dump.bin"
EOF
    echo "config.env created successfully."
    ;;
  --save)
    save_data
    ;;
  --restore)
    restore_data
    ;;
  *)
    echo "Error: Unknown command '$1'."
    show_help
    exit 1
    ;;
esac

exit 0