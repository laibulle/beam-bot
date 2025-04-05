#!/bin/bash

# Check if running as postgres user
if [ "$(whoami)" != "postgres" ]; then
    echo "This script must be run as postgres user"
    exit 1
fi

# Backup the original configuration file
cp /var/lib/postgresql/data/postgresql.conf /var/lib/postgresql/data/postgresql.conf.backup

# Apply custom configurations
cat << 'EOF' >> /var/lib/postgresql/data/postgresql.conf

# Custom configurations added by setup script

# Memory Configuration
shared_buffers = '2GB'
max_locks_per_transaction = 2048
maintenance_work_mem = '1GB'
effective_cache_size = '6GB'

# Connection Settings
max_connections = 100

# TimescaleDB specific settings
timescaledb.max_background_workers = 8

# Query Planning
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
log_min_duration_statement = 1000
EOF

echo "PostgreSQL custom configuration has been applied successfully"
echo "A backup of the original configuration has been saved as postgresql.conf.backup" 