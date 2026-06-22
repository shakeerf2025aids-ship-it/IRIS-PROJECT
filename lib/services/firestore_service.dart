import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Exception for Firestore operations
class FirestoreException implements Exception {
  final String message;
  final String code;

  FirestoreException({required this.message, required this.code});

  @override
  String toString() => message;
}

/// Model for scan result
class ScanResult {
  final String id;
  final String userId;
  final int predictedClass;
  final double confidenceScore;
  final String riskStatus;
  final DateTime timestamp;

  ScanResult({
    required this.id,
    required this.userId,
    required this.predictedClass,
    required this.confidenceScore,
    required this.riskStatus,
    required this.timestamp,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'predictedClass': predictedClass,
      'confidenceScore': confidenceScore,
      'riskStatus': riskStatus,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  /// Create from Firestore document
  factory ScanResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ScanResult(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      predictedClass: data['predictedClass'] as int? ?? 0,
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      riskStatus: data['riskStatus'] as String? ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  /// Get the scans collection reference
  CollectionReference<Map<String, dynamic>> get _scansCollection {
    return _firestore.collection('scans');
  }

  /// Get current user ID
  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirestoreException(
        message: 'User not authenticated',
        code: 'not_authenticated',
      );
    }
    return user.uid;
  }

  /// Save a scan result to Firestore
  /// Returns the document ID
  Future<String> saveScanResult({
    required int predictedClass,
    required double confidenceScore,
    required String riskStatus,
  }) async {
    try {
      final scanData = {
        'userId': _currentUserId,
        'predictedClass': predictedClass,
        'confidenceScore': confidenceScore,
        'riskStatus': riskStatus,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await _scansCollection.add(scanData);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to save scan result: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirestoreException(
        message: 'An unexpected error occurred while saving scan',
        code: 'unknown_error',
      );
    }
  }

  /// Get all scans for the current user (latest first)
  Stream<List<ScanResult>> getUserScansStream() {
    try {
      return _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ScanResult.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      throw FirestoreException(
        message: 'Failed to fetch scan history',
        code: 'fetch_failed',
      );
    }
  }

  /// Get paginated scans for the current user
  /// [pageSize] - Number of scans per page
  /// [lastDoc] - Last document from previous page for pagination
  Future<List<ScanResult>> getUserScansPaginated({
    int pageSize = 10,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ScanResult.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to fetch scans: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirestoreException(
        message: 'An unexpected error occurred',
        code: 'unknown_error',
      );
    }
  }

  /// Get a single scan by ID
  Future<ScanResult> getScanById(String scanId) async {
    try {
      final doc = await _scansCollection.doc(scanId).get();
      if (!doc.exists) {
        throw FirestoreException(
          message: 'Scan not found',
          code: 'scan_not_found',
        );
      }

      final scanResult = ScanResult.fromFirestore(doc);

      // Verify ownership
      if (scanResult.userId != _currentUserId) {
        throw FirestoreException(
          message: 'Unauthorized access to this scan',
          code: 'unauthorized',
        );
      }

      return scanResult;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to fetch scan: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        message: 'An unexpected error occurred',
        code: 'unknown_error',
      );
    }
  }

  /// Get total count of scans for current user
  Future<int> getScanCount() async {
    try {
      final snapshot = await _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to get scan count: ${e.message}',
        code: e.code,
      );
    }
  }

  /// Get scans filtered by risk status
  Stream<List<ScanResult>> getScansByRiskStatus(String riskStatus) {
    try {
      return _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .where('riskStatus', isEqualTo: riskStatus)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ScanResult.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      throw FirestoreException(
        message: 'Failed to fetch filtered scans',
        code: 'fetch_failed',
      );
    }
  }

  /// Delete a scan (only if user owns it)
  Future<void> deleteScan(String scanId) async {
    try {
      // Verify ownership first
      await getScanById(scanId);
      
      await _scansCollection.doc(scanId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to delete scan: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        message: 'Failed to delete scan',
        code: 'delete_failed',
      );
    }
  }

  /// Update scan result
  Future<void> updateScan({
    required String scanId,
    required String riskStatus,
  }) async {
    try {
      // Verify ownership first
      await getScanById(scanId);
      
      await _scansCollection.doc(scanId).update({
        'riskStatus': riskStatus,
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to update scan: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        message: 'Failed to update scan',
        code: 'update_failed',
      );
    }
  }

  /// Get scans from a specific date range
  Stream<List<ScanResult>> getScansByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    try {
      return _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ScanResult.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      throw FirestoreException(
        message: 'Failed to fetch date-filtered scans',
        code: 'fetch_failed',
      );
    }
  }

  /// Get average confidence score for current user
  Future<double> getAverageConfidenceScore() async {
    try {
      final snapshot = await _scansCollection
          .where('userId', isEqualTo: _currentUserId)
          .get();

      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      double total = 0;
      for (var doc in snapshot.docs) {
        final confidenceScore = (doc['confidenceScore'] as num?)?.toDouble() ?? 0.0;
        total += confidenceScore;
      }

      return total / snapshot.docs.length;
    } catch (e) {
      throw FirestoreException(
        message: 'Failed to calculate average confidence',
        code: 'calculation_failed',
      );
    }
  }

  /// Delete all scan records for a specific user.
  /// Used during account deletion to clean up Firestore data.
  /// Takes [userId] as a parameter so it works even when auth state is changing.
  Future<void> deleteAllUserScans(String userId) async {
    try {
      final snapshot = await _scansCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return;

      // Firestore batch write limit is 500 operations per batch.
      final batches = <WriteBatch>[];
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        operationCount++;

        if (operationCount == 500) {
          batches.add(batch);
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(batch);
      }

      for (final b in batches) {
        await b.commit();
      }

      debugPrint('[FIRESTORE] Deleted ${snapshot.docs.length} scans for user $userId');
    } on FirebaseException catch (e) {
      throw FirestoreException(
        message: 'Failed to delete user scans: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw FirestoreException(
        message: 'Failed to delete user data',
        code: 'delete_all_failed',
      );
    }
  }
}
