import React, { useState, useEffect } from 'react';
import { ref, onValue, off } from 'firebase/database';
import { database } from './firebase';
import { calculateCommission, calculateTotalCommission } from './commissionCalculator';
import './Commission.css';

function Commission() {
    const [bookings, setBookings] = useState([]);
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [timeRange, setTimeRange] = useState('all');
    const [sortBy, setSortBy] = useState('commission');
    const [sortOrder, setSortOrder] = useState('desc');

    useEffect(() => {
        const bookingsRef = ref(database, 'requests');
        const usersRef = ref(database, 'users');

        const unsubscribeBookings = onValue(bookingsRef, (snapshot) => {
            const bookingsData = snapshot.val();
            if (bookingsData) {
                const bookingsList = Object.entries(bookingsData).map(([id, booking]) => ({
                    id,
                    ...booking
                }));
                setBookings(bookingsList);
            }
        });

        const unsubscribeUsers = onValue(usersRef, (snapshot) => {
            const usersData = snapshot.val();
            if (usersData) {
                const usersList = Object.entries(usersData).map(([id, user]) => ({
                    id,
                    ...user
                }));
                setUsers(usersList);
            }
            setLoading(false);
        });

        return () => {
            off(bookingsRef, 'value', unsubscribeBookings);
            off(usersRef, 'value', unsubscribeUsers);
        };
    }, []);

    const getUserById = (userId) => {
        return users.find(user => user.id === userId) || {};
    };

    const getFilteredBookings = () => {
        const now = Date.now();
        const days = parseInt(timeRange);
        const cutoff = days === 0 ? 0 : now - (days * 24 * 60 * 60 * 1000);

        return bookings
            .filter(booking => {
                // Only show completed bookings - explicitly exclude accepted, cancelled, canceled, and any other statuses
                const status = booking.status?.toLowerCase();
                if (status !== 'completed') return false;

                // Time range filter
                if (timeRange !== 'all' && booking.timestamp < cutoff) return false;

                // Search filter
                const customer = getUserById(booking.customerId);
                const matchesSearch =
                    booking.loadName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    customer.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    customer.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    booking.pickupLocation?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    booking.destinationLocation?.toLowerCase().includes(searchTerm.toLowerCase());

                return matchesSearch;
            })
            .map(booking => {
                const fare = parseFloat(booking.finalFare || booking.offerFare) || 0;
                const commissionData = calculateCommission(fare);
                return {
                    ...booking,
                    fare,
                    commission: commissionData.commission,
                    driverReceives: commissionData.driverReceives,
                    commissionPercentage: commissionData.percentage
                };
            })
            .sort((a, b) => {
                let aValue = a[sortBy] || 0;
                let bValue = b[sortBy] || 0;

                if (sortOrder === 'asc') {
                    return aValue > bValue ? 1 : -1;
                } else {
                    return aValue < bValue ? 1 : -1;
                }
            });
    };

    const filteredBookings = getFilteredBookings();
    const commissionStats = calculateTotalCommission(bookings);

    const formatCurrency = (amount) => {
        return new Intl.NumberFormat('en-PK', {
            style: 'currency',
            currency: 'PKR'
        }).format(amount);
    };

    const formatDate = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    };

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading commission data...</p>
            </div>
        );
    }

    return (
        <div className="commission-page">
            <header className="page-header">
                <h1>Commission Management</h1>
                <p>Track and manage commission earnings from completed trips</p>
            </header>

            {/* Summary Cards */}
            <div className="commission-summary">
                <div className="summary-card">
                    <div className="summary-icon">💵</div>
                    <div className="summary-content">
                        <h3>{formatCurrency(commissionStats.totalCommission)}</h3>
                        <p>Total Commission</p>
                    </div>
                </div>
                <div className="summary-card">
                    <div className="summary-icon">📦</div>
                    <div className="summary-content">
                        <h3>{commissionStats.bookingCount}</h3>
                        <p>Completed Trips</p>
                    </div>
                </div>
                <div className="summary-card">
                    <div className="summary-icon">📊</div>
                    <div className="summary-content">
                        <h3>{formatCurrency(commissionStats.averageCommission)}</h3>
                        <p>Average Commission</p>
                    </div>
                </div>
                <div className="summary-card">
                    <div className="summary-icon">💰</div>
                    <div className="summary-content">
                        <h3>{formatCurrency(commissionStats.totalRevenue)}</h3>
                        <p>Total Revenue</p>
                    </div>
                </div>
            </div>

            {/* Filters */}
            <div className="filters">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search by load name, customer, or location..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>

                <div className="filter-controls">
                    <select
                        value={timeRange}
                        onChange={(e) => setTimeRange(e.target.value)}
                    >
                        <option value="7">Last 7 Days</option>
                        <option value="30">Last 30 Days</option>
                        <option value="90">Last 90 Days</option>
                        <option value="all">All Time</option>
                    </select>

                    <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                    >
                        <option value="commission">Sort by Commission</option>
                        <option value="fare">Sort by Fare</option>
                        <option value="timestamp">Sort by Date</option>
                        <option value="loadName">Sort by Load Name</option>
                    </select>

                    <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="sort-btn"
                    >
                        {sortOrder === 'asc' ? '↑' : '↓'}
                    </button>
                </div>
            </div>

            {/* Commission Table */}
            <div className="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Trip Details</th>
                            <th>Customer</th>
                            <th>Route</th>
                            <th>Fare</th>
                            <th>Commission</th>
                            <th>Driver Receives</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredBookings.length > 0 ? (
                            filteredBookings.map((booking) => {
                                const customer = getUserById(booking.customerId);
                                return (
                                    <tr key={booking.id}>
                                        <td>
                                            <div className="trip-details">
                                                <div className="load-name">{booking.loadName || 'N/A'}</div>
                                                <div className="load-type">{booking.loadType || 'N/A'}</div>
                                                <div className="vehicle-type">{booking.vehicleType || 'N/A'}</div>
                                            </div>
                                        </td>
                                        <td>
                                            <div className="customer-info">
                                                <div className="customer-name">{customer.name || 'N/A'}</div>
                                                <div className="customer-email">{customer.email || 'N/A'}</div>
                                            </div>
                                        </td>
                                        <td>
                                            <div className="route-info">
                                                <div className="route-from">📍 {booking.pickupLocation || 'N/A'}</div>
                                                <div className="route-to">📍 {booking.destinationLocation || 'N/A'}</div>
                                            </div>
                                        </td>
                                        <td className="fare-cell">{formatCurrency(booking.fare)}</td>
                                        <td className="commission-cell">
                                            <div className="commission-amount">{formatCurrency(booking.commission)}</div>
                                            <div className="commission-percentage">({booking.commissionPercentage.toFixed(1)}%)</div>
                                        </td>
                                        <td className="driver-cell">{formatCurrency(booking.driverReceives)}</td>
                                        <td>{formatDate(booking.timestamp)}</td>
                                    </tr>
                                );
                            })
                        ) : (
                            <tr>
                                <td colSpan="7" className="no-data">
                                    No commission data available for the selected filters
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>

            {/* Summary Footer */}
            <div className="summary-footer">
                <p>Showing {filteredBookings.length} of {commissionStats.bookingCount} completed trips</p>
            </div>
        </div>
    );
}

export default Commission;

