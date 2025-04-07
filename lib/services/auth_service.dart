import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during sign in';
    }
  }
  
  // Register with email and password
  Future<UserCredential?> register(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      
      // Create user document in Firestore
      await _createUserDocument(userCredential.user!, displayName);
      
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during registration';
    }
  }
  
  // Create user document in Firestore
  Future<void> _createUserDocument(User user, String displayName) async {
    UserModel userModel = UserModel(
      uid: user.uid,
      email: user.email!,
      displayName: displayName,
      photoUrl: user.photoURL,
    );
    
    await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}

