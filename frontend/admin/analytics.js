// Analytics Dashboard Functions
let analyticsData = null;
let charts = {};

async function loadAnalytics() {
    const clientId = 'demo-client';
    const timeRange = document.getElementById('timeRange')?.value || '7d';
    
    try {
        const response = await fetch(`/api/analytics/dashboard/${clientId}?timeRange=${timeRange}`);
        const result = await response.json();
        
        if (result.success) {
            analyticsData = result.data;
            updateAnalyticsDisplay();
        }
    } catch (error) {
        console.error('Error loading analytics:', error);
    }
}

function updateAnalyticsDisplay() {
    if (!analyticsData) return;
    
    const { overview, trends, healthScore } = analyticsData;
    
    // Update metric cards
    const metricsHtml = `
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Total Conversations</span>
                <div class="stat-icon">💬</div>
            </div>
            <div class="stat-value">${overview.total_conversations || 0}</div>
            <div class="stat-change">Active this period</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Unique Users</span>
                <div class="stat-icon">👥</div>
            </div>
            <div class="stat-value">${overview.unique_users || 0}</div>
            <div class="stat-change">Engaged users</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Resolution Rate</span>
                <div class="stat-icon">✅</div>
            </div>
            <div class="stat-value">${Math.round(overview.resolution_rate || 0)}%</div>
            <div class="stat-change">Success rate</div>
        </div>
        <div class="stat-card">
            <div class="stat-header">
                <span class="stat-title">Avg Response Time</span>
                <div class="stat-icon">⚡</div>
            </div>
            <div class="stat-value">${Math.round(overview.avg_response_time || 0)}ms</div>
            <div class="stat-change">Response speed</div>
        </div>
    `;
    
    const analyticsGrid = document.querySelector('#analytics .dashboard-grid');
    if (analyticsGrid) {
        analyticsGrid.innerHTML = metricsHtml;
    }
    
    // Update trends chart if canvas exists
    const trendsCanvas = document.getElementById('trendsChart');
    if (trendsCanvas && trends.length > 0) {
        const ctx = trendsCanvas.getContext('2d');
        
        if (charts.trends) charts.trends.destroy();
        
        charts.trends = new Chart(ctx, {
            type: 'line',
            data: {
                labels: trends.map(t => new Date(t.date).toLocaleDateString()),
                datasets: [{
                    label: 'Conversations',
                    data: trends.map(t => t.conversations),
                    borderColor: '#3b82f6',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
}

// Initialize analytics when page loads
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('analytics')) {
        loadAnalytics();
        setInterval(loadAnalytics, 30000); // Refresh every 30 seconds
    }
});
