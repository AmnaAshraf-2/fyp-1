import { initializeApp } from "firebase/app";
import { getDatabase } from "firebase/database";

// 🔹 Copy your Firebase config from Firebase Console → Project Settings → SDK setup and configuration
const firebaseConfig = {
     apiKey: "AIzaSyDWpUIrQ4VwjiN9EE06zYPoQxg15Hvmbuc",
     authDomain: "fyp-1-2dbaf.firebaseapp.com",
     databaseURL: "https://fyp-1-2dbaf-default-rtdb.firebaseio.com",
     projectId: "fyp-1-2dbaf",
     storageBucket: "fyp-1-2dbaf.firebasestorage.app",
     messagingSenderId: "798522688381",
     appId: "1:798522688381:web:54e364753fbc170ef00214"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Export Realtime Database
export const database = getDatabase(app);
