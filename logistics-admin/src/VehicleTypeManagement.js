import React, { useState, useEffect } from 'react';
import { ref, onValue, off, set, remove, update } from 'firebase/database';
import { database } from './firebase';
import './VehicleTypeManagement.css';

function VehicleTypeManagement() {
    const [vehicleTypes, setVehicleTypes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showAddModal, setShowAddModal] = useState(false);
    const [showEditModal, setShowEditModal] = useState(false);
    const [selectedVehicleType, setSelectedVehicleType] = useState(null);
    const [searchTerm, setSearchTerm] = useState('');

    // Form state
    const [formData, setFormData] = useState({
        nameKey: '',
        capacityKey: '',
        name: {
            en: '',
            ur: '',
            ps: ''
        },
        capacity: {
            en: '',
            ur: '',
            ps: ''
        },
        isDisabled: false
    });

    useEffect(() => {
        const vehicleTypesRef = ref(database, 'vehicle_types');
        
        const unsubscribe = onValue(vehicleTypesRef, (snapshot) => {
            if (snapshot.exists()) {
                const data = snapshot.val();
                const typesList = Object.entries(data).map(([key, value]) => ({
                    id: key,
                    ...value
                }));
                // Sort by nameKey
                typesList.sort((a, b) => (a.nameKey || '').localeCompare(b.nameKey || ''));
                setVehicleTypes(typesList);
            } else {
                setVehicleTypes([]);
            }
            setLoading(false);
        });

        return () => {
            off(vehicleTypesRef, 'value', unsubscribe);
        };
    }, []);

    const handleInputChange = (e) => {
        const { name, value } = e.target;
        if (name.startsWith('name.')) {
            const lang = name.split('.')[1];
            setFormData(prev => ({
                ...prev,
                name: {
                    ...prev.name,
                    [lang]: value
                }
            }));
        } else if (name.startsWith('capacity.')) {
            const lang = name.split('.')[1];
            setFormData(prev => ({
                ...prev,
                capacity: {
                    ...prev.capacity,
                    [lang]: value
                }
            }));
        } else {
            setFormData(prev => ({
                ...prev,
                [name]: value
            }));
        }
    };

    const handleCheckboxChange = (e) => {
        const { name, checked } = e.target;
        setFormData(prev => ({
            ...prev,
            [name]: checked
        }));
    };

    const resetForm = () => {
        setFormData({
            nameKey: '',
            capacityKey: '',
            name: {
                en: '',
                ur: '',
                ps: ''
            },
            capacity: {
                en: '',
                ur: '',
                ps: ''
            },
            isDisabled: false
        });
    };

    const handleAdd = () => {
        resetForm();
        setShowAddModal(true);
    };

    const handleEdit = (vehicleType) => {
        setFormData({
            nameKey: vehicleType.nameKey || '',
            capacityKey: vehicleType.capacityKey || '',
            name: vehicleType.name || { en: '', ur: '', ps: '' },
            capacity: vehicleType.capacity || { en: '', ur: '', ps: '' },
            isDisabled: vehicleType.isDisabled || false
        });
        setSelectedVehicleType(vehicleType);
        setShowEditModal(true);
    };

    const handleSave = async (e) => {
        e.preventDefault();
        
        if (!formData.nameKey || !formData.capacityKey) {
            alert('Please fill in nameKey and capacityKey');
            return;
        }

        if (!formData.name.en || !formData.capacity.en) {
            alert('Please fill in at least English name and capacity');
            return;
        }

        try {
            const vehicleTypeData = {
                nameKey: formData.nameKey,
                capacityKey: formData.capacityKey,
                name: formData.name,
                capacity: formData.capacity,
                isDisabled: formData.isDisabled || false,
                updatedAt: Date.now()
            };

            if (showAddModal) {
                // Add new vehicle type
                const key = `${formData.nameKey}_${formData.capacityKey}`;
                const vehicleTypeRef = ref(database, `vehicle_types/${key}`);
                await set(vehicleTypeRef, {
                    ...vehicleTypeData,
                    createdAt: Date.now()
                });
                alert('Vehicle type added successfully!');
            } else {
                // Update existing vehicle type
                const vehicleTypeRef = ref(database, `vehicle_types/${selectedVehicleType.id}`);
                await update(vehicleTypeRef, vehicleTypeData);
                alert('Vehicle type updated successfully!');
            }

            setShowAddModal(false);
            setShowEditModal(false);
            resetForm();
        } catch (error) {
            console.error('Error saving vehicle type:', error);
            alert('Error saving vehicle type: ' + error.message);
        }
    };

    const handleDelete = async (vehicleType) => {
        if (!window.confirm(`Are you sure you want to delete "${vehicleType.name?.en || vehicleType.nameKey}"? This action cannot be undone.`)) {
            return;
        }

        try {
            const vehicleTypeRef = ref(database, `vehicle_types/${vehicleType.id}`);
            await remove(vehicleTypeRef);
            alert('Vehicle type deleted successfully!');
        } catch (error) {
            console.error('Error deleting vehicle type:', error);
            alert('Error deleting vehicle type: ' + error.message);
        }
    };

    const handleToggleDisable = async (vehicleType) => {
        try {
            const vehicleTypeRef = ref(database, `vehicle_types/${vehicleType.id}`);
            const newDisabledState = !(vehicleType.isDisabled || false);
            await update(vehicleTypeRef, {
                isDisabled: newDisabledState,
                updatedAt: Date.now()
            });
        } catch (error) {
            console.error('Error toggling vehicle type status:', error);
            alert('Error updating vehicle type: ' + error.message);
        }
    };

    const filteredVehicleTypes = vehicleTypes.filter(vt => {
        const searchLower = searchTerm.toLowerCase();
        return (
            (vt.nameKey || '').toLowerCase().includes(searchLower) ||
            (vt.name?.en || '').toLowerCase().includes(searchLower) ||
            (vt.name?.ur || '').toLowerCase().includes(searchLower) ||
            (vt.name?.ps || '').toLowerCase().includes(searchLower) ||
            (vt.capacityKey || '').toLowerCase().includes(searchLower)
        );
    });

    if (loading) {
        return (
            <div className="loading">
                <div className="spinner"></div>
                <p>Loading vehicle types...</p>
            </div>
        );
    }

    return (
        <div className="vehicle-type-management">
            <header className="page-header">
                <h1>Vehicle Type Management</h1>
                <p>Manage vehicle types available in the system</p>
            </header>

            {/* Statistics */}
            <div className="vehicle-type-stats">
                <div className="stat-item">
                    <div className="stat-value">{vehicleTypes.length}</div>
                    <div className="stat-label">Total Types</div>
                </div>
                <div className="stat-item">
                    <div className="stat-value">{vehicleTypes.filter(vt => !vt.isDisabled).length}</div>
                    <div className="stat-label">Active Types</div>
                </div>
                <div className="stat-item">
                    <div className="stat-value">{vehicleTypes.filter(vt => vt.isDisabled).length}</div>
                    <div className="stat-label">Disabled Types</div>
                </div>
            </div>

            {/* Actions Bar */}
            <div className="actions-bar">
                <div className="search-box">
                    <input
                        type="text"
                        placeholder="Search vehicle types..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="search-input"
                    />
                </div>
                <button className="btn btn-primary" onClick={handleAdd}>
                    <span>+</span> Add Vehicle Type
                </button>
            </div>

            {/* Vehicle Types Table */}
            <div className="vehicle-types-table-container">
                <table className="vehicle-types-table">
                    <thead>
                        <tr>
                            <th>Name Key</th>
                            <th>English Name</th>
                            <th>Urdu Name</th>
                            <th>Pashto Name</th>
                            <th>Capacity (EN)</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredVehicleTypes.length === 0 ? (
                            <tr>
                                <td colSpan="7" className="no-data">
                                    {searchTerm ? 'No vehicle types found matching your search.' : 'No vehicle types found. Add your first vehicle type!'}
                                </td>
                            </tr>
                        ) : (
                            filteredVehicleTypes.map((vehicleType) => (
                                <tr key={vehicleType.id} className={vehicleType.isDisabled ? 'disabled' : ''}>
                                    <td>{vehicleType.nameKey}</td>
                                    <td>{vehicleType.name?.en || 'N/A'}</td>
                                    <td>{vehicleType.name?.ur || 'N/A'}</td>
                                    <td>{vehicleType.name?.ps || 'N/A'}</td>
                                    <td>{vehicleType.capacity?.en || 'N/A'}</td>
                                    <td>
                                        <span className={`status-badge ${vehicleType.isDisabled ? 'disabled' : 'active'}`}>
                                            {vehicleType.isDisabled ? 'Disabled' : 'Active'}
                                        </span>
                                    </td>
                                    <td>
                                        <div className="action-buttons">
                                            <button
                                                className="btn btn-small btn-edit"
                                                onClick={() => handleEdit(vehicleType)}
                                                title="Edit"
                                            >
                                                ✏️
                                            </button>
                                            <button
                                                className="btn btn-small btn-toggle"
                                                onClick={() => handleToggleDisable(vehicleType)}
                                                title={vehicleType.isDisabled ? 'Enable' : 'Disable'}
                                            >
                                                {vehicleType.isDisabled ? '✅' : '🚫'}
                                            </button>
                                            <button
                                                className="btn btn-small btn-delete"
                                                onClick={() => handleDelete(vehicleType)}
                                                title="Delete"
                                            >
                                                🗑️
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>

            {/* Add Modal */}
            {showAddModal && (
                <div className="modal-overlay" onClick={() => setShowAddModal(false)}>
                    <div className="modal-content" onClick={(e) => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Add Vehicle Type</h2>
                            <button className="modal-close" onClick={() => setShowAddModal(false)}>×</button>
                        </div>
                        <form onSubmit={handleSave}>
                            <div className="form-group">
                                <label>Name Key *</label>
                                <input
                                    type="text"
                                    name="nameKey"
                                    value={formData.nameKey}
                                    onChange={handleInputChange}
                                    required
                                    placeholder="e.g., pickupCarry"
                                />
                            </div>
                            <div className="form-group">
                                <label>Capacity Key *</label>
                                <input
                                    type="text"
                                    name="capacityKey"
                                    value={formData.capacityKey}
                                    onChange={handleInputChange}
                                    required
                                    placeholder="e.g., pickupCarryCapacity"
                                />
                            </div>
                            
                            <div className="form-section">
                                <h3>Names (Multilingual)</h3>
                                <div className="form-group">
                                    <label>English Name *</label>
                                    <input
                                        type="text"
                                        name="name.en"
                                        value={formData.name.en}
                                        onChange={handleInputChange}
                                        required
                                        placeholder="e.g., Pickup Carry"
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Urdu Name</label>
                                    <input
                                        type="text"
                                        name="name.ur"
                                        value={formData.name.ur}
                                        onChange={handleInputChange}
                                        placeholder="e.g., پک اپ کیری"
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Pashto Name</label>
                                    <input
                                        type="text"
                                        name="name.ps"
                                        value={formData.name.ps}
                                        onChange={handleInputChange}
                                        placeholder="e.g., پک اپ کیری"
                                    />
                                </div>
                            </div>

                            <div className="form-section">
                                <h3>Capacities (Multilingual)</h3>
                                <div className="form-group">
                                    <label>English Capacity *</label>
                                    <input
                                        type="text"
                                        name="capacity.en"
                                        value={formData.capacity.en}
                                        onChange={handleInputChange}
                                        required
                                        placeholder="e.g., Up to 800kg"
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Urdu Capacity</label>
                                    <input
                                        type="text"
                                        name="capacity.ur"
                                        value={formData.capacity.ur}
                                        onChange={handleInputChange}
                                        placeholder="e.g., 800 کلوگرام تک"
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Pashto Capacity</label>
                                    <input
                                        type="text"
                                        name="capacity.ps"
                                        value={formData.capacity.ps}
                                        onChange={handleInputChange}
                                        placeholder="e.g., تر 800 کیلوګرامه"
                                    />
                                </div>
                            </div>

                            <div className="form-group">
                                <label className="checkbox-label">
                                    <input
                                        type="checkbox"
                                        name="isDisabled"
                                        checked={formData.isDisabled}
                                        onChange={handleCheckboxChange}
                                    />
                                    Disabled (Hide from users)
                                </label>
                            </div>

                            <div className="modal-actions">
                                <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)}>
                                    Cancel
                                </button>
                                <button type="submit" className="btn btn-primary">
                                    Add Vehicle Type
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Edit Modal */}
            {showEditModal && (
                <div className="modal-overlay" onClick={() => setShowEditModal(false)}>
                    <div className="modal-content" onClick={(e) => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Edit Vehicle Type</h2>
                            <button className="modal-close" onClick={() => setShowEditModal(false)}>×</button>
                        </div>
                        <form onSubmit={handleSave}>
                            <div className="form-group">
                                <label>Name Key *</label>
                                <input
                                    type="text"
                                    name="nameKey"
                                    value={formData.nameKey}
                                    onChange={handleInputChange}
                                    required
                                    disabled
                                />
                            </div>
                            <div className="form-group">
                                <label>Capacity Key *</label>
                                <input
                                    type="text"
                                    name="capacityKey"
                                    value={formData.capacityKey}
                                    onChange={handleInputChange}
                                    required
                                    disabled
                                />
                            </div>
                            
                            <div className="form-section">
                                <h3>Names (Multilingual)</h3>
                                <div className="form-group">
                                    <label>English Name *</label>
                                    <input
                                        type="text"
                                        name="name.en"
                                        value={formData.name.en}
                                        onChange={handleInputChange}
                                        required
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Urdu Name</label>
                                    <input
                                        type="text"
                                        name="name.ur"
                                        value={formData.name.ur}
                                        onChange={handleInputChange}
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Pashto Name</label>
                                    <input
                                        type="text"
                                        name="name.ps"
                                        value={formData.name.ps}
                                        onChange={handleInputChange}
                                    />
                                </div>
                            </div>

                            <div className="form-section">
                                <h3>Capacities (Multilingual)</h3>
                                <div className="form-group">
                                    <label>English Capacity *</label>
                                    <input
                                        type="text"
                                        name="capacity.en"
                                        value={formData.capacity.en}
                                        onChange={handleInputChange}
                                        required
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Urdu Capacity</label>
                                    <input
                                        type="text"
                                        name="capacity.ur"
                                        value={formData.capacity.ur}
                                        onChange={handleInputChange}
                                    />
                                </div>
                                <div className="form-group">
                                    <label>Pashto Capacity</label>
                                    <input
                                        type="text"
                                        name="capacity.ps"
                                        value={formData.capacity.ps}
                                        onChange={handleInputChange}
                                    />
                                </div>
                            </div>

                            <div className="form-group">
                                <label className="checkbox-label">
                                    <input
                                        type="checkbox"
                                        name="isDisabled"
                                        checked={formData.isDisabled}
                                        onChange={handleCheckboxChange}
                                    />
                                    Disabled (Hide from users)
                                </label>
                            </div>

                            <div className="modal-actions">
                                <button type="button" className="btn btn-secondary" onClick={() => setShowEditModal(false)}>
                                    Cancel
                                </button>
                                <button type="submit" className="btn btn-primary">
                                    Update Vehicle Type
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

export default VehicleTypeManagement;

