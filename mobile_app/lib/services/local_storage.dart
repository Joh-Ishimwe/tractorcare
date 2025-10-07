import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tractor.dart';
import 'dart:convert';

class LocalStorage {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tractorcare.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tractors table
        await db.execute('''
          CREATE TABLE tractors(
            tractor_id TEXT PRIMARY KEY,
            coop_id TEXT,
            model TEXT,
            engine_hours REAL,
            usage_intensity TEXT,
            current_status TEXT,
            last_maintenance_date TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Predictions table
        await db.execute('''
          CREATE TABLE predictions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tractor_id TEXT,
            task_name TEXT,
            description TEXT,
            status TEXT,
            urgency_level INTEGER,
            hours_remaining REAL,
            days_remaining INTEGER,
            estimated_cost_rwf INTEGER,
            recommendation TEXT,
            prediction_date TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Bookings table
        await db.execute('''
          CREATE TABLE bookings(
            booking_id INTEGER PRIMARY KEY,
            tractor_id TEXT,
            member_id TEXT,
            start_date TEXT,
            end_date TEXT,
            booking_status TEXT,
            payment_status TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Sync queue (for offline changes)
        await db.execute('''
          CREATE TABLE sync_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT,
            action TEXT,
            data TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }
  
  // Tractors CRUD
  Future<void> insertTractor(Tractor tractor) async {
    final db = await database;
    await db.insert(
      'tractors',
      {...tractor.toLocalDb(), 'synced': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Tractor>> getTractors(String coopId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tractors',
      where: 'coop_id = ?',
      whereArgs: [coopId],
    );
    
    return List.generate(maps.length, (i) => Tractor.fromLocalDb(maps[i]));
  }
  
  Future<Tractor?> getTractor(String tractorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tractors',
      where: 'tractor_id = ?',
      whereArgs: [tractorId],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Tractor.fromLocalDb(maps.first);
  }
  
  // Add to sync queue when offline
  Future<void> addToSyncQueue(String tableName, String action, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'action': action,
      'data': jsonEncode(data),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  // Get pending sync items
  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }
  
  // Clear sync queue after successful sync
  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }
}