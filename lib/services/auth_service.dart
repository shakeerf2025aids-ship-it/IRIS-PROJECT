import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom exception for auth errors with user-friendly messages
class AuthException implements Exception {
  final String message;
  final String code;

  AuthException({required this.message, required this.code});

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Sign up with email and password
  /// Throws [AuthException] with user-friendly error message
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Validate inputs
      if (email.trim().isEmpty) {
        throw AuthException(
          message: 'Email is required',
          code: 'empty_email',
        );
      }

      if (!_isValidEmail(email)) {
        throw AuthException(
          message: 'Invalid email format',
          code: 'invalid_email',
        );
      }

      if (password.isEmpty) {
        throw AuthException(
          message: 'Password is required',
          code: 'empty_password',
        );
      }

      if (password.length < 6) {
        throw AuthException(
          message: 'Password must be at least 6 characters',
          code: 'weak_password',
        );
      }

      if (fullName.trim().isEmpty) {
        throw AuthException(
          message: 'Full name is required',
          code: 'empty_name',
        );
      }

      debugPrint('[AUTH DEBUG] Attempting signup for: ${email.trim()}');

      // Create user
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('[AUTH DEBUG] Signup successful for UID: ${userCredential.user?.uid}');

      // Update user profile with full name
      await userCredential.user?.updateDisplayName(fullName.trim());
      await userCredential.user?.reload();

      // Save session locally
      await _saveSession(userCredential.user!.uid);

