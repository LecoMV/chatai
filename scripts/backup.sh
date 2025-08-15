#!/bin/bash
BACKUP_DIR="/opt/chatai/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
PGPASSWORD="chatai_analytics_2024" pg_dump -U chatai_user -h localhost chatai_analytics > "$BACKUP_DIR/db_$TIMESTAMP.sql"

# Backup client configurations
tar -czf "$BACKUP_DIR/configs_$TIMESTAMP.tar.gz" /opt/chatai/backend/config/clients/

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $TIMESTAMP"
