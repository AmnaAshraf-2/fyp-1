import React, { useState, useEffect } from 'react';
import { ref, onValue, off, update, remove } from 'firebase/database';
import { database } from './firebase';
import './BookingManagement.css';

function BookingManagement() {
    const [bookings, setBookings] = useState([]);
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterStatus, setFilterStatus] = useState('all');
    const [sortBy, setSortBy] = useState('timestamp');
    const [sortOrder, setSortOrder] = useState('desc');
    const [selectedBooking, setSelectedBooking] = useState(null);
    const [showDetailsModal, setShowDetailsModal] = useState(false);

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

    const filteredBookings = bookings
        .filter(booking => {
            const user = getUserById(booking.customerId);
            const matchesSearch =
                booking.loadName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                booking.loadType?.toLowerCase().includes(searchTerm.toLowerCase());

            const matchesStatus = filterStatus === 'all' || booking.status === filterStatus;

            return matchesSearch && matchesStatus;
        })
        .sort((a, b) => {
            let aValue = a[sortBy] || '';
            let bValue = b[sortBy] || '';

            if (sortBy === 'timestamp') {
                aValue = a.timestamp || 0;
                bValue = b.timestamp || 0;
            }

            if (sortOrder === 'asc') {
                return aValue > bValue ? 1 : -1;
            } else {
                return aValue < bValue ? 1 : -1;
            }
        });

    const handleStatusChange = async (bookingId, newStatus) => {
        try {
            const bookingRef = ref(database, `requests/${bookingId}`);
            await update(bookingRef, { status: newStatus });
        } catch (error) {
            console.error('Error updating booking status:', error);
            alert('Error updating booking status. Please try again.');
        }
    };

    const handleDeleteBooking = async (bookingId) => {
        if (window.confirm('Are you sure you want to delete this booking?')) {
            try {
                const bookingRef = ref(database, `requests/${bookingId}`);
                await remove(bookingRef);
            } catch (error) {
                console.error('Error deleting booking:', error);
                alert('Error deleting booking. Please try again.');
            }
        }
    };

    const handleViewDetails = (booking) => {
        setSelectedBooking(booking);
        setShowDetailsModal(true);
    };

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

    const getStatusColor = (status) => {
        switch (status) {
            case 'pending': return '#f57c00';
            case 'accepted': return '#1976d2';
            case 'in_progress': return '#7b1fa2';
            case 'completed': return '#388e3c';
            case 'cancelled': return '#d32f2f';
            default: return '#666';
        }
    };

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading bookings...</p>
            </div>
        );
    }

    return (
        <div className="booking-management">
            <header className="page-header">
                <h1>Booking Management</h1>
                <p>Manage all booking requests and their status</p>
            </header>

            {/* Filters and Search */}
            <div className="filters">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search bookings by load name, customer, or type..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>

                <div className="filter-controls">
                    <select
                        value={filterStatus}
                        onChange={(e) => setFilterStatus(e.target.value)}
                    >
                        <option value="all">All Status</option>
                        <option value="pending">Pending</option>
                        <option value="accepted">Accepted</option>
                        <option value="in_progress">In Progress</option>
                        <option value="completed">Completed</option>
                        <option value="cancelled">Cancelled</option>
                    </select>

                    <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                    >
                        <option value="timestamp">Sort by Date</option>
                        <option value="loadName">Sort by Load Name</option>
                        <option value="offerFare">Sort by Fare</option>
                        <option value="status">Sort by Status</option>
                    </select>

                    <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="sort-btn"
                    >
                        {sortOrder === 'asc' ? '↑' : '↓'}
                    </button>
                </div>
            </div>

            {/* Bookings Table */}
            <div className="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Load Details</th>
                            <th>Customer</th>
                            <th>Weight</th>
                            <th>Fare</th>
                            <th>Status</th>
                            <th>Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredBookings.map((booking) => {
                            const customer = getUserById(booking.customerId);
                            return (
                                <tr key={booking.id}>
                                    <td>
                                        <div className="load-details">
                                            <div className="load-name">{booking.loadName || 'N/A'}</div>
                                            <div className="load-type">{booking.loadType || 'N/A'}</div>
                                            <div className="vehicle-type">{booking.vehicleType || 'N/A'}</div>
                                        </div>
                                    </td>
                                    <td>
                                        <div className="customer-info">
                                            <div className="customer-name">{customer.name || 'N/A'}</div>
                                            <div className="customer-email">{customer.email || 'N/A'}</div>
                                            <div className="customer-phone">{customer.phone || 'N/A'}</div>
                                        </div>
                                    </td>
                                    <td>
                                        {booking.weight ? `${booking.weight} ${booking.weightUnit || 'kg'}` : 'N/A'}
                                    </td>
                                    <td>
                                        {booking.offerFare ? formatCurrency(booking.offerFare) : 'N/A'}
                                    </td>
                                    <td>
                                        <select
                                            value={booking.status || 'pending'}
                                            onChange={(e) => handleStatusChange(booking.id, e.target.value)}
                                            className="status-select"
                                            style={{ color: getStatusColor(booking.status) }}
                                        >
                                            <option value="pending">Pending</option>
                                            <option value="accepted">Accepted</option>
                                            <option value="in_progress">In Progress</option>
                                            <option value="completed">Completed</option>
                                            <option value="cancelled">Cancelled</option>
                                        </select>
                                    </td>
                                    <td>{formatDate(booking.timestamp)}</td>
                                    <td>
                                        <div className="action-buttons">
                                            <button
                                                onClick={() => handleViewDetails(booking)}
                                                className="view-btn"
                                            >
                                                View
                                            </button>
                                            <button
                                                onClick={() => handleDeleteBooking(booking.id)}
                                                className="delete-btn"
                                            >
                                                Delete
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>

            {/* Details Modal */}
            {showDetailsModal && selectedBooking && (
                <div className="modal-overlay">
                    <div className="modal">
                        <h3>Booking Details</h3>
                        <div className="booking-details">
                            <div className="detail-section">
                                <h4>Load Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Load Name:</strong> {selectedBooking.loadName || 'N/A'}</div>
                                    <div><strong>Load Type:</strong> {selectedBooking.loadType || 'N/A'}</div>
                                    <div><strong>Vehicle Type:</strong> {selectedBooking.vehicleType || 'N/A'}</div>
                                    <div><strong>Weight:</strong> {selectedBooking.weight ? `${selectedBooking.weight} ${selectedBooking.weightUnit || 'kg'}` : 'N/A'}</div>
                                    <div><strong>Quantity:</strong> {selectedBooking.quantity || 'N/A'}</div>
                                    <div><strong>Insured:</strong> {selectedBooking.isInsured ? 'Yes' : 'No'}</div>
                                </div>
                            </div>

                            <div className="detail-section">
                                <h4>Customer Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Name:</strong> {getUserById(selectedBooking.customerId).name || 'N/A'}</div>
                                    <div><strong>Email:</strong> {getUserById(selectedBooking.customerId).email || 'N/A'}</div>
                                    <div><strong>Phone:</strong> {getUserById(selectedBooking.customerId).phone || 'N/A'}</div>
                                </div>
                            </div>

                            <div className="detail-section">
                                <h4>Booking Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Fare:</strong> {selectedBooking.offerFare ? formatCurrency(selectedBooking.offerFare) : 'N/A'}</div>
                                    <div><strong>Pickup Time:</strong> {selectedBooking.pickupTime || 'N/A'}</div>
                                    <div><strong>Status:</strong>
                                        <span style={{ color: getStatusColor(selectedBooking.status) }}>
                                            {selectedBooking.status || 'Pending'}
                                        </span>
                                    </div>
                                    <div><strong>Created:</strong> {formatDate(selectedBooking.timestamp)}</div>
                                </div>
                            </div>
                        </div>

                        <div className="modal-actions">
                            <button onClick={() => setShowDetailsModal(false)}>
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Summary */}
            <div className="summary">
                <p>Showing {filteredBookings.length} of {bookings.length} bookings</p>
            </div>
        </div>
    );
}

export default BookingManagement;
