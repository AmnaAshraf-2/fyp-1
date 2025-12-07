import React, { useState } from 'react';
import { createUserWithEmailAndPassword, signInWithPopup, GoogleAuthProvider } from 'firebase/auth';
import { ref, set, get } from 'firebase/database';
import { auth, database } from './firebase';
import './Login.css'; // Reusing Login.css for consistent styling

function Register({ onRegisterSuccess }) {
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        password: '',
        confirmPassword: ''
    });
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);

    const handleChange = (e) => {
        setFormData({
            ...formData,
            [e.target.name]: e.target.value
        });
        setError('');
    };

    const validateForm = () => {
        if (!formData.name.trim()) {
            setError('Name is required.');
            return false;
        }
        if (!formData.email.trim()) {
            setError('Email is required.');
            return false;
        }
        if (formData.password.length < 6) {
            setError('Password must be at least 6 characters.');
            return false;
        }
        if (formData.password !== formData.confirmPassword) {
            setError('Passwords do not match.');
            return false;
        }
        return true;
    };

    const handleEmailRegister = async (e) => {
        e.preventDefault();
        setError('');

        if (!validateForm()) {
            return;
        }

        setLoading(true);

        try {
            // Create user with Firebase Auth
            const userCredential = await createUserWithEmailAndPassword(
                auth,
                formData.email,
                formData.password
            );
            const user = userCredential.user;

            // Check if user already exists in database
            const userRef = ref(database, `users/${user.uid}`);
            const snapshot = await get(userRef);

            if (!snapshot.exists()) {
                // Create admin user in database
                const userData = {
                    id: user.uid,
                    name: formData.name.trim(),
                    email: formData.email.trim(),
                    role: 'admin',
                    createdAt: new Date().toISOString(),
                    profileImage: ''
                };

                await set(userRef, userData);
                onRegisterSuccess(user, userData);
            } else {
                // User exists, just sign them in
                const existingData = snapshot.val();
                if (existingData.role === 'admin') {
                    onRegisterSuccess(user, existingData);
                } else {
                    await auth.signOut();
                    setError('An account with this email already exists with a different role.');
                }
            }
        } catch (error) {
            let errorMessage = 'Registration failed. Please try again.';
            switch (error.code) {
                case 'auth/email-already-in-use':
                    errorMessage = 'An account with this email already exists.';
                    break;
                case 'auth/invalid-email':
                    errorMessage = 'Invalid email format.';
                    break;
                case 'auth/weak-password':
                    errorMessage = 'Password is too weak.';
                    break;
                case 'auth/operation-not-allowed':
                    errorMessage = 'Email/password accounts are not enabled.';
                    break;
                default:
                    errorMessage = error.message || 'Registration failed. Please try again.';
            }
            setError(errorMessage);
        } finally {
            setLoading(false);
        }
    };

    const handleGoogleRegister = async () => {
        setError('');
        setLoading(true);

        try {
            const provider = new GoogleAuthProvider();
            const userCredential = await signInWithPopup(auth, provider);
            const user = userCredential.user;

            // Check if user already exists in database
            const userRef = ref(database, `users/${user.uid}`);
            const snapshot = await get(userRef);

            if (!snapshot.exists()) {
                // Create admin user in database
                const userData = {
                    id: user.uid,
                    name: user.displayName || 'Admin User',
                    email: user.email || '',
                    role: 'admin',
                    createdAt: new Date().toISOString(),
                    profileImage: user.photoURL || ''
                };

                await set(userRef, userData);
                onRegisterSuccess(user, userData);
            } else {
                // User exists, check role
                const existingData = snapshot.val();
                if (existingData.role === 'admin') {
                    onRegisterSuccess(user, existingData);
                } else {
                    await auth.signOut();
                    setError('An account with this email already exists with a different role.');
                }
            }
        } catch (error) {
            let errorMessage = 'Google registration failed. Please try again.';
            if (error.code === 'auth/popup-closed-by-user') {
                errorMessage = 'Registration cancelled.';
            } else if (error.message) {
                errorMessage = error.message;
            }
            setError(errorMessage);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="auth-container">
            <div className="auth-card">
                <div className="auth-header">
                    <h1>Create Admin Account</h1>
                    <p>Register to access the admin panel</p>
                </div>

                {error && (
                    <div className="error-message">
                        {error}
                    </div>
                )}

                <form onSubmit={handleEmailRegister} className="auth-form">
                    <div className="form-group">
                        <label htmlFor="name">Full Name</label>
                        <input
                            type="text"
                            id="name"
                            name="name"
                            value={formData.name}
                            onChange={handleChange}
                            placeholder="Enter your full name"
                            required
                            disabled={loading}
                        />
                    </div>

                    <div className="form-group">
                        <label htmlFor="email">Email</label>
                        <input
                            type="email"
                            id="email"
                            name="email"
                            value={formData.email}
                            onChange={handleChange}
                            placeholder="admin@example.com"
                            required
                            disabled={loading}
                        />
                    </div>

                    <div className="form-group">
                        <label htmlFor="password">Password</label>
                        <div className="password-input-wrapper">
                            <input
                                type={showPassword ? 'text' : 'password'}
                                id="password"
                                name="password"
                                value={formData.password}
                                onChange={handleChange}
                                placeholder="Minimum 6 characters"
                                required
                                disabled={loading}
                            />
                            <button
                                type="button"
                                className="password-toggle"
                                onClick={() => setShowPassword(!showPassword)}
                                disabled={loading}
                            >
                                {showPassword ? '👁️' : '👁️‍🗨️'}
                            </button>
                        </div>
                    </div>

                    <div className="form-group">
                        <label htmlFor="confirmPassword">Confirm Password</label>
                        <div className="password-input-wrapper">
                            <input
                                type={showConfirmPassword ? 'text' : 'password'}
                                id="confirmPassword"
                                name="confirmPassword"
                                value={formData.confirmPassword}
                                onChange={handleChange}
                                placeholder="Re-enter your password"
                                required
                                disabled={loading}
                            />
                            <button
                                type="button"
                                className="password-toggle"
                                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                                disabled={loading}
                            >
                                {showConfirmPassword ? '👁️' : '👁️‍🗨️'}
                            </button>
                        </div>
                    </div>

                    <button
                        type="submit"
                        className="auth-button primary"
                        disabled={loading}
                    >
                        {loading ? 'Creating account...' : 'Create Account'}
                    </button>
                </form>

                <div className="auth-divider">
                    <span>OR</span>
                </div>

                <button
                    onClick={handleGoogleRegister}
                    className="auth-button google"
                    disabled={loading}
                >
                    <svg width="20" height="20" viewBox="0 0 24 24">
                        <path
                            fill="#4285F4"
                            d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                        />
                        <path
                            fill="#34A853"
                            d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                        />
                        <path
                            fill="#FBBC05"
                            d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                        />
                        <path
                            fill="#EA4335"
                            d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                        />
                    </svg>
                    Continue with Google
                </button>

                <div className="auth-footer">
                    <p>
                        Already have an account?{' '}
                        <a href="#login" onClick={(e) => {
                            e.preventDefault();
                            window.location.hash = 'login';
                        }}>
                            Sign in here
                        </a>
                    </p>
                </div>
            </div>
        </div>
    );
}

export default Register;

