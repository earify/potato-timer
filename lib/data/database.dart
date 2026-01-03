import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DataClassName('Session')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get durationSeconds => integer()();
  TextColumn get type =>
      text().withDefault(const Constant('focus'))(); // focus, rest
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
}

@DataClassName('TimerEvent')
class TimerEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()(); // pause, skip_focus, skip_rest
}

@DriftDatabase(tables: [Sessions, TimerEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(timerEvents);
      }
    },
  );

  // Statistics Queries

  // Get sessions within a date range
  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) {
    return (select(sessions)..where(
          (tbl) => tbl.startTime.isBetween(Variable(start), Variable(end)),
        ))
        .get();
  }

  Future<List<TimerEvent>> getEventsInRange(DateTime start, DateTime end) {
    return (select(timerEvents)..where(
          (tbl) => tbl.timestamp.isBetween(Variable(start), Variable(end)),
        ))
        .get();
  }

  Future<List<Session>> get allSessions => select(sessions).get();

  Future<bool> checkSessionExists(DateTime startTime) async {
    final query = select(sessions)
      ..where((tbl) => tbl.startTime.equals(startTime));
    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<int> addSession(SessionsCompanion entry) {
    return into(sessions).insert(entry);
  }

  Future<int> addEvent(TimerEventsCompanion entry) {
    return into(timerEvents).insert(entry);
  }

  Future<int> deleteAllSessions() async {
    await delete(timerEvents).go();
    return delete(sessions).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
