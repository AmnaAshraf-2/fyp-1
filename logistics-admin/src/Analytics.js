import React, { useState, useEffect } from 'react';
import { ref, onValue, off } from 'firebase/database';
import { database } from './firebase';
import { calculateTotalCommission, calculateCommission } from './commissionCalculator';
import './Analytics.css';

function Analytics() {
    const [analytics, setAnalytics] = useState({
        bookings: [],
        users: [],
        loading: true
    });
    const [timeRange, setTimeRange] = useState('30'); // 7, 30, 90, all

    useEffect(() => {
        const requestsRef = ref(database, 'requests');
        const usersRef = ref(database, 'users');

        const unsubscribeRequests = onValue(requestsRef, (snapshot) => {
            const requestsData = snapshot.val();
            if (requestsData) {
                const bookings = Object.entries(requestsData).map(([id, booking]) => ({
                    id,
                    ...booking
                }));
                setAnalytics(prev => ({ ...prev, bookings }));
            }
        });

        const unsubscribeUsers = onValue(usersRef, (snapshot) => {
            const usersData = snapshot.val();
            if (usersData) {
                const users = Object.entries(usersData).map(([id, user]) => ({
                    id,
                    ...user
                }));
                setAnalytics(prev => ({ ...prev, users, loading: false }));
            } else {
                setAnalytics(prev => ({ ...prev, loading: false }));
            }
        });

        return () => {
            off(requestsRef, 'value', unsubscribeRequests);
            off(usersRef, 'value', unsubscribeUsers);
        };
    }, []);

    const getFilteredBookings = () => {
        const now = Date.now();
        const days = parseInt(timeRange);
        const cutoff = days === 0 ? 0 : now - (days * 24 * 60 * 60 * 1000);
        
        return analytics.bookings.filter(booking => {
            if (booking.status === 'pending') return false;
            if (timeRange === 'all') return true;
            return booking.timestamp >= cutoff;
        });
    };

    const filteredBookings = getFilteredBookings();

    // Calculate metrics
    const calculateMetrics = () => {
        const completed = filteredBookings.filter(b => b.status === 'completed');
        const cancelled = filteredBookings.filter(b => b.status === 'cancelled');
        const inProgress = filteredBookings.filter(b => b.status === 'in_progress');
        const accepted = filteredBookings.filter(b => b.status === 'accepted');

        const totalRevenue = completed.reduce((sum, b) => sum + (parseFloat(b.offerFare || b.finalFare) || 0), 0);
        const avgBookingValue = completed.length > 0 ? totalRevenue / completed.length : 0;
        const completionRate = filteredBookings.length > 0 ? (completed.length / filteredBookings.length) * 100 : 0;

        // Calculate commission metrics
        const commissionData = calculateTotalCommission(filteredBookings);

        // Group by date for trends
        const bookingsByDate = {};
        filteredBookings.forEach(booking => {
            if (booking.timestamp) {
                const date = new Date(booking.timestamp);
                const dateKey = date.toISOString().split('T')[0];
                if (!bookingsByDate[dateKey]) {
                    bookingsByDate[dateKey] = { total: 0, completed: 0, revenue: 0, commission: 0 };
                }
                bookingsByDate[dateKey].total++;
                if (booking.status === 'completed') {
                    const fare = parseFloat(booking.offerFare || booking.finalFare) || 0;
                    bookingsByDate[dateKey].completed++;
                    bookingsByDate[dateKey].revenue += fare;
                    const commissionData = calculateCommission(fare);
                    bookingsByDate[dateKey].commission += commissionData.commission;
                }
            }
        });

        // Top customers
        const customerBookings = {};
        filteredBookings.forEach(booking => {
            if (booking.customerId) {
                if (!customerBookings[booking.customerId]) {
                    customerBookings[booking.customerId] = 0;
                }
                customerBookings[booking.customerId]++;
            }
        });

        const topCustomers = Object.entries(customerBookings)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([customerId, count]) => {
                const customer = analytics.users.find(u => u.id === customerId);
                return {
                    id: customerId,
                    name: customer?.name || 'Unknown',
                    email: customer?.email || 'N/A',
                    bookings: count
                };
            });

        // Top drivers
        const driverBookings = {};
        filteredBookings
            .filter(b => b.status === 'completed' && b.acceptedDriverId)
            .forEach(booking => {
                if (!driverBookings[booking.acceptedDriverId]) {
                    driverBookings[booking.acceptedDriverId] = 0;
                }
                driverBookings[booking.acceptedDriverId]++;
            });

        const topDrivers = Object.entries(driverBookings)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([driverId, count]) => {
                const driver = analytics.users.find(u => u.id === driverId);
                return {
                    id: driverId,
                    name: driver?.name || driver?.driverDetails?.fullName || 'Unknown',
                    email: driver?.email || 'N/A',
                    completed: count
                };
            });

        return {
            total: filteredBookings.length,
            completed: completed.length,
            cancelled: cancelled.length,
            inProgress: inProgress.length,
            accepted: accepted.length,
            totalRevenue,
            avgBookingValue,
            completionRate,
            bookingsByDate,
            topCustomers,
            topDrivers,
            totalCommission: commissionData.totalCommission,
            avgCommission: commissionData.averageCommission,
            totalDriverReceives: commissionData.totalDriverReceives
        };
    };

    const metrics = calculateMetrics();

    // Prepare chart data
    const getChartData = () => {
        const dates = Object.keys(metrics.bookingsByDate).sort();
        const maxBookings = Math.max(...dates.map(d => metrics.bookingsByDate[d].total), 1);
        const maxRevenue = Math.max(...dates.map(d => metrics.bookingsByDate[d].revenue), 1);
        const maxCommission = Math.max(...dates.map(d => metrics.bookingsByDate[d].commission || 0), 1);

        return dates.map(date => ({
            date,
            bookings: metrics.bookingsByDate[date].total,
            completed: metrics.bookingsByDate[date].completed,
            revenue: metrics.bookingsByDate[date].revenue,
            commission: metrics.bookingsByDate[date].commission || 0,
            bookingsHeight: (metrics.bookingsByDate[date].total / maxBookings) * 100,
            revenueHeight: (metrics.bookingsByDate[date].revenue / maxRevenue) * 100,
            commissionHeight: ((metrics.bookingsByDate[date].commission || 0) / maxCommission) * 100
        }));
    };

    const chartData = getChartData();

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('en-PK', {
            style: 'currency',
            currency: 'PKR',
            maximumFractionDigits: 0
        }).format(amount);
    };

    const formatDate = (dateString) => {
        const date = new Date(dateString + 'T00:00:00');
        const now = new Date();
        const diffTime = Math.abs(now - date);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    };

    if (analytics.loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading analytics...</p>
            </div>
        );
    }

    return (
        <div className="analytics">
            <header className="analytics-header">
                <h1>Analytics Dashboard</h1>
                <p>Comprehensive insights and performance metrics</p>
                <div className="time-range-selector">
                    <label>Time Range:</label>
                    <select value={timeRange} onChange={(e) => setTimeRange(e.target.value)}>
                        <option value="7">Last 7 Days</option>
                        <option value="30">Last 30 Days</option>
                        <option value="90">Last 90 Days</option>
                        <option value="all">All Time</option>
                    </select>
                </div>
            </header>

            {/* Key Metrics */}
            <div className="metrics-grid">
                <div className="metric-card">
                    <div className="metric-icon">📊</div>
                    <div className="metric-content">
                        <h3>{metrics.total}</h3>
                        <p>Total Bookings</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">✅</div>
                    <div className="metric-content">
                        <h3>{metrics.completed}</h3>
                        <p>Completed</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">💰</div>
                    <div className="metric-content">
                        <h3>{formatCurrency(metrics.totalRevenue)}</h3>
                        <p>Total Revenue</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">📈</div>
                    <div className="metric-content">
                        <h3>{metrics.completionRate.toFixed(1)}%</h3>
                        <p>Completion Rate</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">💵</div>
                    <div className="metric-content">
                        <h3>{formatCurrency(metrics.avgBookingValue)}</h3>
                        <p>Avg Booking Value</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">❌</div>
                    <div className="metric-content">
                        <h3>{metrics.cancelled}</h3>
                        <p>Cancelled</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">💵</div>
                    <div className="metric-content">
                        <h3>{formatCurrency(metrics.totalCommission)}</h3>
                        <p>Total Commission</p>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon">📊</div>
                    <div className="metric-content">
                        <h3>{formatCurrency(metrics.avgCommission)}</h3>
                        <p>Avg Commission</p>
                    </div>
                </div>
            </div>

            {/* Charts Section */}
            <div className="charts-section">
                {/* Booking Trends */}
                <div className="chart-card">
                    <h2>Booking Trends</h2>
                    <div className="chart-container">
                        {chartData.length > 0 ? (
                            <div className="bar-chart">
                                {chartData.map((data, index) => (
                                    <div key={index} className="bar-group">
                                        <div className="bar-wrapper">
                                            <div 
                                                className="bar" 
                                                style={{ height: `${data.bookingsHeight}%` }}
                                                title={`${data.bookings} bookings`}
                                            ></div>
                                        </div>
                                        <div className="bar-label">{formatDate(data.date)}</div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="no-data">No data available for selected time range</div>
                        )}
                    </div>
                </div>

                {/* Revenue Trends */}
                <div className="chart-card">
                    <h2>Revenue Trends</h2>
                    <div className="chart-container">
                        {chartData.length > 0 ? (
                            <div className="bar-chart">
                                {chartData.map((data, index) => (
                                    <div key={index} className="bar-group">
                                        <div className="bar-wrapper">
                                            <div 
                                                className="bar revenue-bar" 
                                                style={{ height: `${data.revenueHeight}%` }}
                                                title={formatCurrency(data.revenue)}
                                            ></div>
                                        </div>
                                        <div className="bar-label">{formatDate(data.date)}</div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="no-data">No data available for selected time range</div>
                        )}
                    </div>
                </div>

                {/* Commission Trends */}
                <div className="chart-card">
                    <h2>Commission Trends</h2>
                    <div className="chart-container">
                        {chartData.length > 0 ? (
                            <div className="bar-chart">
                                {chartData.map((data, index) => (
                                    <div key={index} className="bar-group">
                                        <div className="bar-wrapper">
                                            <div 
                                                className="bar commission-bar" 
                                                style={{ height: `${data.commissionHeight}%` }}
                                                title={formatCurrency(data.commission)}
                                            ></div>
                                        </div>
                                        <div className="bar-label">{formatDate(data.date)}</div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="no-data">No data available for selected time range</div>
                        )}
                    </div>
                </div>
            </div>

            {/* Status Distribution & Top Lists */}
            <div className="analytics-grid">
                {/* Status Distribution */}
                <div className="analytics-card">
                    <h2>Status Distribution</h2>
                    <div className="status-chart">
                        <div className="status-item">
                            <div className="status-bar">
                                <div 
                                    className="status-fill completed" 
                                    style={{ width: `${metrics.total > 0 ? (metrics.completed / metrics.total) * 100 : 0}%` }}
                                ></div>
                            </div>
                            <div className="status-info">
                                <span className="status-label">Completed</span>
                                <span className="status-value">{metrics.completed} ({metrics.total > 0 ? ((metrics.completed / metrics.total) * 100).toFixed(1) : 0}%)</span>
                            </div>
                        </div>
                        <div className="status-item">
                            <div className="status-bar">
                                <div 
                                    className="status-fill accepted" 
                                    style={{ width: `${metrics.total > 0 ? (metrics.accepted / metrics.total) * 100 : 0}%` }}
                                ></div>
                            </div>
                            <div className="status-info">
                                <span className="status-label">Accepted</span>
                                <span className="status-value">{metrics.accepted} ({metrics.total > 0 ? ((metrics.accepted / metrics.total) * 100).toFixed(1) : 0}%)</span>
                            </div>
                        </div>
                        <div className="status-item">
                            <div className="status-bar">
                                <div 
                                    className="status-fill in-progress" 
                                    style={{ width: `${metrics.total > 0 ? (metrics.inProgress / metrics.total) * 100 : 0}%` }}
                                ></div>
                            </div>
                            <div className="status-info">
                                <span className="status-label">In Progress</span>
                                <span className="status-value">{metrics.inProgress} ({metrics.total > 0 ? ((metrics.inProgress / metrics.total) * 100).toFixed(1) : 0}%)</span>
                            </div>
                        </div>
                        <div className="status-item">
                            <div className="status-bar">
                                <div 
                                    className="status-fill cancelled" 
                                    style={{ width: `${metrics.total > 0 ? (metrics.cancelled / metrics.total) * 100 : 0}%` }}
                                ></div>
                            </div>
                            <div className="status-info">
                                <span className="status-label">Cancelled</span>
                                <span className="status-value">{metrics.cancelled} ({metrics.total > 0 ? ((metrics.cancelled / metrics.total) * 100).toFixed(1) : 0}%)</span>
                            </div>
                        </div>
                    </div>
                </div>

                {/* Top Customers */}
                <div className="analytics-card">
                    <h2>Top Customers</h2>
                    <div className="top-list">
                        {metrics.topCustomers.length > 0 ? (
                            metrics.topCustomers.map((customer, index) => (
                                <div key={customer.id} className="top-item">
                                    <div className="top-rank">#{index + 1}</div>
                                    <div className="top-info">
                                        <div className="top-name">{customer.name}</div>
                                        <div className="top-email">{customer.email}</div>
                                    </div>
                                    <div className="top-value">{customer.bookings} bookings</div>
                                </div>
                            ))
                        ) : (
                            <div className="no-data">No customer data available</div>
                        )}
                    </div>
                </div>

                {/* Top Drivers */}
                <div className="analytics-card">
                    <h2>Top Drivers</h2>
                    <div className="top-list">
                        {metrics.topDrivers.length > 0 ? (
                            metrics.topDrivers.map((driver, index) => (
                                <div key={driver.id} className="top-item">
                                    <div className="top-rank">#{index + 1}</div>
                                    <div className="top-info">
                                        <div className="top-name">{driver.name}</div>
                                        <div className="top-email">{driver.email}</div>
                                    </div>
                                    <div className="top-value">{driver.completed} completed</div>
                                </div>
                            ))
                        ) : (
                            <div className="no-data">No driver data available</div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

export default Analytics;

