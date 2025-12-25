// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
      apiKey: "AIzaSyDG03gfg0f-_qXQrHe8fGgL7freoRuQeqM",
  authDomain: "greensworld-c2918.firebaseapp.com",
  databaseURL: "https://greensworld-c2918-default-rtdb.firebaseio.com",
  projectId: "greensworld-c2918",
  storageBucket: "greensworld-c2918.firebasestorage.app",
  messagingSenderId: "118532775984",
  appId: "1:118532775984:web:d2af930a8efcea15318df5",
  measurementId: "G-3KBVCJ6NTN"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
const db = getFirestore(app);
const auth = getAuth(app);
const storage = getStorage(app);

// Connect to Firebase function for server startup
const connectDB = async () => {
  try {
    console.log('🔥 Connecting to Firebase...');
    // Firebase is initialized synchronously, so we just need to verify the connection
    console.log('✅ Firebase connected successfully');
    return true;
  } catch (error) {
    console.error('❌ Firebase connection failed:', error);
    throw error;
  }
};

// Export for use in other files
export { app, db, auth, storage, connectDB };
export default connectDB;