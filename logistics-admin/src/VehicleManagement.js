import React, { useState, useEffect } from 'react';
import { ref, onValue, off, get } from 'firebase/database';
import { database } from './firebase';
import './VehicleManagement.css';

function VehicleManagement() {
    const [vehicles, setVehicles] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterType, setFilterType] = useState('all');
    const [filterOwnerType, setFilterOwnerType] = useState('all');
    const [sortBy, setSortBy] = useState('ownerName');
    const [sortOrder, setSortOrder] = useState('asc');
    const [selectedVehicle, setSelectedVehicle] = useState(null);
    const [showDetailsModal, setShowDetailsModal] = useState(false);

    useEffect(() => {
        const usersRef = ref(database, 'users');
        const enterprisesRef = ref(database, 'enterprises');

        const loadVehicles = async () => {
            try {
                // Get all users
                const usersSnapshot = await get(usersRef);
                const usersData = usersSnapshot.val() || {};
                
                const vehiclesList = [];

                // Process each user
                Object.entries(usersData).forEach(([userId, user]) => {
                    // Driver vehicles (single vehicle in vehicleInfo)
                    if (user.role === 'driver' && user.vehicleInfo) {
                        vehiclesList.push({
                            id: `${userId}_driver`,
                            vehicleId: userId,
                            ownerId: userId,
                            ownerName: user.name || 'N/A',
                            ownerEmail: user.email || 'N/A',
                            ownerPhone: user.phone || 'N/A',
                            ownerType: 'driver',
                            ownerRole: 'driver',
                            makeModel: user.vehicleInfo.makeModel || user.vehicleInfo.vehicleName || 'N/A',
                            type: user.vehicleInfo.type || user.vehicleInfo.vehicleType || 'N/A',
                            color: user.vehicleInfo.color || 'N/A',
                            engineNumber: user.vehicleInfo.engineNumber || 'N/A',
                            chassisNumber: user.vehicleInfo.chassisNumber || 'N/A',
                            registrationNumber: user.vehicleInfo.registrationNumber || user.vehicleInfo.vehicleNumber || 'N/A',
                            registrationExpiry: user.vehicleInfo.registrationExpiry || 'N/A',
                            trackingDeviceId: user.vehicleInfo.trackingDeviceId || 'N/A',
                            insuranceCopy: user.vehicleInfo.insuranceCopy || '',
                            fitnessCopy: user.vehicleInfo.fitnessCopy || '',
                            capacity: user.vehicleInfo.capacity || 'N/A',
                            driverLicense: user.driverDetails?.licenseNumber || 'N/A',
                            driverCNIC: user.driverDetails?.cnic || 'N/A',
                            addedAt: user.vehicleInfo.addedAt || user.createdAt || null
                        });
                    }

                    // Enterprise vehicles (multiple vehicles in vehicles array)
                    if (user.role === 'enterprise' && user.vehicles) {
                        const enterpriseVehicles = user.vehicles;
                        if (typeof enterpriseVehicles === 'object') {
                            Object.entries(enterpriseVehicles).forEach(([vehicleId, vehicle]) => {
                                vehiclesList.push({
                                    id: `${userId}_${vehicleId}`,
                                    vehicleId: vehicleId,
                                    ownerId: userId,
                                    ownerName: user.name || user.companyName || 'N/A',
                                    ownerEmail: user.email || 'N/A',
                                    ownerPhone: user.phone || 'N/A',
                                    ownerType: 'enterprise',
                                    ownerRole: 'enterprise',
                                    makeModel: vehicle.makeModel || vehicle.vehicleName || 'N/A',
                                    type: vehicle.type || vehicle.vehicleType || 'N/A',
                                    color: vehicle.color || 'N/A',
                                    engineNumber: vehicle.engineNumber || 'N/A',
                                    chassisNumber: vehicle.chassisNumber || 'N/A',
                                    registrationNumber: vehicle.registrationNumber || vehicle.vehicleNumber || 'N/A',
                                    registrationExpiry: vehicle.registrationExpiry || 'N/A',
                                    trackingDeviceId: vehicle.trackingDeviceId || 'N/A',
                                    insuranceCopy: vehicle.insuranceCopy || '',
                                    fitnessCopy: vehicle.fitnessCopy || '',
                                    capacity: vehicle.capacity || 'N/A',
                                    addedAt: vehicle.addedAt || user.createdAt || null
                                });
                            });
                        }
                    }
                });

                // Also check enterprises path
                try {
                    const enterprisesSnapshot = await get(enterprisesRef);
                    const enterprisesData = enterprisesSnapshot.val() || {};
                    
                    Object.entries(enterprisesData).forEach(([enterpriseId, enterprise]) => {
                        if (enterprise.vehicles) {
                            const enterpriseVehicles = enterprise.vehicles;
                            if (typeof enterpriseVehicles === 'object') {
                                Object.entries(enterpriseVehicles).forEach(([vehicleId, vehicle]) => {
                                    // Check if vehicle already added from users path
                                    const existingIndex = vehiclesList.findIndex(
                                        v => v.id === `${enterpriseId}_${vehicleId}`
                                    );
                                    
                                    if (existingIndex === -1) {
                                        vehiclesList.push({
                                            id: `${enterpriseId}_${vehicleId}`,
                                            vehicleId: vehicleId,
                                            ownerId: enterpriseId,
                                            ownerName: enterprise.name || enterprise.companyName || 'N/A',
                                            ownerEmail: enterprise.email || 'N/A',
                                            ownerPhone: enterprise.phone || 'N/A',
                                            ownerType: 'enterprise',
                                            ownerRole: 'enterprise',
                                            makeModel: vehicle.makeModel || vehicle.vehicleName || 'N/A',
                                            type: vehicle.type || vehicle.vehicleType || 'N/A',
                                            color: vehicle.color || 'N/A',
                                            engineNumber: vehicle.engineNumber || 'N/A',
                                            chassisNumber: vehicle.chassisNumber || 'N/A',
                                            registrationNumber: vehicle.registrationNumber || vehicle.vehicleNumber || 'N/A',
                                            registrationExpiry: vehicle.registrationExpiry || 'N/A',
                                            trackingDeviceId: vehicle.trackingDeviceId || 'N/A',
                                            insuranceCopy: vehicle.insuranceCopy || '',
                                            fitnessCopy: vehicle.fitnessCopy || '',
                                            capacity: vehicle.capacity || 'N/A',
                                            addedAt: vehicle.addedAt || enterprise.createdAt || null
                                        });
                                    }
                                });
                            }
                        }
                    });
                } catch (error) {
                    console.log('No enterprises path found or error loading:', error);
                }

                setVehicles(vehiclesList);
                setLoading(false);
            } catch (error) {
                console.error('Error loading vehicles:', error);
                setLoading(false);
            }
        };

        // Initial load
        loadVehicles();

        // Listen for real-time updates
        const unsubscribeUsers = onValue(usersRef, () => {
            loadVehicles();
        });

        return () => {
            off(usersRef, 'value', unsubscribeUsers);
        };
    }, []);

    const filteredVehicles = vehicles
        .filter(vehicle => {
            const matchesSearch =
                vehicle.makeModel?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                vehicle.registrationNumber?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                vehicle.ownerName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                vehicle.ownerEmail?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                vehicle.ownerPhone?.includes(searchTerm);

            const matchesType = filterType === 'all' || vehicle.type?.toLowerCase() === filterType.toLowerCase();
            const matchesOwnerType = filterOwnerType === 'all' || vehicle.ownerType === filterOwnerType;

            return matchesSearch && matchesType && matchesOwnerType;
        })
        .sort((a, b) => {
            let aValue = a[sortBy] || '';
            let bValue = b[sortBy] || '';

            if (sortBy === 'addedAt') {
                aValue = a.addedAt || 0;
                bValue = b.addedAt || 0;
            }

            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
            }
            if (typeof bValue === 'string') {
                bValue = bValue.toLowerCase();
            }

            if (sortOrder === 'asc') {
                return aValue > bValue ? 1 : -1;
            } else {
                return aValue < bValue ? 1 : -1;
            }
        });

    const handleViewDetails = (vehicle) => {
        setSelectedVehicle(vehicle);
        setShowDetailsModal(true);
    };

    const formatDate = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    };

    // Get unique vehicle types for filter
    const vehicleTypes = [...new Set(vehicles.map(v => v.type).filter(Boolean))];

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading vehicles...</p>
            </div>
        );
    }

    return (
        <div className="vehicle-management">
            <header className="page-header">
                <h1>Vehicle Management</h1>
                <p>View all registered vehicles with owner details</p>
            </header>

            {/* Statistics Summary */}
            <div className="vehicle-stats">
                <div className="stat-item">
                    <div className="stat-value">{vehicles.length}</div>
                    <div className="stat-label">Total Vehicles</div>
                </div>
                <div className="stat-item">
                    <div className="stat-value">{vehicles.filter(v => v.ownerType === 'driver').length}</div>
                    <div className="stat-label">Driver Vehicles</div>
                </div>
                <div className="stat-item">
                    <div className="stat-value">{vehicles.filter(v => v.ownerType === 'enterprise').length}</div>
                    <div className="stat-label">Enterprise Vehicles</div>
                </div>
            </div>

            {/* Filters and Search */}
            <div className="filters">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search by vehicle, registration, owner name, email, or phone..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>

                <div className="filter-controls">
                    <select
                        value={filterOwnerType}
                        onChange={(e) => setFilterOwnerType(e.target.value)}
                    >
                        <option value="all">All Owners</option>
                        <option value="driver">Drivers</option>
                        <option value="enterprise">Enterprises</option>
                    </select>

                    <select
                        value={filterType}
                        onChange={(e) => setFilterType(e.target.value)}
                    >
                        <option value="all">All Types</option>
                        {vehicleTypes.map(type => (
                            <option key={type} value={type}>{type}</option>
                        ))}
                    </select>

                    <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                    >
                        <option value="ownerName">Sort by Owner</option>
                        <option value="makeModel">Sort by Vehicle</option>
                        <option value="type">Sort by Type</option>
                        <option value="registrationNumber">Sort by Registration</option>
                        <option value="addedAt">Sort by Date Added</option>
                    </select>

                    <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="sort-btn"
                    >
                        {sortOrder === 'asc' ? '↑' : '↓'}
                    </button>
                </div>
            </div>

            {/* Vehicles Table */}
            <div className="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Vehicle</th>
                            <th>Type</th>
                            <th>Registration</th>
                            <th>Owner Name</th>
                            <th>Owner Type</th>
                            <th>Owner Contact</th>
                            <th>Details</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredVehicles.length === 0 ? (
                            <tr>
                                <td colSpan="7" style={{ textAlign: 'center', padding: '40px' }}>
                                    <p style={{ color: '#666', fontSize: '1.1rem' }}>No vehicles found</p>
                                </td>
                            </tr>
                        ) : (
                            filteredVehicles.map((vehicle) => (
                                <tr key={vehicle.id}>
                                    <td>
                                        <div className="vehicle-info">
                                            <div className="vehicle-icon">🚛</div>
                                            <span>{vehicle.makeModel}</span>
                                        </div>
                                    </td>
                                    <td>
                                        <span className="type-badge">{vehicle.type}</span>
                                    </td>
                                    <td>{vehicle.registrationNumber}</td>
                                    <td>
                                        <div className="owner-info">
                                            <div className="owner-avatar">
                                                {vehicle.ownerName.charAt(0).toUpperCase()}
                                            </div>
                                            <span>{vehicle.ownerName}</span>
                                        </div>
                                    </td>
                                    <td>
                                        <span className={`owner-type-badge ${vehicle.ownerType}`}>
                                            {vehicle.ownerType === 'driver' ? 'Driver' : 'Enterprise'}
                                        </span>
                                    </td>
                                    <td>
                                        <div className="contact-info">
                                            <div>{vehicle.ownerEmail}</div>
                                            <div style={{ fontSize: '0.9rem', color: '#666' }}>{vehicle.ownerPhone}</div>
                                        </div>
                                    </td>
                                    <td>
                                        <button
                                            onClick={() => handleViewDetails(vehicle)}
                                            className="view-btn"
                                        >
                                            View Details
                                        </button>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Details Modal */}
            {showDetailsModal && selectedVehicle && (
                <div className="modal-overlay">
                    <div className="modal" style={{ maxWidth: '800px', maxHeight: '90vh', overflowY: 'auto' }}>
                        <h3>Vehicle Details</h3>
                        <div className="booking-details">
                            {/* Vehicle Information */}
                            <div className="detail-section">
                                <h4>Vehicle Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Make/Model:</strong> {selectedVehicle.makeModel}</div>
                                    <div><strong>Type:</strong> {selectedVehicle.type}</div>
                                    <div><strong>Color:</strong> {selectedVehicle.color}</div>
                                    <div><strong>Registration Number:</strong> {selectedVehicle.registrationNumber}</div>
                                    <div><strong>Registration Expiry:</strong> {selectedVehicle.registrationExpiry}</div>
                                    <div><strong>Engine Number:</strong> {selectedVehicle.engineNumber}</div>
                                    <div><strong>Chassis Number:</strong> {selectedVehicle.chassisNumber}</div>
                                    <div><strong>Tracking Device ID:</strong> {selectedVehicle.trackingDeviceId}</div>
                                    {selectedVehicle.capacity && (
                                        <div><strong>Capacity:</strong> {selectedVehicle.capacity}</div>
                                    )}
                                    <div><strong>Date Added:</strong> {formatDate(selectedVehicle.addedAt)}</div>
                                </div>
                            </div>

                            {/* Owner Information */}
                            <div className="detail-section">
                                <h4>Owner Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Name:</strong> {selectedVehicle.ownerName}</div>
                                    <div><strong>Type:</strong> {selectedVehicle.ownerType === 'driver' ? 'Driver' : 'Enterprise'}</div>
                                    <div><strong>Email:</strong> {selectedVehicle.ownerEmail}</div>
                                    <div><strong>Phone:</strong> {selectedVehicle.ownerPhone}</div>
                                    {selectedVehicle.driverLicense && (
                                        <div><strong>Driver License:</strong> {selectedVehicle.driverLicense}</div>
                                    )}
                                    {selectedVehicle.driverCNIC && (
                                        <div><strong>Driver CNIC:</strong> {selectedVehicle.driverCNIC}</div>
                                    )}
                                </div>
                            </div>

                            {/* Documents */}
                            {(selectedVehicle.insuranceCopy || selectedVehicle.fitnessCopy) && (
                                <div className="detail-section">
                                    <h4>Documents</h4>
                                    <div className="detail-grid">
                                        {selectedVehicle.insuranceCopy && (
                                            <div>
                                                <strong>Insurance Copy:</strong>
                                                <a href={selectedVehicle.insuranceCopy} target="_blank" rel="noopener noreferrer" style={{ marginLeft: '10px', color: '#006A6A' }}>
                                                    View Document
                                                </a>
                                            </div>
                                        )}
                                        {selectedVehicle.fitnessCopy && (
                                            <div>
                                                <strong>Fitness Copy:</strong>
                                                <a href={selectedVehicle.fitnessCopy} target="_blank" rel="noopener noreferrer" style={{ marginLeft: '10px', color: '#006A6A' }}>
                                                    View Document
                                                </a>
                                            </div>
                                        )}
                                    </div>
                                </div>
                            )}
                        </div>

                        <div className="modal-actions">
                            <button onClick={() => {
                                setShowDetailsModal(false);
                                setSelectedVehicle(null);
                            }}>
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Summary */}
            <div className="summary">
                <p>Showing {filteredVehicles.length} of {vehicles.length} vehicles</p>
            </div>
        </div>
    );
}

export default VehicleManagement;































