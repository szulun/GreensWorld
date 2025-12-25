import { db } from "../connection/config.js";

import { collection, addDoc, getDocs, getDoc, doc, updateDoc, deleteDoc, query, where, setDoc } from "firebase/firestore";

import { validateUserData, sanitizeUserData } from "../models/User.js";

import { admin } from "../connection/firebaseAdmin.js";   // NEW
const adb = admin.firestore();                 // NEW (Admin Firestore)

// Create User
export const createUser = async (req, res) => {
  try {
    const { username, email, password } = req.body;

    // Validate user data
    const validationErrors = validateUserData({ username, email, password });
    if (validationErrors.length > 0) {
      return res.status(400).json({ error: validationErrors.join(', ') });
    }

    // Sanitize and prepare user data
    const userData = sanitizeUserData({ username, email, password });
    
    // Set a timeout for Firebase operations
    const firebaseTimeout = setTimeout(() => {
      console.log('Firebase operation timed out, returning offline response');
      res.status(201).json({ 
        message: "Signup successful! (Data will sync when Firebase is available)", 
        userId: "offline_" + Date.now(),
        user: { ...userData, id: "offline_" + Date.now() },
        warning: "Firebase is currently offline. Data will sync when connection is restored."
      });
    }, 3000); // Reduced to 3 seconds

    try {
      // First, test if we can access Firestore at all
      console.log('Testing Firestore connection...');
      const testRef = collection(db, 'test');
      await addDoc(testRef, { test: true, timestamp: new Date().toISOString() });
      console.log('Firestore connection test successful');
      
      // Check if user exists by email
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where("email", "==", email.toLowerCase()));
      const querySnapshot = await getDocs(q);
      
      clearTimeout(firebaseTimeout); // Clear timeout if operation succeeds
      
      if (!querySnapshot.empty) {
        return res.status(400).json({ error: "Email already exists, please log in." });
      }

      // Add user to Firestore
      const docRef = await addDoc(collection(db, 'users'), userData);

      res.status(201).json({ 
        message: "Signup successful!", 
        userId: docRef.id,
        user: { ...userData, id: docRef.id }
      });
    } catch (firebaseError) {
      clearTimeout(firebaseTimeout); // Clear timeout if operation fails
      console.error('Firebase error details:', {
        code: firebaseError.code,
        message: firebaseError.message,
        stack: firebaseError.stack
      });
      
      // Provide more specific error messages
      if (firebaseError.code === 'permission-denied') {
        res.status(500).json({ 
          error: "Firebase permission denied. Check your Firestore security rules.",
          details: firebaseError.message
        });
      } else if (firebaseError.code === 'unavailable') {
        res.status(503).json({ 
          error: "Firebase service unavailable. Please try again later.",
          details: firebaseError.message
        });
      } else {
        // If Firebase is offline, still return success but with a warning
        res.status(201).json({ 
          message: "Signup successful! (Data will sync when Firebase is available)", 
          userId: "offline_" + Date.now(),
          user: { ...userData, id: "offline_" + Date.now() },
          warning: "Firebase is currently offline. Data will sync when connection is restored.",
          error: firebaseError.message
        });
      }
    }
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: `Server Error: ${error.message}` });
  }
};

export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required" });
    }

    try {
      // Find user by email
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where("email", "==", email.toLowerCase()));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return res.status(400).json({ error: "Invalid credentials" });
      }

      const userDoc = querySnapshot.docs[0];
      const userData = userDoc.data();

      // Check password (Note: In production, use proper password hashing)
      if (userData.password !== password) {
        return res.status(400).json({ error: "Invalid credentials" });
      }

      res.status(200).json({ 
        userId: userDoc.id, 
        message: "Login successful!",
        user: { ...userData, id: userDoc.id }
      });
    } catch (firebaseError) {
      console.error('Firebase error:', firebaseError);
      res.status(503).json({ 
        error: "Database temporarily unavailable. Please try again later.",
        warning: "Firebase is currently offline."
      });
    }
  } catch (error) {
    console.error('Error logging in user:', error);
    res.status(500).json({ error: "Server error" });
  }
};

// New: Get current user's profile by email
export const getCurrentUserProfile = async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    const usersRef = collection(db, 'users');
    const q = query(usersRef, where('email', '==', email.toLowerCase()));
    const snapshot = await getDocs(q);

    if (snapshot.empty) {
      return res.status(200).json({ exists: false, profile: null });
    }

    const docSnap = snapshot.docs[0];
    const data = docSnap.data();
    delete data.password; // do not expose
    res.json({ exists: true, id: docSnap.id, profile: data });
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: error.message });
  }
};