      return userCredential.user;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseAuthException during signup');
      debugPrint('[AUTH ERROR] Code: ${e.code}');
      debugPrint('[AUTH ERROR] Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseException during signup');
      debugPrint('[AUTH ERROR] Code: ${e.code}');
      debugPrint('[AUTH ERROR] Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Unexpected exception during signup');
      debugPrint('[AUTH ERROR] Type: ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Details: $e');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: 'Signup failed: ${e.runtimeType} - $e',
        code: 'unknown_error',
      );
    }
  }

  /// Sign in with email and password
  /// Throws [AuthException] with user-friendly error message
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Validate inputs
      if (email.trim().isEmpty) {
        throw AuthException(
          message: 'Email is required',
          code: 'empty_email',
        );
      }

      if (password.isEmpty) {
        throw AuthException(
          message: 'Password is required',
          code: 'empty_password',
        );
      }

      debugPrint('[AUTH DEBUG] Attempting login for: ${email.trim()}');
      debugPrint('[AUTH DEBUG] Firebase project: ${_firebaseAuth.app.options.projectId}');
      debugPrint('[AUTH DEBUG] Firebase app name: ${_firebaseAuth.app.name}');

      // Sign in
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('[AUTH DEBUG] Login successful for UID: ${userCredential.user?.uid}');

      // Save session locally
      await _saveSession(userCredential.user!.uid);

      return userCredential.user;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseAuthException during login');
      debugPrint('[AUTH ERROR] Code: ${e.code}');
      debugPrint('[AUTH ERROR] Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseException during login');
      debugPrint('[AUTH ERROR] Code: ${e.code}');
      debugPrint('[AUTH ERROR] Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Unexpected exception during login');
      debugPrint('[AUTH ERROR] Type: ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Details: $e');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: 'Login failed: ${e.runtimeType} - $e',
        code: 'unknown_error',
      );
    }
  }

  /// Send password reset email
  /// Throws [AuthException] with user-friendly error message
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      if (email.trim().isEmpty) {
        throw AuthException(
          message: 'Email is required',
          code: 'empty_email',
        );
      }

      if (!_isValidEmail(email)) {
        throw AuthException(
          message: 'Invalid email format',
          code: 'invalid_email',
        );
      }

      debugPrint('[AUTH DEBUG] Sending password reset for: ${email.trim()}');

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());

      debugPrint('[AUTH DEBUG] Password reset email sent successfully');
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseAuthException during password reset');
      debugPrint('[AUTH ERROR] Code: ${e.code}, Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseException during password reset');
      debugPrint('[AUTH ERROR] Code: ${e.code}, Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Unexpected exception during password reset');
      debugPrint('[AUTH ERROR] Type: ${e.runtimeType}, Details: $e');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: 'Failed to send reset email: ${e.runtimeType} - $e',
        code: 'unknown_error',
      );
    }
  }

  /// Confirm password reset with code and new password
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      if (newPassword.isEmpty) {
        throw AuthException(
          message: 'Password is required',
          code: 'empty_password',
        );
      }

      if (newPassword.length < 6) {
        throw AuthException(
          message: 'Password must be at least 6 characters',
          code: 'weak_password',
        );
      }

      await _firebaseAuth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseAuthException during password confirm');
      debugPrint('[AUTH ERROR] Code: ${e.code}, Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseException during password confirm');
      debugPrint('[AUTH ERROR] Code: ${e.code}, Message: ${e.message}');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    }
  }

  /// Re-authenticate the user with their current email and password.
  /// Required before sensitive operations like changing password or deleting account.
  Future<void> reauthenticate(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw AuthException(
          message: 'No user logged in',
          code: 'no_user',
        );
      }

      if (password.isEmpty) {
        throw AuthException(
          message: 'Password is required',
          code: 'empty_password',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      debugPrint('[AUTH DEBUG] Re-authentication successful');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH ERROR] Re-authentication failed: ${e.code}');
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        message: 'Re-authentication failed',
        code: 'reauth_error',
      );
    }
  }

  /// Change the current user's password.
  /// Requires re-authentication first via [reauthenticate].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(
          message: 'No user logged in',
          code: 'no_user',
        );
      }

      if (newPassword.isEmpty) {
        throw AuthException(
          message: 'New password is required',
          code: 'empty_password',
        );
      }

      if (newPassword.length < 6) {
        throw AuthException(
          message: 'Password must be at least 6 characters',
          code: 'weak_password',
        );
      }

      if (currentPassword == newPassword) {
        throw AuthException(
          message: 'New password must be different from the current password',
          code: 'same_password',
        );
      }

      // Re-authenticate first — Firebase requires this for password changes
      await reauthenticate(currentPassword);

      // Update the password
      await user.updatePassword(newPassword);
      debugPrint('[AUTH DEBUG] Password changed successfully');
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        message: 'Failed to change password',
        code: 'change_password_error',
      );
    }
  }

  /// Delete the current user's Firebase Auth account.
  /// Requires re-authentication first via [reauthenticate].
  /// Caller is responsible for deleting Firestore data before calling this.
  Future<void> deleteAccount(String password) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(
          message: 'No user logged in',
          code: 'no_user',
        );
      }

      // Re-authenticate before deletion
      await reauthenticate(password);

      // Delete the Firebase Auth account
      await user.delete();
      debugPrint('[AUTH DEBUG] Account deleted successfully');

      // Clear local session
      await _clearSession();
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        message: 'Failed to delete account',
        code: 'delete_account_error',
      );
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      debugPrint('[AUTH DEBUG] Logging out user: ${currentUser?.uid}');
      await _firebaseAuth.signOut();
      // Clear local session
      await _clearSession();
      debugPrint('[AUTH DEBUG] Logout successful');
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Logout failed: $e');
      debugPrint('[AUTH ERROR] StackTrace: $stackTrace');
      throw AuthException(
        message: 'Failed to logout',
        code: 'logout_error',
      );
    }
  }

  /// Check if user has session stored locally (for persistence)
  Future<bool> hasStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('user_uid');
    } catch (e) {
      return false;
    }
  }

  /// Save user session locally
  Future<void> _saveSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', uid);
      await prefs.setInt('session_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Session save failure shouldn't prevent login
      debugPrint('[AUTH WARN] Session save failed: $e');
    }
  }

  /// Clear local session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('session_timestamp');
    } catch (e) {
      // Session clear failure shouldn't prevent logout
      debugPrint('[AUTH WARN] Session clear failed: $e');
    }
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email already in use';
      case 'invalid-email':
        return 'Invalid email format';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please enable it in Firebase Console.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'user-disabled':
        return 'User account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Wrong password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'CONFIGURATION_NOT_FOUND':
        return 'Firebase project configuration not found. Check Firebase Console setup.';
      case 'app-not-authorized':
        return 'This app is not authorized in the Firebase project';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      default:
        debugPrint('[AUTH WARN] Unhandled Firebase error code: $code');
        return 'Authentication error [$code]';
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException(
          message: 'No user logged in',
          code: 'no_user',
        );
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    }
  }

  /// Reload current user
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    } on FirebaseException catch (e) {
      throw AuthException(
        message: _getFirebaseErrorMessage(e.code),
        code: e.code,
      );
    }
  }
}
