import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'dart:async';

class SyncRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _db;
  final User? _user;
  static const String _lastSyncKey = 'last_sync_timestamp';

  final _syncStatusController = StreamController<DateTime?>.broadcast();
  Stream<DateTime?> get lastSyncStream => _syncStatusController.stream;

  SyncRepository(this._db, this._user) {
    _loadLastSyncTime();
  }

  String? get _uid => _user?.uid;

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    if (timestamp != null) {
      _syncStatusController.add(DateTime.fromMillisecondsSinceEpoch(timestamp));
    } else {
      _syncStatusController.add(null);
    }
  }

  Future<void> _updateLastSyncTime() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
    _syncStatusController.add(now);
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  Future<void> syncAll() async {
    if (_uid == null) return;
    try {
      await uploadLocalSessions();
      await downloadRemoteSessions();
      await _updateLastSyncTime();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> uploadLocalSessions() async {
    if (_uid == null) return;

    final sessions = await _db.allSessions;
    if (sessions.isEmpty) return;

    final batch = _firestore.batch();
    final userSessionsRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('sessions');

    for (var session in sessions) {
      final docId = '${session.startTime.millisecondsSinceEpoch}_${session.id}';
      final docRef = userSessionsRef.doc(docId);

      batch.set(docRef, {
        'startTime': Timestamp.fromDate(session.startTime),
        'durationSeconds': session.durationSeconds,
        'type': session.type,
        'completed': session.completed,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> downloadRemoteSessions() async {
    if (_uid == null) return;

    final userSessionsRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('sessions');
    final snapshot = await userSessionsRef.get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final startTime = (data['startTime'] as Timestamp).toDate();

      final exists = await _db.checkSessionExists(startTime);

      if (!exists) {
        await _db.addSession(
          SessionsCompanion.insert(
            startTime: startTime,
            durationSeconds: data['durationSeconds'] as int,
            type: Value(data['type'] as String),
            completed: Value(data['completed'] as bool),
          ),
        );
      }
    }
  }

  Future<void> clearCloudData() async {
    if (_uid == null) return;

    final userSessionsRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('sessions');

    final snapshot = await userSessionsRef.get();
    final batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
