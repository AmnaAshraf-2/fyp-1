import React, { useState, useEffect } from 'react';
import { ref, onValue, off, get } from 'firebase/database';
import { database } from './firebase';
import './Reports.css';

function Reports() {
    const [drivers, setDrivers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [sortBy, setSortBy] = useState('totalTrips');
    const [sortOrder, setSortOrder] = useState('desc');
    const [selectedDriver, setSelectedDriver] = useState(null);
    const [showDetailsModal, setShowDetailsModal] = useState(false);
    const [driverTrips, setDriverTrips] = useState([]);
    const [mostUsedVehicle, setMostUsedVehicle] = useState('N/A');
    const [mostUsedVehicleCount, setMostUsedVehicleCount] = useState(0);
    const [vehicleUsageStats, setVehicleUsageStats] = useState({});
    const [driverRatings, setDriverRatings] = useState({});
    const [driverFeedbacks, setDriverFeedbacks] = useState({});
    const [enterprises, setEnterprises] = useState([]);
    const [enterpriseRatings, setEnterpriseRatings] = useState({});
    const [enterpriseFeedbacks, setEnterpriseFeedbacks] = useState({});
    const [showEnterpriseSection, setShowEnterpriseSection] = useState(false);

    useEffect(() => {
        loadDriverReports();
    }, []);

    const loadDriverReports = async () => {
        try {
            setLoading(true);
            const usersRef = ref(database, 'users');
            const requestsRef = ref(database, 'requests');
            const driverHistoryRef = ref(database, 'driver_history');
            const customerHistoryRef = ref(database, 'customer_history');
            const driverRatingsRef = ref(database, 'driver_ratings');
            const enterpriseHistoryRef = ref(database, 'enterprise_history');
            const enterpriseRatingsRef = ref(database, 'enterprise_ratings');

            // Get all users, requests, history data, and ratings
            const [usersSnapshot, requestsSnapshot, driverHistorySnapshot, customerHistorySnapshot, ratingsSnapshot, enterpriseHistorySnapshot, enterpriseRatingsSnapshot] = await Promise.all([
                get(usersRef),
                get(requestsRef),
                get(driverHistoryRef),
                get(customerHistoryRef),
                get(driverRatingsRef),
                get(enterpriseHistoryRef),
                get(enterpriseRatingsRef)
            ]);

            const usersData = usersSnapshot.exists() ? usersSnapshot.val() : {};
            const requestsData = requestsSnapshot.exists() ? requestsSnapshot.val() : {};
            const driverHistoryData = driverHistorySnapshot.exists() ? driverHistorySnapshot.val() : {};
            const customerHistoryData = customerHistorySnapshot.exists() ? customerHistorySnapshot.val() : {};
            const ratingsData = ratingsSnapshot.exists() ? ratingsSnapshot.val() : {};

            // Process ratings data
            const ratingsByDriver = {};
            const feedbacksByDriver = {};
            
            Object.entries(ratingsData).forEach(([driverId, requestRatings]) => {
                if (!ratingsByDriver[driverId]) {
                    ratingsByDriver[driverId] = [];
                    feedbacksByDriver[driverId] = [];
                }
                
                Object.entries(requestRatings).forEach(([requestId, ratingData]) => {
                    if (ratingData.rating) {
                        ratingsByDriver[driverId].push(ratingData.rating);
                    }
                    if (ratingData.feedback && ratingData.feedback.trim()) {
                        feedbacksByDriver[driverId].push({
                            requestId,
                            feedback: ratingData.feedback,
                            rating: ratingData.rating,
                            timestamp: ratingData.timestamp,
                            customerId: ratingData.customerId
                        });
                    }
                });
            });
            
            setDriverRatings(ratingsByDriver);
            setDriverFeedbacks(feedbacksByDriver);

            // Process enterprise ratings data
            const enterpriseRatingsData = enterpriseRatingsSnapshot.exists() ? enterpriseRatingsSnapshot.val() : {};
            const enterpriseHistoryData = enterpriseHistorySnapshot.exists() ? enterpriseHistorySnapshot.val() : {};
            
            const ratingsByEnterprise = {};
            const feedbacksByEnterprise = {};
            
            Object.entries(enterpriseRatingsData).forEach(([enterpriseId, requestRatings]) => {
                if (!ratingsByEnterprise[enterpriseId]) {
                    ratingsByEnterprise[enterpriseId] = [];
                    feedbacksByEnterprise[enterpriseId] = [];
                }
                
                Object.entries(requestRatings).forEach(([requestId, ratingData]) => {
                    if (ratingData.rating) {
                        ratingsByEnterprise[enterpriseId].push(ratingData.rating);
                    }
                    if (ratingData.feedback && ratingData.feedback.trim()) {
                        feedbacksByEnterprise[enterpriseId].push({
                            requestId,
                            feedback: ratingData.feedback,
                            rating: ratingData.rating,
                            timestamp: ratingData.timestamp,
                            customerId: ratingData.customerId
                        });
                    }
                });
            });
            
            setEnterpriseRatings(ratingsByEnterprise);
            setEnterpriseFeedbacks(feedbacksByEnterprise);

            // Process enterprises
            const enterprisesList = Object.entries(usersData)
                .filter(([id, user]) => user.role === 'enterprise')
                .map(([id, user]) => {
                    // Count bookings from enterprise_history
                    const historyBookings = enterpriseHistoryData[id] || {};
                    const completedBookings = Object.keys(historyBookings).length;

                    // Count bookings from requests where enterprise is accepted
                    let acceptedBookings = 0;
                    let inProgressBookings = 0;
                    let dispatchedBookings = 0;
                    let totalAcceptedBookings = 0;

                    Object.entries(requestsData).forEach(([requestId, request]) => {
                        if (request.acceptedEnterpriseId === id) {
                            totalAcceptedBookings++;
                            if (request.status === 'accepted') {
                                acceptedBookings++;
                            } else if (request.status === 'dispatched') {
                                dispatchedBookings++;
                            } else if (request.status === 'in_progress') {
                                inProgressBookings++;
                            }
                        }
                    });

                    const totalBookings = completedBookings + totalAcceptedBookings;

                    // Calculate average rating
                    const ratings = ratingsByEnterprise[id] || [];
                    const averageRating = ratings.length > 0
                        ? (ratings.reduce((sum, r) => sum + r, 0) / ratings.length).toFixed(1)
                        : 'N/A';
                    const totalRatings = ratings.length;

                    const enterpriseDetails = user.enterpriseDetails || {};
                    
                    return {
                        id,
                        name: enterpriseDetails.enterpriseName || user.name || 'N/A',
                        email: user.email || 'N/A',
                        phone: enterpriseDetails.contactPhone || enterpriseDetails.cooperateNumber || user.phone || 'N/A',
                        totalBookings,
                        completedBookings,
                        acceptedBookings,
                        dispatchedBookings,
                        inProgressBookings,
                        createdAt: user.createdAt || null,
                        registrationNumber: enterpriseDetails.registrationNumber || 'N/A',
                        averageRating,
                        totalRatings
                    };
                });

            setEnterprises(enterprisesList);

            // Track vehicle type usage (using Set to avoid duplicates)
            const vehicleUsage = {};
            const processedTrips = new Set();

            // Count vehicle types from driver_history
            Object.entries(driverHistoryData).forEach(([driverId, trips]) => {
                Object.entries(trips).forEach(([tripId, trip]) => {
                    if (!processedTrips.has(tripId)) {
                        processedTrips.add(tripId);
                        const vehicleType = trip.vehicleType || 'Unknown';
                        vehicleUsage[vehicleType] = (vehicleUsage[vehicleType] || 0) + 1;
                    }
                });
            });

            // Count vehicle types from customer_history (only if not already counted)
            Object.entries(customerHistoryData).forEach(([customerId, trips]) => {
                Object.entries(trips).forEach(([tripId, trip]) => {
                    if (!processedTrips.has(tripId)) {
                        processedTrips.add(tripId);
                        const vehicleType = trip.vehicleType || 'Unknown';
                        vehicleUsage[vehicleType] = (vehicleUsage[vehicleType] || 0) + 1;
                    }
                });
            });

            // Count vehicle types from completed requests (only if not already in history)
            Object.entries(requestsData).forEach(([requestId, request]) => {
                if (request.status === 'completed' && request.vehicleType && !processedTrips.has(requestId)) {
                    processedTrips.add(requestId);
                    const vehicleType = request.vehicleType || 'Unknown';
                    vehicleUsage[vehicleType] = (vehicleUsage[vehicleType] || 0) + 1;
                }
            });

            // Find most used vehicle
            let mostUsedVehicle = 'N/A';
            let mostUsedCount = 0;
            Object.entries(vehicleUsage).forEach(([vehicleType, count]) => {
                if (count > mostUsedCount) {
                    mostUsedCount = count;
                    mostUsedVehicle = vehicleType;
                }
            });

            // Filter drivers only
            const driversList = Object.entries(usersData)
                .filter(([id, user]) => user.role === 'driver')
                .map(([id, user]) => {
                    // Count trips from driver_history
                    const historyTrips = driverHistoryData[id] || {};
                    const completedTrips = Object.keys(historyTrips).length;

                    // Count trips from requests where driver is accepted
                    let acceptedTrips = 0;
                    let inProgressTrips = 0;
                    let totalAcceptedTrips = 0;

                    Object.entries(requestsData).forEach(([requestId, request]) => {
                        if (request.acceptedDriverId === id) {
                            totalAcceptedTrips++;
                            if (request.status === 'accepted') {
                                acceptedTrips++;
                            } else if (request.status === 'in_progress') {
                                inProgressTrips++;
                            }
                        }
                    });

                    // Total trips = completed from history + all accepted/in_progress/completed from requests
                    const totalTrips = completedTrips + totalAcceptedTrips;

                    // Calculate average rating
                    const ratings = ratingsByDriver[id] || [];
                    const averageRating = ratings.length > 0
                        ? (ratings.reduce((sum, r) => sum + r, 0) / ratings.length).toFixed(1)
                        : 'N/A';
                    const totalRatings = ratings.length;

                    return {
                        id,
                        name: user.name || 'N/A',
                        email: user.email || 'N/A',
                        phone: user.phone || 'N/A',
                        totalTrips,
                        completedTrips,
                        acceptedTrips,
                        inProgressTrips,
                        createdAt: user.createdAt || null,
                        licenseNumber: user.driverDetails?.licenseNumber || 'N/A',
                        cnic: user.driverDetails?.cnic || 'N/A',
                        averageRating,
                        totalRatings
                    };
                });

            // Store vehicle stats in component state
            setDrivers(driversList);
            setMostUsedVehicle(mostUsedVehicle);
            setMostUsedVehicleCount(mostUsedCount);
            setVehicleUsageStats(vehicleUsage);
            setLoading(false);
        } catch (error) {
            console.error('Error loading driver reports:', error);
            setLoading(false);
        }
    };

    const loadDriverTripDetails = async (driverId) => {
        try {
            const driverHistoryRef = ref(database, `driver_history/${driverId}`);
            const requestsRef = ref(database, 'requests');
            const driverRatingsRef = ref(database, `driver_ratings/${driverId}`);

            const [historySnapshot, requestsSnapshot, ratingsSnapshot] = await Promise.all([
                get(driverHistoryRef),
                get(requestsRef),
                get(driverRatingsRef)
            ]);

            const historyData = historySnapshot.exists() ? historySnapshot.val() : {};
            const requestsData = requestsSnapshot.exists() ? requestsSnapshot.val() : {};
            const ratingsData = ratingsSnapshot.exists() ? ratingsSnapshot.val() : {};

            const trips = [];

            // Add trips from driver_history
            Object.entries(historyData).forEach(([requestId, trip]) => {
                const rating = ratingsData[requestId];
                trips.push({
                    requestId,
                    ...trip,
                    source: 'history',
                    status: 'completed',
                    rating: rating?.rating || null,
                    feedback: rating?.feedback || null,
                    ratingTimestamp: rating?.timestamp || null
                });
            });

            // Add active trips from requests
            Object.entries(requestsData).forEach(([requestId, request]) => {
                if (request.acceptedDriverId === driverId && 
                    (request.status === 'accepted' || request.status === 'in_progress')) {
                    trips.push({
                        requestId,
                        ...request,
                        source: 'active',
                        status: request.status
                    });
                }
            });

            // Sort by timestamp (newest first)
            trips.sort((a, b) => {
                const timestampA = a.timestamp || a.completedAt || 0;
                const timestampB = b.timestamp || b.completedAt || 0;
                return timestampB - timestampA;
            });

            setDriverTrips(trips);
        } catch (error) {
            console.error('Error loading driver trip details:', error);
        }
    };

    const handleViewDetails = (driver) => {
        setSelectedDriver(driver);
        setShowDetailsModal(true);
        loadDriverTripDetails(driver.id);
    };

    const handleViewEnterpriseDetails = (enterprise) => {
        setSelectedDriver(enterprise);
        setShowDetailsModal(true);
        loadEnterpriseDetails(enterprise.id);
    };

    const loadEnterpriseDetails = async (enterpriseId) => {
        try {
            const enterpriseHistoryRef = ref(database, `enterprise_history/${enterpriseId}`);
            const requestsRef = ref(database, 'requests');
            const enterpriseRatingsRef = ref(database, `enterprise_ratings/${enterpriseId}`);

            const [historySnapshot, requestsSnapshot, ratingsSnapshot] = await Promise.all([
                get(enterpriseHistoryRef),
                get(requestsRef),
                get(enterpriseRatingsRef)
            ]);

            const historyData = historySnapshot.exists() ? historySnapshot.val() : {};
            const requestsData = requestsSnapshot.exists() ? requestsSnapshot.val() : {};
            const ratingsData = ratingsSnapshot.exists() ? ratingsSnapshot.val() : {};

            const bookings = [];

            // Add bookings from enterprise_history
            Object.entries(historyData).forEach(([requestId, booking]) => {
                const rating = ratingsData[requestId];
                bookings.push({
                    requestId,
                    ...booking,
                    source: 'history',
                    status: 'completed',
                    rating: rating?.rating || null,
                    feedback: rating?.feedback || null,
                    ratingTimestamp: rating?.timestamp || null
                });
            });

            // Add active bookings from requests
            Object.entries(requestsData).forEach(([requestId, request]) => {
                if (request.acceptedEnterpriseId === enterpriseId && 
                    (request.status === 'accepted' || request.status === 'dispatched' || request.status === 'in_progress')) {
                    bookings.push({
                        requestId,
                        ...request,
                        source: 'active',
                        status: request.status
                    });
                }
            });

            // Sort by timestamp (newest first)
            bookings.sort((a, b) => {
                const timestampA = a.timestamp || a.completedAt || a.deliveredAt || 0;
                const timestampB = b.timestamp || b.completedAt || b.deliveredAt || 0;
                return timestampB - timestampA;
            });

            setDriverTrips(bookings);
        } catch (error) {
            console.error('Error loading enterprise details:', error);
        }
    };

    const filteredDrivers = drivers.filter(driver => {
        const searchLower = searchTerm.toLowerCase();
        return (
            driver.name.toLowerCase().includes(searchLower) ||
            driver.email.toLowerCase().includes(searchLower) ||
            driver.phone.toLowerCase().includes(searchLower) ||
            driver.licenseNumber.toLowerCase().includes(searchLower)
        );
    });

    const sortedDrivers = [...filteredDrivers].sort((a, b) => {
        let aValue = a[sortBy];
        let bValue = b[sortBy];

        if (typeof aValue === 'string') {
            aValue = aValue.toLowerCase();
            bValue = bValue.toLowerCase();
        }

        if (sortOrder === 'asc') {
            return aValue > bValue ? 1 : -1;
        } else {
            return aValue < bValue ? 1 : -1;
        }
    });

    const formatDate = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    };

    const formatTimestamp = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const handleSort = (field) => {
        if (sortBy === field) {
            setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
        } else {
            setSortBy(field);
            setSortOrder('desc');
        }
    };

    if (loading) {
        return (
            <div className="reports-container">
                <div className="loading">Loading driver reports...</div>
            </div>
        );
    }

    const filteredEnterprises = enterprises.filter(enterprise => {
        const searchLower = searchTerm.toLowerCase();
        return (
            enterprise.name.toLowerCase().includes(searchLower) ||
            enterprise.email.toLowerCase().includes(searchLower) ||
            enterprise.phone.toLowerCase().includes(searchLower) ||
            enterprise.registrationNumber.toLowerCase().includes(searchLower)
        );
    });

    const sortedEnterprises = [...filteredEnterprises].sort((a, b) => {
        let aValue = a[sortBy];
        let bValue = b[sortBy];

        if (typeof aValue === 'string') {
            aValue = aValue.toLowerCase();
            bValue = bValue.toLowerCase();
        }

        if (sortOrder === 'asc') {
            return aValue > bValue ? 1 : -1;
        } else {
            return aValue < bValue ? 1 : -1;
        }
    });

    return (
        <div className="reports-container">
            <div className="reports-header">
                <h1>📊 Reports</h1>
                <div style={{ display: 'flex', gap: '20px', marginTop: '10px' }}>
                    <button 
                        onClick={() => setShowEnterpriseSection(false)}
                        className={!showEnterpriseSection ? 'active-tab' : ''}
                        style={{ 
                            padding: '10px 20px', 
                            border: 'none', 
                            borderRadius: '5px',
                            backgroundColor: !showEnterpriseSection ? '#007D7D' : '#f0f0f0',
                            color: !showEnterpriseSection ? 'white' : '#333',
                            cursor: 'pointer'
                        }}
                    >
                        Driver Reports
                    </button>
                    <button 
                        onClick={() => setShowEnterpriseSection(true)}
                        className={showEnterpriseSection ? 'active-tab' : ''}
                        style={{ 
                            padding: '10px 20px', 
                            border: 'none', 
                            borderRadius: '5px',
                            backgroundColor: showEnterpriseSection ? '#007D7D' : '#f0f0f0',
                            color: showEnterpriseSection ? 'white' : '#333',
                            cursor: 'pointer'
                        }}
                    >
                        Enterprise Reports
                    </button>
                </div>
            </div>

            <div className="reports-controls">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder={showEnterpriseSection ? "Search by name, email, phone, or registration..." : "Search by name, email, phone, or license..."}
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="search-input"
                    />
                </div>
                <button onClick={loadDriverReports} className="refresh-btn">
                    🔄 Refresh
                </button>
            </div>

            {!showEnterpriseSection ? (
                <>
                    <div className="stats-summary">
                        <div className="stat-card">
                            <div className="stat-value">{drivers.length}</div>
                            <div className="stat-label">Total Drivers</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">
                                {drivers.reduce((sum, d) => sum + d.totalTrips, 0)}
                            </div>
                            <div className="stat-label">Total Trips</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">
                                {drivers.reduce((sum, d) => sum + d.completedTrips, 0)}
                            </div>
                            <div className="stat-label">Completed Trips</div>
                        </div>
                        <div className="stat-card">
                            <div className="stat-value">
                                {drivers.reduce((sum, d) => sum + d.inProgressTrips, 0)}
                            </div>
                            <div className="stat-label">Active Trips</div>
                        </div>
                        <div className="stat-card highlight">
                            <div className="stat-value">{mostUsedVehicleCount}</div>
                            <div className="stat-label">Most Used Vehicle</div>
                            <div className="stat-sub-label">{mostUsedVehicle}</div>
                        </div>
                    </div>
                </>
            ) : (
                <div className="stats-summary">
                    <div className="stat-card">
                        <div className="stat-value">{enterprises.length}</div>
                        <div className="stat-label">Total Enterprises</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value">
                            {enterprises.reduce((sum, e) => sum + e.totalBookings, 0)}
                        </div>
                        <div className="stat-label">Total Bookings</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value">
                            {enterprises.reduce((sum, e) => sum + e.completedBookings, 0)}
                        </div>
                        <div className="stat-label">Completed Bookings</div>
                    </div>
                    <div className="stat-card">
                        <div className="stat-value">
                            {enterprises.reduce((sum, e) => sum + e.dispatchedBookings + e.inProgressBookings, 0)}
                        </div>
                        <div className="stat-label">Active Bookings</div>
                    </div>
                </div>
            )}

            {/* Vehicle Usage Breakdown - Only show for drivers */}
            {!showEnterpriseSection && Object.keys(vehicleUsageStats).length > 0 && (
                <div className="vehicle-usage-section">
                    <h2>🚛 Vehicle Usage Statistics</h2>
                    <div className="vehicle-usage-grid">
                        {Object.entries(vehicleUsageStats)
                            .sort((a, b) => b[1] - a[1])
                            .map(([vehicleType, count]) => (
                                <div key={vehicleType} className="vehicle-stat-card">
                                    <div className="vehicle-name">{vehicleType}</div>
                                    <div className="vehicle-count">{count} trips</div>
                                </div>
                            ))}
                    </div>
                </div>
            )}

            <div className="reports-table-container">
                {!showEnterpriseSection ? (
                    <table className="reports-table">
                        <thead>
                            <tr>
                                <th onClick={() => handleSort('name')} className="sortable">
                                    Driver Name {sortBy === 'name' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th onClick={() => handleSort('email')} className="sortable">
                                    Email {sortBy === 'email' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>Phone</th>
                                <th onClick={() => handleSort('totalTrips')} className="sortable">
                                    Total Trips {sortBy === 'totalTrips' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th onClick={() => handleSort('completedTrips')} className="sortable">
                                    Completed {sortBy === 'completedTrips' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>Active</th>
                                <th onClick={() => handleSort('averageRating')} className="sortable">
                                    Avg Rating {sortBy === 'averageRating' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>License</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {sortedDrivers.length === 0 ? (
                                <tr>
                                    <td colSpan="9" className="no-data">
                                        No drivers found
                                    </td>
                                </tr>
                            ) : (
                                sortedDrivers.map((driver) => (
                                    <tr key={driver.id}>
                                        <td>{driver.name}</td>
                                        <td>{driver.email}</td>
                                        <td>{driver.phone}</td>
                                        <td className="trip-count">{driver.totalTrips}</td>
                                        <td className="trip-count completed">{driver.completedTrips}</td>
                                        <td className="trip-count active">
                                            {driver.inProgressTrips + driver.acceptedTrips}
                                        </td>
                                        <td>
                                            {driver.averageRating !== 'N/A' ? (
                                                <span className="rating-display">
                                                    <span className="rating-stars">
                                                        {'★'.repeat(Math.round(parseFloat(driver.averageRating)))}
                                                        {'☆'.repeat(5 - Math.round(parseFloat(driver.averageRating)))}
                                                    </span>
                                                    <span className="rating-value">{driver.averageRating}</span>
                                                    <span className="rating-count">({driver.totalRatings})</span>
                                                </span>
                                            ) : (
                                                <span className="no-rating">No ratings yet</span>
                                            )}
                                        </td>
                                        <td>{driver.licenseNumber}</td>
                                        <td>
                                            <button
                                                onClick={() => handleViewDetails(driver)}
                                                className="view-details-btn"
                                            >
                                                View Details
                                            </button>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                ) : (
                    <table className="reports-table">
                        <thead>
                            <tr>
                                <th onClick={() => handleSort('name')} className="sortable">
                                    Enterprise Name {sortBy === 'name' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th onClick={() => handleSort('email')} className="sortable">
                                    Email {sortBy === 'email' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>Phone</th>
                                <th onClick={() => handleSort('totalBookings')} className="sortable">
                                    Total Bookings {sortBy === 'totalBookings' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th onClick={() => handleSort('completedBookings')} className="sortable">
                                    Completed {sortBy === 'completedBookings' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>Active</th>
                                <th onClick={() => handleSort('averageRating')} className="sortable">
                                    Avg Rating {sortBy === 'averageRating' && (sortOrder === 'asc' ? '↑' : '↓')}
                                </th>
                                <th>Registration</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {sortedEnterprises.length === 0 ? (
                                <tr>
                                    <td colSpan="9" className="no-data">
                                        No enterprises found
                                    </td>
                                </tr>
                            ) : (
                                sortedEnterprises.map((enterprise) => (
                                    <tr key={enterprise.id}>
                                        <td>{enterprise.name}</td>
                                        <td>{enterprise.email}</td>
                                        <td>{enterprise.phone}</td>
                                        <td className="trip-count">{enterprise.totalBookings}</td>
                                        <td className="trip-count completed">{enterprise.completedBookings}</td>
                                        <td className="trip-count active">
                                            {enterprise.dispatchedBookings + enterprise.inProgressBookings + enterprise.acceptedBookings}
                                        </td>
                                        <td>
                                            {enterprise.averageRating !== 'N/A' ? (
                                                <span className="rating-display">
                                                    <span className="rating-stars">
                                                        {'★'.repeat(Math.round(parseFloat(enterprise.averageRating)))}
                                                        {'☆'.repeat(5 - Math.round(parseFloat(enterprise.averageRating)))}
                                                    </span>
                                                    <span className="rating-value">{enterprise.averageRating}</span>
                                                    <span className="rating-count">({enterprise.totalRatings})</span>
                                                </span>
                                            ) : (
                                                <span className="no-rating">No ratings yet</span>
                                            )}
                                        </td>
                                        <td>{enterprise.registrationNumber}</td>
                                        <td>
                                            <button
                                                onClick={() => handleViewEnterpriseDetails(enterprise)}
                                                className="view-details-btn"
                                            >
                                                View Details
                                            </button>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                )}
            </div>

            {showDetailsModal && selectedDriver && (
                <div className="modal-overlay" onClick={() => setShowDetailsModal(false)}>
                    <div className="modal-content" onClick={(e) => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>{showEnterpriseSection ? 'Enterprise' : 'Trip'} Details - {selectedDriver.name}</h2>
                            <button
                                className="close-modal"
                                onClick={() => setShowDetailsModal(false)}
                            >
                                ×
                            </button>
                        </div>
                        <div className="modal-body">
                            <div className="driver-info">
                                <p><strong>Email:</strong> {selectedDriver.email}</p>
                                <p><strong>Phone:</strong> {selectedDriver.phone}</p>
                                {!showEnterpriseSection ? (
                                    <>
                                        <p><strong>License:</strong> {selectedDriver.licenseNumber}</p>
                                        <p><strong>CNIC:</strong> {selectedDriver.cnic}</p>
                                        <p><strong>Total Trips:</strong> {selectedDriver.totalTrips}</p>
                                    </>
                                ) : (
                                    <>
                                        <p><strong>Registration:</strong> {selectedDriver.registrationNumber}</p>
                                        <p><strong>Total Bookings:</strong> {selectedDriver.totalBookings}</p>
                                    </>
                                )}
                                <p><strong>Average Rating:</strong> {
                                    selectedDriver.averageRating !== 'N/A' ? (
                                        <span>
                                            <span className="rating-stars">
                                                {'★'.repeat(Math.round(parseFloat(selectedDriver.averageRating)))}
                                                {'☆'.repeat(5 - Math.round(parseFloat(selectedDriver.averageRating)))}
                                            </span>
                                            {' '}{selectedDriver.averageRating} ({selectedDriver.totalRatings} {selectedDriver.totalRatings === 1 ? 'rating' : 'ratings'})
                                        </span>
                                    ) : 'No ratings yet'
                                }</p>
                            </div>
                            
                            {/* Ratings and Feedbacks Section */}
                            {!showEnterpriseSection && driverFeedbacks[selectedDriver.id] && driverFeedbacks[selectedDriver.id].length > 0 && (
                                <>
                                    <h3>⭐ Ratings & Feedbacks</h3>
                                    <div className="ratings-section">
                                        {driverFeedbacks[selectedDriver.id].map((feedback, index) => (
                                            <div key={index} className="feedback-item">
                                                <div className="feedback-header">
                                                    <span className="feedback-rating">
                                                        {'★'.repeat(feedback.rating)}
                                                        {'☆'.repeat(5 - feedback.rating)}
                                                    </span>
                                                    <span className="feedback-date">
                                                        {formatTimestamp(feedback.timestamp)}
                                                    </span>
                                                </div>
                                                <div className="feedback-text">
                                                    {feedback.feedback}
                                                </div>
                                                <div className="feedback-meta">
                                                    Request ID: {feedback.requestId}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </>
                            )}
                            
                            {showEnterpriseSection && enterpriseFeedbacks[selectedDriver.id] && enterpriseFeedbacks[selectedDriver.id].length > 0 && (
                                <>
                                    <h3>⭐ Ratings & Feedbacks</h3>
                                    <div className="ratings-section">
                                        {enterpriseFeedbacks[selectedDriver.id].map((feedback, index) => (
                                            <div key={index} className="feedback-item">
                                                <div className="feedback-header">
                                                    <span className="feedback-rating">
                                                        {'★'.repeat(feedback.rating)}
                                                        {'☆'.repeat(5 - feedback.rating)}
                                                    </span>
                                                    <span className="feedback-date">
                                                        {formatTimestamp(feedback.timestamp)}
                                                    </span>
                                                </div>
                                                <div className="feedback-text">
                                                    {feedback.feedback}
                                                </div>
                                                <div className="feedback-meta">
                                                    Request ID: {feedback.requestId}
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </>
                            )}
                            
                            <h3>{showEnterpriseSection ? 'Booking' : 'Trip'} History</h3>
                            {driverTrips.length === 0 ? (
                                <p className="no-trips">No {showEnterpriseSection ? 'bookings' : 'trips'} found</p>
                            ) : (
                                <div className="trips-list">
                                    {driverTrips.map((trip) => (
                                        <div key={trip.requestId} className="trip-item">
                                            <div className="trip-header">
                                                <span className="trip-load">{trip.loadName || 'N/A'}</span>
                                                <span className={`trip-status ${trip.status}`}>
                                                    {trip.status}
                                                </span>
                                            </div>
                                            <div className="trip-details">
                                                <p><strong>Load Type:</strong> {trip.loadType || 'N/A'}</p>
                                                <p><strong>Weight:</strong> {trip.weight} {trip.weightUnit || 'kg'}</p>
                                                <p><strong>Vehicle Type:</strong> {trip.vehicleType || 'N/A'}</p>
                                                <p><strong>Fare:</strong> Rs {trip.finalFare || trip.offerFare || 'N/A'}</p>
                                                {trip.pickupLocation && (
                                                    <p><strong>Pickup:</strong> {trip.pickupLocation}</p>
                                                )}
                                                {trip.destinationLocation && (
                                                    <p><strong>Destination:</strong> {trip.destinationLocation}</p>
                                                )}
                                                <p><strong>Date:</strong> {formatTimestamp(trip.timestamp || trip.completedAt || trip.deliveredAt)}</p>
                                                {trip.rating && (
                                                    <div className="trip-rating">
                                                        <strong>Rating:</strong> {'★'.repeat(trip.rating)}{'☆'.repeat(5 - trip.rating)} ({trip.rating}/5)
                                                        {trip.feedback && (
                                                            <div className="trip-feedback">
                                                                <strong>Feedback:</strong> {trip.feedback}
                                                            </div>
                                                        )}
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

export default Reports;

