#!/bin/bash
echo "=== ChatAI Analytics Status ==="
echo ""
echo "PostgreSQL Status:"
systemctl status postgresql | grep Active
echo ""
echo "Redis Status:"
systemctl status redis-server | grep Active
echo ""
echo "Database Tables:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "\dt" 2>/dev/null | head -20
echo ""
echo "Recent Conversations:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "SELECT COUNT(*) as total FROM conversations;" 2>/dev/null
echo ""
echo "Recent Messages:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "SELECT COUNT(*) as total FROM messages;" 2>/dev/null
echo ""
echo "PM2 Status:"
pm2 status
