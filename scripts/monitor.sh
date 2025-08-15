#!/bin/bash

# Health check endpoints
check_service() {
    local service=$1
    local url=$2
    
    if curl -s -f -o /dev/null "$url"; then
        echo "✅ $service: OK"
        return 0
    else
        echo "❌ $service: FAILED"
        return 1
    fi
}

echo "=== ChatAI System Health Check ==="
echo "Time: $(date)"
echo ""

# Check services
check_service "Frontend" "http://localhost"
check_service "API" "http://localhost:3000/api/health"
check_service "Analytics" "http://localhost:3000/api/analytics/dashboard/demo-client"

# Check processes
echo ""
echo "Process Status:"
pm2 status | grep chatai

# Check disk space
echo ""
echo "Disk Usage:"
df -h | grep -E '^/dev/' | awk '{print $6 ": " $5}'

# Check memory
echo ""
echo "Memory Usage:"
free -h | grep Mem | awk '{print "Used: " $3 " / " $2}'

# Check database
echo ""
echo "Database Status:"
PGPASSWORD="chatai_analytics_2024" psql -U chatai_user -h localhost -d chatai_analytics -c "SELECT COUNT(*) as conversations FROM conversations;" 2>/dev/null || echo "Database connection failed"
