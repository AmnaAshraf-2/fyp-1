import React, { useState, useEffect } from 'react';
import { ref, onValue, off } from 'firebase/database';
import { database } from './firebase';
import './Dashboard.css';

function Dashboard() {
    const [stats, setStats] = useState({
        totalUsers: 0,
        totalCustomers: 0,
        totalDrivers: 0,
        totalEnterprises: 0,
        totalBookings: 0,
        pendingBookings: 0,
        completedBookings: 0,
        totalRevenue: 0
    });
    const [loading, setLoading] = useState(true);
    const [recentUsers, setRecentUsers] = useState([]);
    const [recentBookings, setRecentBookings] = useState([]);

    useEffect(() => {
        const usersRef = ref(database, 'users');
        const requestsRef = ref(database, 'requests');
        const enterprisesRef = ref(database, 'enterprises');

        // Listen to users data
        const unsubscribeUsers = onValue(usersRef, (snapshot) => {
            const usersData = snapshot.val();
            if (usersData) {
                const users = Object.values(usersData);
                const customers = users.filter(user => user.role === 'customer' || !user.role);
                const drivers = users.filter(user => user.role === 'driver');
                const enterprises = users.filter(user => user.role === 'enterprise');

                // Get recent users (last 5)
                const sortedUsers = users
                    .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
                    .slice(0, 5);

                setRecentUsers(sortedUsers);

                setStats(prev => ({
                    ...prev,
                    totalUsers: users.length,
                    totalCustomers: customers.length,
                    totalDrivers: drivers.length,
                    totalEnterprises: enterprises.length
                }));
            }
        });

        // Listen to requests/bookings data
        const unsubscribeRequests = onValue(requestsRef, (snapshot) => {
            const requestsData = snapshot.val();
            if (requestsData) {
                const requests = Object.values(requestsData);
                const pending = requests.filter(req => req.status === 'pending');
                const completed = requests.filter(req => req.status === 'completed');
                const totalRevenue = requests
                    .filter(req => req.status === 'completed')
                    .reduce((sum, req) => sum + (parseFloat(req.offerFare) || 0), 0);

                // Get recent bookings (last 5)
                const sortedBookings = requests
                    .sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0))
                    .slice(0, 5);

                setRecentBookings(sortedBookings);

                setStats(prev => ({
                    ...prev,
                    totalBookings: requests.length,
                    pendingBookings: pending.length,
                    completedBookings: completed.length,
                    totalRevenue: totalRevenue
                }));
            }
        });

        setLoading(false);

        return () => {
            off(usersRef, 'value', unsubscribeUsers);
            off(requestsRef, 'value', unsubscribeRequests);
        };
    }, []);

    const formatDate = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    };

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('en-PK', {
            style: 'currency',
            currency: 'PKR'
        }).format(amount);
    };

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading dashboard...</p>
            </div>
        );
    }

    return (
        <div className="dashboard">
            <header className="dashboard-header">
                <h1>Logistics App Admin Dashboard</h1>
                <p>Real-time monitoring and management</p>
            </header>

            {/* Statistics Cards */}
            <div className="stats-grid">
                <div className="stat-card">
                    <div className="stat-icon">👥</div>
                    <div className="stat-content">
                        <h3>{stats.totalUsers}</h3>
                        <p>Total Users</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">🛒</div>
                    <div className="stat-content">
                        <h3>{stats.totalCustomers}</h3>
                        <p>Customers</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">🚛</div>
                    <div className="stat-content">
                        <h3>{stats.totalDrivers}</h3>
                        <p>Drivers</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">🏢</div>
                    <div className="stat-content">
                        <h3>{stats.totalEnterprises}</h3>
                        <p>Enterprises</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">📦</div>
                    <div className="stat-content">
                        <h3>{stats.totalBookings}</h3>
                        <p>Total Bookings</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">⏳</div>
                    <div className="stat-content">
                        <h3>{stats.pendingBookings}</h3>
                        <p>Pending</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">✅</div>
                    <div className="stat-content">
                        <h3>{stats.completedBookings}</h3>
                        <p>Completed</p>
                    </div>
                </div>

                <div className="stat-card">
                    <div className="stat-icon">💰</div>
                    <div className="stat-content">
                        <h3>{formatCurrency(stats.totalRevenue)}</h3>
                        <p>Total Revenue</p>
                    </div>
                </div>
            </div>

            {/* Recent Activity */}
            <div className="recent-activity">
                <div className="recent-users">
                    <h3>Recent Users</h3>
                    <div className="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Email</th>
                                    <th>Role</th>
                                    <th>Phone</th>
                                    <th>Joined</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentUsers.map((user, index) => (
                                    <tr key={index}>
                                        <td>{user.name || 'N/A'}</td>
                                        <td>{user.email || 'N/A'}</td>
                                        <td>
                                            <span className={`role-badge ${user.role || 'customer'}`}>
                                                {user.role || 'Customer'}
                                            </span>
                                        </td>
                                        <td>{user.phone || 'N/A'}</td>
                                        <td>{formatDate(user.createdAt)}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>

                <div className="recent-bookings">
                    <h3>Recent Bookings</h3>
                    <div className="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th>Load Name</th>
                                    <th>Type</th>
                                    <th>Weight</th>
                                    <th>Fare</th>
                                    <th>Status</th>
                                    <th>Date</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentBookings.map((booking, index) => (
                                    <tr key={index}>
                                        <td>{booking.loadName || 'N/A'}</td>
                                        <td>{booking.loadType || 'N/A'}</td>
                                        <td>{booking.weight ? `${booking.weight} ${booking.weightUnit || 'kg'}` : 'N/A'}</td>
                                        <td>{booking.offerFare ? formatCurrency(booking.offerFare) : 'N/A'}</td>
                                        <td>
                                            <span className={`status-badge ${booking.status}`}>
                                                {booking.status || 'Pending'}
                                            </span>
                                        </td>
                                        <td>{formatDate(booking.timestamp)}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default Dashboard;
