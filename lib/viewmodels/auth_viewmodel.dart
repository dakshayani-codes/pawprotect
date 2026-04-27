// lib/viewmodels/auth_viewmodel.dart

import 'package:flutter/material.dart';
import '../data/remote/firebase_service.dart';

enum AuthState { unauthenticated, loading, authenticated, error }

/// Extra state to signal auth_screen to switch to sign-in tab after sign-up
enum AuthAction { none, switchToSignIn, showResetSent }

class AuthViewModel extends ChangeNotifier {
  AuthState _state = AuthState.unauthenticated;
  String _errorMessage = '';
  AuthAction _pendingAction = AuthAction.none;
  String _infoMessage = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  AuthAction get pendingAction => _pendingAction;
  String get infoMessage => _infoMessage;

  String get displayName => FirebaseService.instance.displayName ?? 'User';
  String get email => FirebaseService.instance.email ?? '';

  void checkExistingSession() {
    if (FirebaseService.instance.hasExistingSession) {
      _state = AuthState.authenticated;
      notifyListeners();
    }
  }

  void continueAsGuest() {
    _state = AuthState.authenticated;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (!_validateFields([email, password])) return;
    if (!_validateEmail(email)) return;

    _state = AuthState.loading;
    notifyListeners();

    final error =
    await FirebaseService.instance.signInWithEmail(email.trim(), password.trim());

    if (error == null) {
      _state = AuthState.authenticated;
    } else {
      _setError(error);
    }
    notifyListeners();
  }

  /// After success: redirects to sign-in tab (does NOT auto-authenticate)
  Future<void> signUp(String name, String email, String password) async {
    name = name.trim(); email = email.trim(); password = password.trim();
    if (!_validateFields([name, email, password])) return;
    if (!_validateEmail(email)) return;
    if (password.length < 6) {
      _setError('Password must be at least 6 characters');
      return;
    }

    _state = AuthState.loading;
    notifyListeners();

    final error = await FirebaseService.instance
        .signUpWithEmail(email, password, name);

    if (error == null) {
      // ← KEY: do NOT set authenticated — redirect to sign-in instead
      _state = AuthState.unauthenticated;
      _infoMessage = 'Account created! Sign in to continue.';
      _pendingAction = AuthAction.switchToSignIn;
    } else {
      _setError(error);
    }
    notifyListeners();
  }

  Future<void> sendForgotPassword(String email) async {
    if (email.trim().isEmpty) {
      _setError('Enter your email address first');
      return;
    }
    _state = AuthState.loading;
    notifyListeners();

    final error =
    await FirebaseService.instance.sendPasswordReset(email.trim());

    _state = AuthState.unauthenticated;
    if (error == null) {
      _infoMessage = 'Reset email sent! Check your inbox.';
      _pendingAction = AuthAction.showResetSent;
    } else {
      _setError(error);
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _state = AuthState.loading;
    notifyListeners();

    final success =
    await FirebaseService.instance.signInWithGoogle();

    if (success) {
      _state = AuthState.authenticated;
    } else {
      _setError('Google sign-in failed');
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseService.instance.signOut();
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    _infoMessage = '';
    _pendingAction = AuthAction.none;
    if (_state == AuthState.error) _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearPendingAction() {
    _pendingAction = AuthAction.none;
  }

  bool _validateFields(List<String> fields) {
    if (fields.any((f) => f.trim().isEmpty)) {
      _setError('Please fill in all fields');
      return false;
    }
    return true;
  }

  bool _validateEmail(String email) {
    if (!email.contains('@') || !email.contains('.')) {
      _setError('Enter a valid email address');
      return false;
    }
    return true;
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = AuthState.error;
  }
}
