import React, { useState, useEffect } from 'react';
import { ref, onValue, off, update, remove } from 'firebase/database';
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
                            <th>Driver Details</th>
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
                                        {driverDetails ? (
                                            <div className="driver-details">
                                                <div>License: {driverDetails.licenseNumber || 'N/A'}</div>
                                                <div>CNIC: {driverDetails.cnic || 'N/A'}</div>
                                                <div>Expiry: {driverDetails.licenseExpiry || 'N/A'}</div>
                                            </div>
                                        ) : (
                                            <span className="no-details">-</span>
                                        )}
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

            {/* Summary */}
            <div className="summary">
                <p>Showing {filteredUsers.length} of {users.length} users</p>
            </div>
        </div>
    );
}

export default UserManagement;