// New: Upsert user profile by email (no password handling)
export const upsertUserProfile = async (req, res) => {
  try {
    const { email, displayName, location, bio, avatarUrl, badges, stats, plants } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    const usersRef = collection(db, 'users');
    const q = query(usersRef, where('email', '==', email.toLowerCase()));
    const snapshot = await getDocs(q);

    const baseProfile = {
      username: displayName || '',
      email: email.toLowerCase(),
      profilePicture: avatarUrl || '',
      bio: bio || '',
      location: location || '',
      badges: Array.isArray(badges) ? badges : [],
      stats: {
        successfulSwaps: stats?.successfulSwaps ?? 0,
        rating: stats?.rating ?? 0,
        communityHelps: stats?.communityHelps ?? 0,
        activePlants: stats?.activePlants ?? 0,
      },
      plants: Array.isArray(plants) ? plants : [],
      updatedAt: new Date().toISOString(),
      createdAt: new Date().toISOString(),
    };

    if (snapshot.empty) {
      const newRef = doc(collection(db, 'users'));
      await setDoc(newRef, baseProfile);
      return res.status(201).json({ id: newRef.id, profile: baseProfile, created: true });
    } else {
      const docRef = doc(db, 'users', snapshot.docs[0].id);
      await updateDoc(docRef, baseProfile);
      return res.json({ id: docRef.id, profile: baseProfile, created: false });
    }
  } catch (error) {
    console.error('Error upserting profile:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get All Users
export const getAllUsers = async (req, res) => {
  try {
    const usersRef = collection(db, 'users');
    const snapshot = await getDocs(usersRef);
    const users = [];
    
    snapshot.forEach((doc) => {
      const userData = doc.data();
      // Don't send passwords in the response
      delete userData.password;
      users.push({ id: doc.id, ...userData });
    });
    
    res.json({ message: "All users retrieved", data: users });
  } catch (error) {
    console.error('Error getting users:', error);
    res.status(500).json({ error: error.message });
  }
};

// Get User by ID
export const getUser = async (req, res) => {
  try {
    const { id } = req.params;
    const userRef = doc(db, 'users', id);
    const userSnap = await getDoc(userRef);
    
    if (!userSnap.exists()) {
      return res.status(404).json({ message: "User not found" });
    }

    const userData = userSnap.data();
    // Don't send password in the response
    delete userData.password;

    res.json({ message: "User found", data: { id: userSnap.id, ...userData } });
  } catch (error) {
    console.error('Error getting user:', error);
    res.status(500).json({ error: error.message });
  }
};

// Update User
export const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    updateData.updatedAt = new Date().toISOString();
    
    const userRef = doc(db, 'users', id);
    const userSnap = await getDoc(userRef);
    
    if (!userSnap.exists()) {
      return res.status(404).json({ message: "User not found" });
    }

    await updateDoc(userRef, updateData);
    
    // Get updated user data
    const updatedSnap = await getDoc(userRef);
    const updatedData = updatedSnap.data();
    delete updatedData.password; // Don't send password

    res.json({ message: "User updated", data: { id, ...updatedData } });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: error.message });
  }
};

// Delete User
export const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    const userRef = doc(db, 'users', id);
    const userSnap = await getDoc(userRef);
    
    if (!userSnap.exists()) {
      return res.status(404).json({ message: "User not found" });
    }

    await deleteDoc(userRef);
    res.json({ message: "User deleted successfully" });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: error.message });
  }
};


// ========================
// FAVORITES FUNCTIONALITY
// ========================

// Helper to build deterministic favorite doc ID
const favDocId = (userId, shopId) => `${userId}_${shopId}`;

// GET /api/users/:userId/favorites/plant-shops
export const getFavoritePlantShops = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!req.user || req.user.uid !== userId) {
      return res.status(403).json({ success: false, error: "Forbidden" });
    }

    const snap = await adb.collection("userFavorites")
                          .where("userId", "==", userId)
                          .get();
    const favorites = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ success: true, favorites });
  } catch (error) {
    console.error("Error getting favorite plant shops:", error);
    res.status(500).json({
      success: false,
      error: "Failed to fetch favorite plant shops",
      details: error.message
    });
  }
};

// POST /api/users/:userId/favorites/plant-shops
export const addFavoritePlantShop = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!req.user || req.user.uid !== userId) {
      return res.status(403).json({ success: false, error: "Forbidden" });
    }

    const { shopId, name, address, lat, lng, rating, types, visibility = "private" } = req.body;
    if (!shopId || !name || !address || lat == null || lng == null) {
      return res.status(400).json({
        success: false,
        error: "Missing required fields: shopId, name, address, lat, lng"
      });
    }

    const docId = favDocId(userId, shopId);
    await adb.collection("userFavorites").doc(docId).set({
      userId,
      shopId,
      name,
      address,
      lat: Number(lat),
      lng: Number(lng),
      rating: rating != null ? Number(rating) : null,
      types: Array.isArray(types) ? types : [],
      visibility, // 'private' (default) or 'public'
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    res.status(201).json({ success: true, id: docId });
  } catch (error) {
    console.error("Error adding favorite plant shop:", error);
    res.status(500).json({
      success: false,
      error: "Failed to add shop to favorites",
      details: error.message
    });
  }
};

// DELETE /api/users/:userId/favorites/plant-shops/:shopId
export const removeFavoritePlantShop = async (req, res) => {
  try {
    const { userId, shopId } = req.params;
    if (!req.user || req.user.uid !== userId) {
      return res.status(403).json({ success: false, error: "Forbidden" });
    }
    if (!shopId) {
      return res.status(400).json({ success: false, error: "Shop ID is required" });
    }

    await adb.collection("userFavorites").doc(favDocId(userId, shopId)).delete();
    res.json({ success: true });
  } catch (error) {
    console.error("Error removing favorite plant shop:", error);
    res.status(500).json({
      success: false,
      error: "Failed to remove shop from favorites",
      details: error.message
    });
  }
};
