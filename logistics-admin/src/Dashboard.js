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
        cancelledBookings: 0,
        completedBookings: 0,
    });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const usersRef = ref(database, 'users');
        const requestsRef = ref(database, 'requests');

        // Listen to users data
        const unsubscribeUsers = onValue(usersRef, (snapshot) => {
            const usersData = snapshot.val();
            if (usersData) {
                const users = Object.values(usersData);
                const customers = users.filter(user => user.role === 'customer' || !user.role);
                const drivers = users.filter(user => user.role === 'driver');
                const enterprises = users.filter(user => user.role === 'enterprise');

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
                // Exclude pending bookings from total count
                const nonPendingRequests = requests.filter(req => req.status !== 'pending');
                const cancelled = requests.filter(req => req.status === 'cancelled');
                const completed = requests.filter(req => req.status === 'completed');
                setStats(prev => ({
                    ...prev,
                    totalBookings: nonPendingRequests.length,
                    cancelledBookings: cancelled.length,
                    completedBookings: completed.length
                }));
            }
        });

        setLoading(false);

        return () => {
            off(usersRef, 'value', unsubscribeUsers);
            off(requestsRef, 'value', unsubscribeRequests);
        };
    }, []);

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
                <div className="stat-card stat-card-primary">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">👥</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.totalUsers}</h3>
                        <p>Total Users</p>
                    </div>
                </div>

                <div className="stat-card stat-card-blue">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">🛒</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.totalCustomers}</h3>
                        <p>Customers</p>
                    </div>
                </div>

                <div className="stat-card stat-card-purple">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">🚛</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.totalDrivers}</h3>
                        <p>Drivers</p>
                    </div>
                </div>

                <div className="stat-card stat-card-green">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">🏢</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.totalEnterprises}</h3>
                        <p>Enterprises</p>
                    </div>
                </div>

                <div className="stat-card stat-card-orange">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">📦</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.totalBookings}</h3>
                        <p>Total Bookings</p>
                    </div>
                </div>

                <div className="stat-card stat-card-red">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">❌</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.cancelledBookings}</h3>
                        <p>Cancelled</p>
                    </div>
                </div>

                <div className="stat-card stat-card-teal">
                    <div className="stat-icon-wrapper">
                        <div className="stat-icon">✅</div>
                    </div>
                    <div className="stat-content">
                        <h3>{stats.completedBookings}</h3>
                        <p>Completed</p>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default Dashboard;
