#!/bin/bash

# Fix Analytics Display in Admin Panel

ADMIN_DIR="/opt/chatai/frontend/admin"

echo "Fixing Analytics Display in Admin Panel..."

# First, check if the analytics section exists in the HTML
if ! grep -q 'id="analytics"' ${ADMIN_DIR}/index.html; then
    echo "Adding analytics section to admin panel..."
    
    # Find where to insert (after conversations section)
    # We'll add it before the closing main tag
    
    # Create a temporary file with the analytics section
    cat > /tmp/analytics-section.html << 'EOANALYTICS'

<!-- Analytics Section -->
<section id="analytics" class="section">
    <div class="header">
        <h2>Analytics Dashboard</h2>
        <div class="header-actions">
            <select id="timeRange" class="btn btn-secondary" onchange="loadAnalytics()">
                <option value="24h">Last 24 Hours</option>
                <option value="7d" selected>Last 7 Days</option>
                <option value="30d">Last 30 Days</option>
                <option value="90d">Last 90 Days</option>
            </select>
            <button class="btn btn-secondary" onclick="exportAnalytics()">Export</button>
            <button class="btn btn-primary" onclick="refreshAnalytics()">Refresh</button>
        </div>
    </div>

    <!-- Key Metrics Grid -->
    <div class="dashboard-grid" id="analytics-metrics">
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Total Conversations</span>
                <div class="stat-icon">💬</div>
            </div>
            <div class="stat-value" id="totalConversations">0</div>
            <div class="stat-change positive">Loading...</div>
        </div>

        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Unique Users</span>
                <div class="stat-icon">👥</div>
            </div>
            <div class="stat-value" id="uniqueUsers">0</div>
            <div class="stat-change positive">Loading...</div>
        </div>

        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Resolution Rate</span>
                <div class="stat-icon">✅</div>
            </div>
            <div class="stat-value" id="resolutionRate">0%</div>
            <div class="stat-change positive">Loading...</div>
        </div>

        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Avg Response Time</span>
                <div class="stat-icon">⚡</div>
            </div>
            <div class="stat-value" id="avgResponseTime">0ms</div>
            <div class="stat-change positive">Loading...</div>
        </div>

        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Satisfaction Score</span>
                <div class="stat-icon">😊</div>
            </div>
            <div class="stat-value" id="satisfactionScore">0</div>
            <div class="stat-change positive">Loading...</div>
        </div>

        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Health Score</span>
                <div class="stat-icon">🏥</div>
            </div>
            <div class="stat-value" id="healthScore">0</div>
            <div class="stat-change positive">System Health</div>
        </div>
    </div>

    <!-- Charts Container -->
    <div class="table-container" style="margin-top: 2rem;">
        <h3>Conversation Trends</h3>
        <canvas id="trendsChart" style="max-height: 300px;"></canvas>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-top: 2rem;">
        <div class="table-container">
            <h3>User Sentiment</h3>
            <canvas id="sentimentChart" style="max-height: 200px;"></canvas>
        </div>
        
        <div class="table-container">
            <h3>Response Times</h3>
            <canvas id="responseTimeChart" style="max-height: 200px;"></canvas>
        </div>
    </div>

    <!-- Top Questions Table -->
    <div class="table-container" style="margin-top: 2rem;">
        <h3>Top Questions</h3>
        <div id="topQuestions" style="max-height: 400px; overflow-y: auto;">
            <table>
                <thead>
                    <tr>
                        <th>Question</th>
                        <th>Frequency</th>
                        <th>Success Rate</th>
                        <th>Intent</th>
                    </tr>
                </thead>
                <tbody id="topQuestionsBody">
                    <tr>
                        <td colspan="4" style="text-align: center;">No data available</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>

EOANALYTICS

    # Insert before the closing main tag
    sed -i '/<\/main>/i ANALYTICS_PLACEHOLDER' ${ADMIN_DIR}/index.html
    sed -i '/ANALYTICS_PLACEHOLDER/r /tmp/analytics-section.html' ${ADMIN_DIR}/index.html
    sed -i '/ANALYTICS_PLACEHOLDER/d' ${ADMIN_DIR}/index.html
fi

# Add Chart.js if not already included
if ! grep -q "chart.js" ${ADMIN_DIR}/index.html; then
    echo "Adding Chart.js library..."
    sed -i '/<\/head>/i <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>' ${ADMIN_DIR}/index.html
fi

# Add analytics JavaScript before closing body tag
if ! grep -q "loadAnalytics" ${ADMIN_DIR}/index.html; then
    echo "Adding analytics JavaScript..."
    
    cat > /tmp/analytics-js.html << 'EOJS'

<script>
// Analytics Functions
let analyticsData = null;
let analyticsCharts = {};

