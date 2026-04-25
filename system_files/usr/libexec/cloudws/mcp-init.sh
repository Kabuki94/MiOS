#!/usr/bin/bash
# cloudws-mcp-init: Provisions the Claude OS Persistent Memory Vaults.
# Incorporates sqlite-vec, FTS5, and the Redis Pub/Sub framework for real-time telemetry.

set -euo pipefail

MCP_DIR="/var/lib/cloudws/mcp"
LOG_DIR="/var/log/cloudws/mcp"

# Ensure persistence directories exist (handled by tmpfiles.d generally, but as a fallback here)
mkdir -p "$MCP_DIR" "$LOG_DIR"
chown -R cloudws:cloudws "$MCP_DIR" "$LOG_DIR"

PROJECT_NAME="cloudws"
VAULTS=(
    "${PROJECT_NAME}-project_memories.db"
    "${PROJECT_NAME}-project_profile.db"
    "${PROJECT_NAME}-project_index.db"
    "${PROJECT_NAME}-knowledge_docs.db"
)

# Provision missing SQLite vaults
for vault in "${VAULTS[@]}"; do
    vault_path="${MCP_DIR}/${vault}"
    if [ ! -f "$vault_path" ]; then
        echo "[MCP] Provisioning new SQLite knowledge base: $vault"
        # Basic schema initialization (handled fully by MCP server, creating placeholder here)
        sqlite3 "$vault_path" "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT);"
        chown cloudws:cloudws "$vault_path"
        chmod 0600 "$vault_path"
    fi
done

# Validate Redis Pub/Sub connection readiness
if ! systemctl is-active --quiet redis.service; then
    echo "[MCP] WARN: Redis Pub/Sub service is not active. Telemetry ingestion may fail." >&2
fi

echo "[MCP] Core vaults provisioned. Preparing to launch server."
exit 0
