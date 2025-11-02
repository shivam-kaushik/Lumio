import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// Database helper singleton for SQLite operations
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  /// Ensure reminder_occurrences table exists (safety check for migrations)
  Future<void> _ensureOccurrencesTableExists(Database db) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [AppConstants.reminderOccurrencesTable],
      );
      
      if (result.isEmpty) {
        // Table doesn't exist, create it
        print('⚠️ reminder_occurrences table missing, creating it now...');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.reminderOccurrencesTable} (
            id TEXT PRIMARY KEY,
            reminderId TEXT NOT NULL,
            scheduledTime TEXT NOT NULL,
            isCompleted INTEGER DEFAULT 0,
            completedAt TEXT,
            notificationId INTEGER NOT NULL,
            FOREIGN KEY (reminderId) REFERENCES ${AppConstants.remindersTable} (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_reminder 
          ON ${AppConstants.reminderOccurrencesTable} (reminderId)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_time 
          ON ${AppConstants.reminderOccurrencesTable} (scheduledTime)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_notification 
          ON ${AppConstants.reminderOccurrencesTable} (notificationId)
        ''');
        print('✅ reminder_occurrences table created successfully');
      }
    } catch (e) {
      print('❌ Error ensuring reminder_occurrences table exists: $e');
    }
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
    
    // Safety check: ensure all required tables exist (for existing databases)
    await _ensureOccurrencesTableExists(db);
    
    return db;
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    // Reminders table with all fields
    await db.execute('''
      CREATE TABLE ${AppConstants.remindersTable} (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        timeAt TEXT,
        geofenceId TEXT,
        geofenceLat REAL,
        geofenceLng REAL,
        geofenceRadius REAL,
        wifiSsid TEXT,
        onLeaveContext INTEGER DEFAULT 0,
        onArriveContext INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        lastTriggeredAt TEXT,
        triggerCount INTEGER DEFAULT 0,
        repeatInterval INTEGER,
        repeatUnit TEXT,
        repeatEndDate TEXT,
        repeatOnDays TEXT,
        timeRangeStart TEXT,
        timeRangeEnd TEXT,
        preferredTimeOfDay TEXT,
        priority TEXT DEFAULT 'medium',
        category TEXT DEFAULT 'other',
        isPaused INTEGER DEFAULT 0,
        skipCount INTEGER DEFAULT 0,
        keepRemindingUntilCompleted INTEGER DEFAULT 0,
        activityType TEXT,
        useSmartTiming INTEGER DEFAULT 0
      )
    ''');

    // Context events table
    await db.execute('''
      CREATE TABLE ${AppConstants.contextEventsTable} (
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        contextType TEXT NOT NULL,
        triggerTime TEXT NOT NULL,
        outcome TEXT NOT NULL,
        metadata TEXT,
        activity_type TEXT,
        FOREIGN KEY (reminderId) REFERENCES ${AppConstants.remindersTable} (id)
          ON DELETE CASCADE
      )
    ''');

    // Locations table
    await db.execute('''
      CREATE TABLE ${AppConstants.locationsTable} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius REAL DEFAULT 100.0,
        wifiSsid TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX idx_reminders_enabled 
      ON ${AppConstants.remindersTable} (enabled)
    ''');

    await db.execute('''
      CREATE INDEX idx_context_events_reminder 
      ON ${AppConstants.contextEventsTable} (reminderId)
    ''');

      await db.execute('''
      CREATE INDEX idx_context_events_time 
      ON ${AppConstants.contextEventsTable} (triggerTime)
    ''');

    // Create learning_patterns table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_patterns (
        id TEXT PRIMARY KEY,
        reminder_text_pattern TEXT,
        optimal_time_hour INTEGER,
        optimal_time_minute INTEGER,
        completion_rate REAL,
        avg_response_time_seconds INTEGER,
        sample_count INTEGER,
        last_updated TEXT NOT NULL
      )
    ''');

    // Create reminder_occurrences table for tracking individual occurrences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.reminderOccurrencesTable} (
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        completedAt TEXT,
        notificationId INTEGER NOT NULL,
        FOREIGN KEY (reminderId) REFERENCES ${AppConstants.remindersTable} (id)
          ON DELETE CASCADE
      )
    ''');

    // Create indexes for occurrences
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_occurrences_reminder 
      ON ${AppConstants.reminderOccurrencesTable} (reminderId)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_occurrences_time 
      ON ${AppConstants.reminderOccurrencesTable} (scheduledTime)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_occurrences_notification 
      ON ${AppConstants.reminderOccurrencesTable} (notificationId)
    ''');
  }

  /// Upgrade database schema
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migration to version 6: Add reminder_occurrences table
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.reminderOccurrencesTable} (
            id TEXT PRIMARY KEY,
            reminderId TEXT NOT NULL,
            scheduledTime TEXT NOT NULL,
            isCompleted INTEGER DEFAULT 0,
            completedAt TEXT,
            notificationId INTEGER NOT NULL,
            FOREIGN KEY (reminderId) REFERENCES ${AppConstants.remindersTable} (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_reminder 
          ON ${AppConstants.reminderOccurrencesTable} (reminderId)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_time 
          ON ${AppConstants.reminderOccurrencesTable} (scheduledTime)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_occurrences_notification 
          ON ${AppConstants.reminderOccurrencesTable} (notificationId)
        ''');
      } catch (e) {
        print('Error creating reminder_occurrences table: $e');
      }
    }

    // Handle future migrations here
    if (oldVersion < 2) {
      // Add recurrence fields - check if they exist first
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN repeatInterval INTEGER',
        );
      } catch (e) {
        // Column might already exist, ignore error
        print('repeatInterval column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN repeatUnit TEXT',
        );
      } catch (e) {
        // Column might already exist, ignore error
        print('repeatUnit column already exists or error: $e');
      }
    }

    if (oldVersion < 3) {
      // Add smart reminder features
      final newColumns = [
        'repeatEndDate TEXT',
        'repeatOnDays TEXT',
        'timeRangeStart TEXT',
        'timeRangeEnd TEXT',
        'preferredTimeOfDay TEXT',
        "priority TEXT DEFAULT 'medium'",
        "category TEXT DEFAULT 'other'",
        'isPaused INTEGER DEFAULT 0',
        'skipCount INTEGER DEFAULT 0',
      ];

      for (var column in newColumns) {
        try {
          await db.execute(
            'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN $column',
          );
        } catch (e) {
          print('Column $column already exists or error: $e');
        }
      }
    }

    if (oldVersion < 4) {
      // Add constant reminder support
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN keepRemindingUntilCompleted INTEGER DEFAULT 0',
        );
      } catch (e) {
        print('keepRemindingUntilCompleted column already exists or error: $e');
      }
    }

    if (oldVersion < 5) {
      // Add Phase 2 features: activity recognition and smart timing
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN activityType TEXT',
        );
      } catch (e) {
        print('activityType column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN useSmartTiming INTEGER DEFAULT 0',
        );
      } catch (e) {
        print('useSmartTiming column already exists or error: $e');
      }

      // Add activity_type to context_events
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.contextEventsTable} ADD COLUMN activity_type TEXT',
        );
      } catch (e) {
        print('activity_type column already exists or error: $e');
      }

      // Create learning_patterns table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS learning_patterns (
            id TEXT PRIMARY KEY,
            reminder_text_pattern TEXT,
            optimal_time_hour INTEGER,
            optimal_time_minute INTEGER,
            completion_rate REAL,
            avg_response_time_seconds INTEGER,
            sample_count INTEGER,
            last_updated TEXT NOT NULL
          )
        ''');
      } catch (e) {
        print('learning_patterns table already exists or error: $e');
      }
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  /// Delete database (for testing/reset)
  Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    await deleteDatabase(path);
    _database = null;
  }
}
