import React, { useState, useEffect } from 'react';
import { ref, onValue, off, update, remove, get } from 'firebase/database';
import { database } from './firebase';
import './UserManagement.css';

function UserManagement() {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [filterRole, setFilterRole] = useState('all');
    const [sortBy, setSortBy] = useState('name');
    const [sortOrder, setSortOrder] = useState('asc');
    const [selectedUser, setSelectedUser] = useState(null);
    const [showEditModal, setShowEditModal] = useState(false);
    const [editForm, setEditForm] = useState({});
    const [showDetailsModal, setShowDetailsModal] = useState(false);
    const [viewingUser, setViewingUser] = useState(null);
    const [enterpriseData, setEnterpriseData] = useState({ drivers: [], vehicles: [], shareholders: [] });

    useEffect(() => {
        const usersRef = ref(database, 'users');

        const unsubscribe = onValue(usersRef, (snapshot) => {
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

        return () => off(usersRef, 'value', unsubscribe);
    }, []);

    const loadEnterpriseData = async (enterpriseId) => {
        try {
            console.log('Loading enterprise data for:', enterpriseId);
            
            const driversRef = ref(database, `users/${enterpriseId}/drivers`);
            const vehiclesRef = ref(database, `users/${enterpriseId}/vehicles`);
            const shareholdersRef = ref(database, `users/${enterpriseId}/shareholders`);
            const enterprisesDriversRef = ref(database, `enterprises/${enterpriseId}/drivers`);
            const enterprisesVehiclesRef = ref(database, `enterprises/${enterpriseId}/vehicles`);
            const userRef = ref(database, `users/${enterpriseId}`);

            const [driversSnapshot, vehiclesSnapshot, shareholdersSnapshot, enterprisesDriversSnapshot, enterprisesVehiclesSnapshot, userSnapshot] = await Promise.all([
                driversRef.get().then(snapshot => {
                    console.log('Drivers snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading drivers:', e);
                    return null;
                }),
                vehiclesRef.get().then(snapshot => {
                    console.log('Vehicles snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading vehicles:', e);
                    return null;
                }),
                shareholdersRef.get().then(snapshot => {
                    console.log('Shareholders snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading shareholders:', e);
                    return null;
                }),
                enterprisesDriversRef.get().then(snapshot => {
                    console.log('Enterprises drivers snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading enterprises drivers:', e);
                    return null;
                }),
                enterprisesVehiclesRef.get().then(snapshot => {
                    console.log('Enterprises vehicles snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading enterprises vehicles:', e);
                    return null;
                }),
                userRef.get().then(snapshot => {
                    console.log('User snapshot exists:', snapshot.exists());
                    return snapshot.exists() ? snapshot.val() : null;
                }).catch((e) => {
                    console.error('Error loading user:', e);
                    return null;
                })
            ]);

            const drivers = [];
            const vehicles = [];
            const shareholders = [];

            // Load drivers from users path
            if (driversSnapshot) {
                console.log('Processing drivers from users path:', Object.keys(driversSnapshot).length);
                Object.entries(driversSnapshot).forEach(([id, driver]) => {
                    drivers.push({ id, ...driver });
                });
            }

            // Load drivers from enterprises path
            if (enterprisesDriversSnapshot) {
                console.log('Processing drivers from enterprises path:', Object.keys(enterprisesDriversSnapshot).length);
                Object.entries(enterprisesDriversSnapshot).forEach(([id, driver]) => {
                    drivers.push({ id, ...driver });
                });
            }

            // Load vehicles from users path
            if (vehiclesSnapshot) {
                console.log('Processing vehicles from users path:', Object.keys(vehiclesSnapshot).length);
                Object.entries(vehiclesSnapshot).forEach(([id, vehicle]) => {
                    vehicles.push({ id, ...vehicle });
                });
            }

            // Load vehicles from enterprises path
            if (enterprisesVehiclesSnapshot) {
                console.log('Processing vehicles from enterprises path:', Object.keys(enterprisesVehiclesSnapshot).length);
                Object.entries(enterprisesVehiclesSnapshot).forEach(([id, vehicle]) => {
                    vehicles.push({ id, ...vehicle });
                });
            }

            // Load shareholders - check both separate path and user object
            if (shareholdersSnapshot) {
                console.log('Processing shareholders from separate path');
                if (Array.isArray(shareholdersSnapshot)) {
                    shareholdersSnapshot.forEach((shareholder, index) => {
                        shareholders.push({ id: index, ...shareholder });
                    });
                } else {
                    Object.entries(shareholdersSnapshot).forEach(([id, shareholder]) => {
                        shareholders.push({ id, ...shareholder });
                    });
                }
            }

            // Also check if shareholders are in the user object itself
            if (userSnapshot && userSnapshot.shareholders) {
                console.log('Processing shareholders from user object');
                const userShareholders = userSnapshot.shareholders;
                if (Array.isArray(userShareholders)) {
                    userShareholders.forEach((shareholder, index) => {
                        // Avoid duplicates
                        if (!shareholders.find(s => s.name === shareholder.name && s.cnic === shareholder.cnic)) {
                            shareholders.push({ id: index, ...shareholder });
                        }
                    });
                } else if (typeof userShareholders === 'object') {
                    Object.entries(userShareholders).forEach(([id, shareholder]) => {
                        // Avoid duplicates
                        if (!shareholders.find(s => s.name === shareholder.name && s.cnic === shareholder.cnic)) {
                            shareholders.push({ id, ...shareholder });
                        }
                    });
                }
            }

            console.log('Final counts - Drivers:', drivers.length, 'Vehicles:', vehicles.length, 'Shareholders:', shareholders.length);
            setEnterpriseData({ drivers, vehicles, shareholders });
        } catch (error) {
            console.error('Error loading enterprise data:', error);
            setEnterpriseData({ drivers: [], vehicles: [], shareholders: [] });
        }
    };

    const handleViewDetails = async (user) => {
        setViewingUser(user);
        setShowDetailsModal(true);
        
        // Load enterprise data if it's an enterprise user
        if (user.role === 'enterprise') {
            await loadEnterpriseData(user.id);
        }
    };

    const filteredUsers = users
        .filter(user => {
            const matchesSearch =
                user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                user.email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                user.phone?.includes(searchTerm);

            const matchesRole = filterRole === 'all' || user.role === filterRole || (!user.role && filterRole === 'customer');

            return matchesSearch && matchesRole;
        })
        .sort((a, b) => {
            let aValue = a[sortBy] || '';
            let bValue = b[sortBy] || '';

            if (sortBy === 'createdAt') {
                aValue = a.createdAt || 0;
                bValue = b.createdAt || 0;
            }

            if (sortOrder === 'asc') {
                return aValue > bValue ? 1 : -1;
            } else {
                return aValue < bValue ? 1 : -1;
            }
        });

    const handleEditUser = (user) => {
        setSelectedUser(user);
        setEditForm({
            name: user.name || '',
            email: user.email || '',
            phone: user.phone || '',
            role: user.role || 'customer'
        });
        setShowEditModal(true);
    };

    const handleSaveUser = async () => {
        try {
            const userRef = ref(database, `users/${selectedUser.id}`);
            await update(userRef, editForm);
            setShowEditModal(false);
            setSelectedUser(null);
            setEditForm({});
        } catch (error) {
            console.error('Error updating user:', error);
            alert('Error updating user. Please try again.');
        }
    };

    const handleDeleteUser = async (userId) => {
        if (window.confirm('Are you sure you want to delete this user?')) {
            try {
                const userRef = ref(database, `users/${userId}`);
                await remove(userRef);
            } catch (error) {
                console.error('Error deleting user:', error);
                alert('Error deleting user. Please try again.');
            }
        }
    };

    const formatDate = (timestamp) => {
        if (!timestamp) return 'N/A';
        const date = new Date(timestamp);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    };

    const getDriverDetails = (user) => {
        if (user.role !== 'driver' || !user.driverDetails) return null;
        return user.driverDetails;
    };

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading users...</p>
            </div>
        );
    }

    return (
        <div className="user-management">
            <header className="page-header">
                <h1>User Management</h1>
                <p>Manage all registered users in the system</p>
            </header>

            {/* Filters and Search */}
            <div className="filters">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search users by name, email, or phone..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>

                <div className="filter-controls">
                    <select
                        value={filterRole}
                        onChange={(e) => setFilterRole(e.target.value)}
                    >
                        <option value="all">All Roles</option>
                        <option value="customer">Customers</option>
                        <option value="driver">Drivers</option>
                        <option value="enterprise">Enterprises</option>
                    </select>

                    <select
                        value={sortBy}
                        onChange={(e) => setSortBy(e.target.value)}
                    >
                        <option value="name">Sort by Name</option>
                        <option value="email">Sort by Email</option>
                        <option value="createdAt">Sort by Join Date</option>
                    </select>

                    <button
                        onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
                        className="sort-btn"
                    >
                        {sortOrder === 'asc' ? '↑' : '↓'}
                    </button>
                </div>
            </div>

            {/* Users Table */}
            <div className="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>Role</th>
                            <th>Detail</th>
                            <th>Join Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredUsers.map((user) => {
                            const driverDetails = getDriverDetails(user);
                            return (
                                <tr key={user.id}>
                                    <td>
                                        <div className="user-info">
                                            <div className="user-avatar">
                                                {user.name ? user.name.charAt(0).toUpperCase() : '?'}
                                            </div>
                                            <span>{user.name || 'N/A'}</span>
                                        </div>
                                    </td>
                                    <td>{user.email || 'N/A'}</td>
                                    <td>{user.phone || 'N/A'}</td>
                                    <td>
                                        <span className={`role-badge ${user.role || 'customer'}`}>
                                            {user.role || 'Customer'}
                                        </span>
                                    </td>
                                    <td>
                                        <button
                                            onClick={() => handleViewDetails(user)}
                                            className="view-btn"
                                        >
                                            View
                                        </button>
                                    </td>
                                    <td>{formatDate(user.createdAt)}</td>
                                    <td>
                                        <div className="action-buttons">
                                            <button
                                                onClick={() => handleEditUser(user)}
                                                className="edit-btn"
                                            >
                                                Edit
                                            </button>
                                            <button
                                                onClick={() => handleDeleteUser(user.id)}
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

            {/* Edit Modal */}
            {showEditModal && (
                <div className="modal-overlay">
                    <div className="modal">
                        <h3>Edit User</h3>
                        <form onSubmit={(e) => { e.preventDefault(); handleSaveUser(); }}>
                            <div className="form-group">
                                <label>Name:</label>
                                <input
                                    type="text"
                                    value={editForm.name}
                                    onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Email:</label>
                                <input
                                    type="email"
                                    value={editForm.email}
                                    onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                                    required
                                />
                            </div>

                            <div className="form-group">
                                <label>Phone:</label>
                                <input
                                    type="tel"
                                    value={editForm.phone}
                                    onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })}
                                />
                            </div>

                            <div className="form-group">
                                <label>Role:</label>
                                <select
                                    value={editForm.role}
                                    onChange={(e) => setEditForm({ ...editForm, role: e.target.value })}
                                >
                                    <option value="customer">Customer</option>
                                    <option value="driver">Driver</option>
                                    <option value="enterprise">Enterprise</option>
                                </select>
                            </div>

                            <div className="modal-actions">
                                <button type="button" onClick={() => setShowEditModal(false)}>
                                    Cancel
                                </button>
                                <button type="submit" className="save-btn">
                                    Save Changes
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Details Modal */}
            {showDetailsModal && viewingUser && (
                <div className="modal-overlay">
                    <div className="modal" style={{ maxWidth: '800px', maxHeight: '90vh', overflowY: 'auto' }}>
                        <h3>{viewingUser.role === 'driver' ? 'Driver Details' : viewingUser.role === 'enterprise' ? 'Enterprise Details' : 'User Details'}</h3>
                        <div className="booking-details">
                            {/* Basic User Information */}
                            <div className="detail-section">
                                <h4>User Information</h4>
                                <div className="detail-grid">
                                    <div><strong>Name:</strong> {viewingUser.name || viewingUser.full_name || 'N/A'}</div>
                                    <div><strong>Email:</strong> {viewingUser.email || 'N/A'}</div>
                                    <div><strong>Phone:</strong> {viewingUser.phone || 'N/A'}</div>
                                    <div><strong>Role:</strong> {viewingUser.role || 'Customer'}</div>
                                    <div><strong>Join Date:</strong> {formatDate(viewingUser.createdAt)}</div>
                                </div>
                            </div>

                            {/* Driver Information */}
                            {viewingUser.role === 'driver' && (
                                <>
                                    <div className="detail-section">
                                        <h4>Driver Information</h4>
                                        <div className="detail-grid">
                                            <div><strong>CNIC:</strong> {viewingUser.driverDetails?.cnic || viewingUser.cnic || 'N/A'}</div>
                                            <div><strong>License Number:</strong> {viewingUser.driverDetails?.licenseNumber || viewingUser.licenseNumber || 'N/A'}</div>
                                            <div><strong>License Expiry:</strong> {viewingUser.driverDetails?.licenseExpiry || viewingUser.licenseExpiry || 'N/A'}</div>
                                            <div><strong>Experience:</strong> {viewingUser.driverDetails?.experienceYears || viewingUser.driverDetails?.experience || viewingUser.experienceYears || 'N/A'} years</div>
                                        </div>
                                    </div>

                                    {/* Vehicle Information for Driver */}
                                    {viewingUser.vehicleInfo && (
                                        <div className="detail-section">
                                            <h4>Vehicle Information</h4>
                                            <div className="detail-grid">
                                                <div><strong>Vehicle Name:</strong> {viewingUser.vehicleInfo.vehicleName || viewingUser.vehicleInfo.makeModel || 'N/A'}</div>
                                                <div><strong>Vehicle Type:</strong> {viewingUser.vehicleInfo.vehicleType || viewingUser.vehicleInfo.type || 'N/A'}</div>
                                                <div><strong>Registration Number:</strong> {viewingUser.vehicleInfo.registrationNumber || viewingUser.vehicleInfo.vehicleNumber || 'N/A'}</div>
                                                <div><strong>Color:</strong> {viewingUser.vehicleInfo.color || 'N/A'}</div>
                                                <div><strong>Capacity:</strong> {viewingUser.vehicleInfo.capacity || 'N/A'}</div>
                                            </div>
                                        </div>
                                    )}
                                </>
                            )}

                            {/* Enterprise Information */}
                            {viewingUser.role === 'enterprise' && (
                                <>
                                    <div className="detail-section">
                                        <h4>Enterprise Information</h4>
                                        <div className="detail-grid">
                                            <div><strong>Company Name:</strong> {viewingUser.companyName || viewingUser.enterpriseDetails?.companyName || 'N/A'}</div>
                                            <div><strong>Registration Number:</strong> {viewingUser.enterpriseDetails?.registrationNumber || viewingUser.registrationNumber || 'N/A'}</div>
                                            <div><strong>Address:</strong> {viewingUser.enterpriseDetails?.address || viewingUser.address || 'N/A'}</div>
                                            <div><strong>Business Type:</strong> {viewingUser.enterpriseDetails?.businessType || viewingUser.businessType || 'N/A'}</div>
                                        </div>
                                    </div>

                                    {/* Enterprise Drivers */}
                                    <div className="detail-section">
                                        <h4>Registered Drivers ({enterpriseData.drivers.length})</h4>
                                        {enterpriseData.drivers.length > 0 ? (
                                            <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                                {enterpriseData.drivers.map((driver, index) => (
                                                    <div key={driver.id || index} style={{ marginBottom: '15px', padding: '10px', border: '1px solid #ddd', borderRadius: '5px' }}>
                                                        <div className="detail-grid">
                                                            <div><strong>Name:</strong> {driver.name || driver.driverName || 'N/A'}</div>
                                                            <div><strong>Phone:</strong> {driver.phone || driver.driverPhone || 'N/A'}</div>
                                                            <div><strong>CNIC:</strong> {driver.cnic || driver.driverCnic || 'N/A'}</div>
                                                            <div><strong>License Number:</strong> {driver.licenseNumber || 'N/A'}</div>
                                                            <div><strong>Experience:</strong> {driver.experienceYears || driver.experience || 'N/A'} years</div>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <p style={{ color: '#666', fontStyle: 'italic' }}>No drivers registered</p>
                                        )}
                                    </div>

                                    {/* Enterprise Vehicles */}
                                    <div className="detail-section">
                                        <h4>Registered Vehicles ({enterpriseData.vehicles.length})</h4>
                                        {enterpriseData.vehicles.length > 0 ? (
                                            <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                                {enterpriseData.vehicles.map((vehicle, index) => (
                                                    <div key={vehicle.id || index} style={{ marginBottom: '15px', padding: '10px', border: '1px solid #ddd', borderRadius: '5px' }}>
                                                        <div className="detail-grid">
                                                            <div><strong>Vehicle Name:</strong> {vehicle.vehicleName || vehicle.makeModel || 'N/A'}</div>
                                                            <div><strong>Vehicle Type:</strong> {vehicle.vehicleType || vehicle.type || 'N/A'}</div>
                                                            <div><strong>Registration Number:</strong> {vehicle.vehicleNumber || vehicle.registrationNumber || 'N/A'}</div>
                                                            <div><strong>Color:</strong> {vehicle.color || 'N/A'}</div>
                                                            <div><strong>Capacity:</strong> {vehicle.capacity || 'N/A'}</div>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <p style={{ color: '#666', fontStyle: 'italic' }}>No vehicles registered</p>
                                        )}
                                    </div>

                                    {/* Enterprise Shareholders */}
                                    <div className="detail-section">
                                        <h4>Shareholders ({enterpriseData.shareholders.length})</h4>
                                        {enterpriseData.shareholders.length > 0 ? (
                                            <div style={{ maxHeight: '300px', overflowY: 'auto' }}>
                                                {enterpriseData.shareholders.map((shareholder, index) => (
                                                    <div key={shareholder.id || index} style={{ marginBottom: '15px', padding: '10px', border: '1px solid #ddd', borderRadius: '5px' }}>
                                                        <div className="detail-grid">
                                                            <div><strong>Name:</strong> {shareholder.name || shareholder.shareholderName || 'N/A'}</div>
                                                            <div><strong>CNIC:</strong> {shareholder.cnic || shareholder.shareholderCnic || 'N/A'}</div>
                                                            <div><strong>Phone:</strong> {shareholder.phone || shareholder.shareholderPhone || 'N/A'}</div>
                                                            <div><strong>Share Percentage:</strong> {shareholder.sharePercentage || shareholder.percentage || 'N/A'}%</div>
                                                            {shareholder.designation && (
                                                                <div><strong>Designation:</strong> {shareholder.designation || 'N/A'}</div>
                                                            )}
                                                            {shareholder.address && (
                                                                <div><strong>Address:</strong> {shareholder.address || 'N/A'}</div>
                                                            )}
                                                            {shareholder.email && (
                                                                <div><strong>Email:</strong> {shareholder.email || shareholder.shareholderEmail || 'N/A'}</div>
                                                            )}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <p style={{ color: '#666', fontStyle: 'italic' }}>No shareholders registered</p>
                                        )}
                                    </div>
                                </>
                            )}
                        </div>

                        <div className="modal-actions">
                            <button onClick={() => {
                                setShowDetailsModal(false);
                                setViewingUser(null);
                                setEnterpriseData({ drivers: [], vehicles: [], shareholders: [] });
                            }}>
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Summary */}
            <div className="summary">
                <p>Showing {filteredUsers.length} of {users.length} users</p>
            </div>
        </div>
    );
}

export default UserManagement;
