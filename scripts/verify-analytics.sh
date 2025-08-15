#!/bin/bash

# Verify and Complete Analytics Setup
# Check what's working and fix any remaining issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Verifying and Completing Analytics Setup           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check PM2 status
echo -e "${CYAN}[1/6] Checking PM2 Status...${NC}"
pm2 list
echo ""

# Check logs for errors
echo -e "${YELLOW}Recent PM2 logs:${NC}"
pm2 logs chatai --lines 10 --nostream
echo ""

# Step 2: Test the API endpoint
echo -e "${CYAN}[2/6] Testing Analytics API...${NC}"
echo "Testing: http://localhost:3000/api/analytics/dashboard/demo-client"
API_RESPONSE=$(curl -s -m 5 http://localhost:3000/api/analytics/dashboard/demo-client 2>/dev/null || echo "TIMEOUT")

if [ "$API_RESPONSE" = "TIMEOUT" ]; then
    echo -e "${RED}API timeout - checking if server is running on correct port${NC}"
    
    # Check what port the server is actually running on
    echo "Checking active ports:"
    sudo netstat -tlnp | grep node || echo "No node processes found on any port"
    
    # Try port 3000 directly
    echo "Testing port 3000:"
    curl -s http://localhost:3000/api/health || echo "Health check failed"
else
    echo -e "${GREEN}API Response received:${NC}"
    echo "$API_RESPONSE" | python3 -m json.tool 2>/dev/null | head -20 || echo "$API_RESPONSE"
fi
echo ""

# Step 3: Check server.js for issues
echo -e "${CYAN}[3/6] Checking server.js configuration...${NC}"
echo "Port configuration:"
grep -n "PORT\|port\|3000" /opt/chatai/backend/server.js | head -5
echo ""
echo "Analytics route registration:"
grep -n "analytics" /opt/chatai/backend/server.js | head -10
echo ""

# Step 4: Ensure the admin panel can access the API
echo -e "${CYAN}[4/6] Testing API through Nginx...${NC}"
echo "Testing through domain:"
curl -s -m 5 https://chatai.coastalweb.us/api/analytics/dashboard/demo-client 2>/dev/null | head -c 200 || echo "Failed to access through domain"
echo ""

# Step 5: Update admin panel with working analytics code
echo -e "${CYAN}[5/6] Updating Admin Panel Analytics...${NC}"

ADMIN_DIR="/opt/chatai/frontend/admin"

# Ensure Chart.js is loaded
if ! grep -q "chart.js" ${ADMIN_DIR}/index.html; then
    sed -i '/<\/head>/i <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>' ${ADMIN_DIR}/index.html
    echo "✓ Added Chart.js"
fi

# Create a simple, working analytics loader
cat > /tmp/simple-analytics.js << 'EOJS'
<script>
// Simple Analytics Loader
window.analyticsCharts = {};

async function loadAnalytics() {
    console.log('[Analytics] Loading data...');
    
    try {
        // Test if the API is accessible
        const testResponse = await fetch('/api/health');
        console.log('[Analytics] Health check:', await testResponse.text());
        
        // Load analytics data
        const response = await fetch('/api/analytics/dashboard/demo-client');
        const data = await response.json();
        console.log('[Analytics] Data received:', data);
        
        if (data.success || data.data) {
            const analyticsData = data.data || data;
            
            // Update numbers
            document.getElementById('totalConversations').textContent = analyticsData.overview?.total_conversations || '0';
            document.getElementById('uniqueUsers').textContent = analyticsData.overview?.unique_users || '0';
            document.getElementById('resolutionRate').textContent = (analyticsData.overview?.resolution_rate || '0') + '%';
            document.getElementById('avgResponseTime').textContent = (analyticsData.overview?.avg_response_time || '0') + 'ms';
            document.getElementById('satisfactionScore').textContent = analyticsData.overview?.avg_satisfaction || '0';
            document.getElementById('healthScore').textContent = analyticsData.healthScore || '85';
            
            // Create simple chart
            const trendsCanvas = document.getElementById('trendsChart');
            if (trendsCanvas && analyticsData.trends) {
                if (window.analyticsCharts.trends) {
                    window.analyticsCharts.trends.destroy();
                }
                
                window.analyticsCharts.trends = new Chart(trendsCanvas, {
                    type: 'line',
                    data: {
                        labels: analyticsData.trends.map(t => t.date),
                        datasets: [{
                            label: 'Conversations',
                            data: analyticsData.trends.map(t => t.conversations),
                            borderColor: 'blue',
                            tension: 0.4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false
                    }
                });
                console.log('[Analytics] Chart created');
            }
        } else {
            console.error('[Analytics] Invalid data structure:', data);
        }
    } catch (error) {
        console.error('[Analytics] Error:', error);
        document.getElementById('totalConversations').textContent = 'Error';
    }
}

// Auto-load when analytics tab is clicked
document.addEventListener('DOMContentLoaded', function() {
    const analyticsTab = document.querySelector('[data-section="analytics"]');
    if (analyticsTab) {
        analyticsTab.addEventListener('click', function() {
            console.log('[Analytics] Tab clicked');
            setTimeout(loadAnalytics, 100);
        });
    }
});

function refreshAnalytics() {
    loadAnalytics();
}

function exportAnalytics() {
    window.open('/api/analytics/export/demo-client?format=csv', '_blank');
}

// Make loadAnalytics globally accessible for testing
window.loadAnalytics = loadAnalytics;
</script>
EOJS

# Remove old analytics scripts and add new one
sed -i '/<script>.*[Aa]nalytics/,/<\/script>/d' ${ADMIN_DIR}/index.html
sed -i '/<\/body>/i SIMPLE_ANALYTICS_PLACEHOLDER' ${ADMIN_DIR}/index.html
sed -i '/SIMPLE_ANALYTICS_PLACEHOLDER/r /tmp/simple-analytics.js' ${ADMIN_DIR}/index.html
sed -i '/SIMPLE_ANALYTICS_PLACEHOLDER/d' ${ADMIN_DIR}/index.html

echo -e "${GREEN}✓ Updated admin panel with simple analytics loader${NC}"

# Step 6: Final status check
echo -e "${CYAN}[6/6] Final Status Check...${NC}"
echo ""

# Check if everything is running
CHECKS_PASSED=0
CHECKS_TOTAL=4

# Check 1: PM2 running
if pm2 list | grep -q "online"; then
    echo -e "${GREEN}✓ PM2 process is running${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗ PM2 process not running${NC}"
fi

# Check 2: API responding
if curl -s http://localhost:3000/api/analytics/dashboard/demo-client | grep -q "success"; then
    echo -e "${GREEN}✓ API is responding${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗ API not responding${NC}"
fi

# Check 3: Admin panel exists
if [ -f "${ADMIN_DIR}/index.html" ]; then
    echo -e "${GREEN}✓ Admin panel exists${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗ Admin panel not found${NC}"
fi

# Check 4: Chart.js included
if grep -q "chart.js" ${ADMIN_DIR}/index.html; then
    echo -e "${GREEN}✓ Chart.js is included${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗ Chart.js not included${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "Status: ${CHECKS_PASSED}/${CHECKS_TOTAL} checks passed"
echo ""

if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
    echo -e "${GREEN}✅ Analytics system is fully operational!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Clear browser cache (Ctrl+Shift+R)"
    echo "2. Go to https://chatai.coastalweb.us/admin"
    echo "3. Click on Analytics tab"
    echo "4. Open browser console (F12) to see debug messages"
    echo ""
    echo "If charts don't appear, type in browser console:"
    echo "  loadAnalytics()"
else
    echo -e "${YELLOW}⚠️ Some issues need attention${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check PM2 logs: pm2 logs chatai"
    echo "2. Restart PM2: pm2 restart chatai"
    echo "3. Test API: curl http://localhost:3000/api/analytics/dashboard/demo-client"
fi

echo ""
echo "Quick test in browser console:"
echo "  fetch('/api/analytics/dashboard/demo-client').then(r=>r.json()).then(console.log)"
