// lib/data/remote/firebase_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth Getters ──────────────────────────────────────────────────────────
  User? get _user => _auth.currentUser;
  bool get isSignedIn => _user != null;
  String? get currentUserId => _user?.uid;
  String? get displayName =>
      _user?.displayName ?? _user?.email?.split('@')[0] ?? 'User';
  String? get email => _user?.email;
  bool get hasExistingSession => _auth.currentUser != null;

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (e) {
      return 'Something went wrong. Try again.';
    }
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────
  // Returns null on success — does NOT auto-login (caller redirects to sign-in)
  Future<String?> signUpWithEmail(
      String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
      // Sign out immediately — user must sign in explicitly
      await _auth.signOut();
      // Create Firestore doc (do this before sign-out completes)
      await _db.collection('users').doc(cred.user?.uid).set({
        'display_name': name,
        'email': email,
        'best_streak': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
      return null; // null = success, redirect to sign-in
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (e) {
      return 'Could not create account. Try again.';
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (e) {
      return 'Could not send reset email. Try again.';
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // 🔥 THIS LINE FIXES YOUR ISSUE
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      return true;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return false;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async => await _auth.signOut();

  // ── Firestore: Offline-first sync ────────────────────────────────────────
  Future<void> syncDailySummary({
    required String date,
    required int totalMinutes,
    required int streak,
    required String mood,
    required double addictionScore,
    required Map<String, int> appBreakdown,
  }) async {
    if (!isSignedIn) return;
    try {
      await _db
          .collection('users')
          .doc(currentUserId)
          .collection('daily_reports')
          .doc(date)
          .set({
        'total_minutes': totalMinutes,
        'streak': streak,
        'mood': mood,
        'addiction_score': addictionScore,
        'app_breakdown': appBreakdown,
        'synced_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('syncDailySummary error: $e');
    }
  }

  Future<void> updateBestStreak(int streak) async {
    if (!isSignedIn) return;
    try {
      final ref = _db.collection('users').doc(currentUserId);
      final doc = await ref.get();
      final current = (doc.data()?['best_streak'] as int?) ?? 0;
      if (streak > current) await ref.update({'best_streak': streak});
    } catch (e) {
      debugPrint('updateBestStreak error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final snap = await _db
          .collection('users')
          .orderBy('best_streak', descending: true)
          .limit(10)
          .get();
      return snap.docs
          .map((d) => {
        'name': d.data()['display_name'] ?? 'User',
        'streak': d.data()['best_streak'] ?? 0,
      })
          .toList();
    } catch (e) {
      return [
        {'name': displayName ?? 'You', 'streak': 0}
      ];
    }
  }

  // ── Error Messages ────────────────────────────────────────────────────────
  String _msg(String code) {
    switch (code) {
      case 'user-not-found':        return 'No account found with this email.';
      case 'wrong-password':        return 'Incorrect password. Try again.';
      case 'invalid-credential':    return 'Incorrect email or password.';
      case 'email-already-in-use':  return 'An account with this email already exists.';
      case 'weak-password':         return 'Password must be at least 6 characters.';
      case 'invalid-email':         return 'Please enter a valid email address.';
      case 'too-many-requests':     return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed': return 'No internet connection.';
      default: return 'Auth error ($code). Try again.';
    }
  }
}