async function loadAnalytics() {
    console.log('Loading analytics...');
    const clientId = document.getElementById('testClientSelect')?.value || 'demo-client';
    const timeRange = document.getElementById('timeRange')?.value || '7d';
    
    try {
        const response = await fetch(`/api/analytics/dashboard/${clientId}?timeRange=${timeRange}`);
        const result = await response.json();
        
        console.log('Analytics data:', result);
        
        if (result.success) {
            analyticsData = result.data;
            updateAnalyticsDisplay();
        } else {
            console.error('Failed to load analytics:', result.error);
        }
    } catch (error) {
        console.error('Error loading analytics:', error);
        // Show error message
        document.getElementById('totalConversations').textContent = 'Error';
        document.getElementById('uniqueUsers').textContent = 'Error';
    }
}

function updateAnalyticsDisplay() {
    if (!analyticsData) return;
    
    const { overview, trends, healthScore } = analyticsData;
    
    console.log('Updating display with:', overview);
    
    // Update metric values
    document.getElementById('totalConversations').textContent = 
        formatNumber(overview.total_conversations || 0);
    document.getElementById('uniqueUsers').textContent = 
        formatNumber(overview.unique_users || 0);
    document.getElementById('resolutionRate').textContent = 
        Math.round(overview.resolution_rate || 0) + '%';
    document.getElementById('avgResponseTime').textContent = 
        Math.round(overview.avg_response_time || 0) + 'ms';
    document.getElementById('satisfactionScore').textContent = 
        (overview.avg_satisfaction || 0).toFixed(1);
    document.getElementById('healthScore').textContent = 
        Math.round(healthScore || 0);
    
    // Update trends chart
    updateTrendsChart();
    
    // Update other charts
    updateSentimentChart();
    updateResponseTimeChart();
}

function updateTrendsChart() {
    if (!analyticsData || !analyticsData.trends) return;
    
    const canvas = document.getElementById('trendsChart');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    
    // Destroy existing chart if it exists
    if (analyticsCharts.trends) {
        analyticsCharts.trends.destroy();
    }
    
    // Create new chart
    analyticsCharts.trends = new Chart(ctx, {
        type: 'line',
        data: {
            labels: analyticsData.trends.map(t => 
                new Date(t.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
            ),
            datasets: [
                {
                    label: 'Conversations',
                    data: analyticsData.trends.map(t => t.conversations || 0),
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    tension: 0.4
                },
                {
                    label: 'Unique Users',
                    data: analyticsData.trends.map(t => t.users || 0),
                    borderColor: '#8b5cf6',
                    backgroundColor: 'rgba(139, 92, 246, 0.1)',
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    labels: { color: '#9ca3af' }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(75, 85, 99, 0.3)' },
                    ticks: { color: '#9ca3af' }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });
}

function updateSentimentChart() {
    const canvas = document.getElementById('sentimentChart');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    
    if (analyticsCharts.sentiment) {
        analyticsCharts.sentiment.destroy();
    }
    
    // Mock data for now - replace with real data when available
    analyticsCharts.sentiment = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Positive', 'Neutral', 'Negative'],
            datasets: [{
                data: [65, 25, 10],
                backgroundColor: ['#10b981', '#6b7280', '#ef4444']
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#9ca3af' }
                }
            }
        }
    });
}

function updateResponseTimeChart() {
    const canvas = document.getElementById('responseTimeChart');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    
    if (analyticsCharts.responseTime) {
        analyticsCharts.responseTime.destroy();
    }
    
    // Mock data for now
    analyticsCharts.responseTime = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['0-1s', '1-2s', '2-3s', '3s+'],
            datasets: [{
                label: 'Response Distribution',
                data: [45, 30, 15, 10],
                backgroundColor: '#3b82f6'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(75, 85, 99, 0.3)' },
                    ticks: { color: '#9ca3af' }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });
}

function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
}

function refreshAnalytics() {
    loadAnalytics();
}

function exportAnalytics() {
    const clientId = document.getElementById('testClientSelect')?.value || 'demo-client';
    const timeRange = document.getElementById('timeRange')?.value || '7d';
    window.location.href = `/api/analytics/export/${clientId}?timeRange=${timeRange}&format=csv`;
}

// Auto-load analytics when section becomes active
document.addEventListener('DOMContentLoaded', function() {
    // Override the navigation click handler to load analytics
    const analyticsNavLink = document.querySelector('[data-section="analytics"]');
    if (analyticsNavLink) {
        analyticsNavLink.addEventListener('click', function() {
            setTimeout(loadAnalytics, 100);
        });
    }
});
</script>

EOJS

    sed -i '/<\/body>/i ANALYTICS_JS_PLACEHOLDER' ${ADMIN_DIR}/index.html
    sed -i '/ANALYTICS_JS_PLACEHOLDER/r /tmp/analytics-js.html' ${ADMIN_DIR}/index.html
    sed -i '/ANALYTICS_JS_PLACEHOLDER/d' ${ADMIN_DIR}/index.html
fi

echo "Analytics display fixed!"
echo "Please refresh your browser and try the Analytics tab again."
