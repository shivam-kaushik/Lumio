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
        weatherCondition TEXT,
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
        useSmartTiming INTEGER DEFAULT 0,
        linked_goal_id INTEGER
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

    // MVP: Create goals table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.goalsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        target_deadline TEXT,
        hours_per_day REAL,
        total_estimated_hours INTEGER
      )
    ''');

    // Create phases table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.phasesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
          ON DELETE CASCADE
      )
    ''');

    // Create tasks table (renamed from subtasks)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.tasksTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        estimated_hours REAL,
        priority TEXT DEFAULT 'medium',
        frequency TEXT DEFAULT 'one-time',
        suggested_time TEXT DEFAULT 'any',
        suggested_location TEXT DEFAULT 'any',
        is_milestone INTEGER DEFAULT 0,
        motivation_anchor TEXT,
        scheduled_date TEXT,
        phase_id INTEGER,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
          ON DELETE CASCADE,
        FOREIGN KEY (phase_id) REFERENCES ${AppConstants.phasesTable} (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_goal 
      ON ${AppConstants.tasksTable} (goal_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_scheduled 
      ON ${AppConstants.tasksTable} (scheduled_date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_phases_goal 
      ON ${AppConstants.phasesTable} (goal_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_phase 
      ON ${AppConstants.tasksTable} (phase_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reminders_goal 
      ON ${AppConstants.remindersTable} (linked_goal_id)
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

    if (oldVersion < 7) {
      // Add weatherCondition to reminders
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN weatherCondition TEXT',
        );
      } catch (e) {
        print('weatherCondition column already exists or error: $e');
      }
    }

    if (oldVersion < 8) {
      // MVP: Add skills, reps, goals tables and linked_skill_id to reminders
      try {
        // Add linked_skill_id to reminders
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN linked_skill_id INTEGER',
        );
      } catch (e) {
        print('linked_skill_id column already exists or error: $e');
      }

      // Create goals table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.goalsTable} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            target_deadline TEXT,
            hours_per_day REAL,
            total_estimated_hours INTEGER
          )
        ''');
      } catch (e) {
        print('goals table already exists or error: $e');
      }

      // Add new columns to existing goals table if they don't exist
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN target_deadline TEXT',
        );
      } catch (e) {
        print('target_deadline column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN hours_per_day REAL',
        );
      } catch (e) {
        print('hours_per_day column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN total_estimated_hours INTEGER',
        );
      } catch (e) {
        print('total_estimated_hours column already exists or error: $e');
      }

      // Skills and reps tables removed in version 12
    }

    if (oldVersion < 9) {
      // Add deadline and capacity columns to existing goals table
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN target_deadline TEXT',
        );
        print('✅ Added target_deadline column to goals table');
      } catch (e) {
        print('⚠️ target_deadline column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN hours_per_day REAL',
        );
        print('✅ Added hours_per_day column to goals table');
      } catch (e) {
        print('⚠️ hours_per_day column already exists or error: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN total_estimated_hours INTEGER',
        );
        print('✅ Added total_estimated_hours column to goals table');
      } catch (e) {
        print('⚠️ total_estimated_hours column already exists or error: $e');
      }
    }

    if (oldVersion < 10) {
      // Create tasks table for goal planning (renamed from subtasks in v12)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.tasksTable} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            estimated_hours REAL,
            priority TEXT DEFAULT 'medium',
            frequency TEXT DEFAULT 'one-time',
            suggested_time TEXT DEFAULT 'any',
            suggested_location TEXT DEFAULT 'any',
            is_milestone INTEGER DEFAULT 0,
            motivation_anchor TEXT,
            scheduled_date TEXT,
            is_completed INTEGER DEFAULT 0,
            completed_at TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
              ON DELETE CASCADE
          )
        ''');
        print('✅ Created tasks table');
      } catch (e) {
        print('⚠️ tasks table already exists or error: $e');
      }

      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_tasks_goal 
          ON ${AppConstants.tasksTable} (goal_id)
        ''');
      } catch (e) {
        print('⚠️ idx_tasks_goal index already exists or error: $e');
      }

      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_tasks_scheduled 
          ON ${AppConstants.tasksTable} (scheduled_date)
        ''');
      } catch (e) {
        print('⚠️ idx_tasks_scheduled index already exists or error: $e');
      }
    }

    // Migration to version 11: Core Features - Goal linking
    if (oldVersion < 11) {
      // Add linked_goal_id to reminders table
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.remindersTable} ADD COLUMN linked_goal_id INTEGER',
        );
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_reminders_goal 
          ON ${AppConstants.remindersTable} (linked_goal_id)
        ''');
      } catch (e) {
        print('linked_goal_id column already exists or error: $e');
      }

      print('✅ Migration to version 11 completed');
    }

    // Migration to version 12: Remove skills/reps, rename subtasks to tasks
    if (oldVersion < 12) {
      try {
        // Drop skills and reps tables if they exist
        await db.execute('DROP TABLE IF EXISTS reps');
        await db.execute('DROP TABLE IF EXISTS skills');
        print('✅ Dropped skills and reps tables');
      } catch (e) {
        print('⚠️ Error dropping skills/reps tables: $e');
      }

      // Rename subtasks table to tasks if it exists
      try {
        // Check if subtasks table exists (old name)
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          ['subtasks'],
        );
        
        if (result.isNotEmpty) {
          // Rename table
          await db.execute(
            'ALTER TABLE subtasks RENAME TO ${AppConstants.tasksTable}',
          );
          print('✅ Renamed subtasks table to tasks');
        } else {
          // Create tasks table if subtasks doesn't exist
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${AppConstants.tasksTable} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              goal_id INTEGER NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              estimated_hours REAL,
              priority TEXT DEFAULT 'medium',
              frequency TEXT DEFAULT 'one-time',
              suggested_time TEXT DEFAULT 'any',
              suggested_location TEXT DEFAULT 'any',
              is_milestone INTEGER DEFAULT 0,
              motivation_anchor TEXT,
              scheduled_date TEXT,
              is_completed INTEGER DEFAULT 0,
              completed_at TEXT,
              created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
                ON DELETE CASCADE
            )
          ''');
          print('✅ Created tasks table');
        }

        // Remove skill_id column from tasks (SQLite doesn't support DROP COLUMN, so we'll recreate)
        // For existing data, we'll need to copy data to new table
        try {
          // Check if skill_id column exists
          final tableInfo = await db.rawQuery('PRAGMA table_info(${AppConstants.tasksTable})');
          final hasSkillId = tableInfo.any((col) => col['name'] == 'skill_id');
          
          if (hasSkillId) {
            // Create new table without skill_id
            await db.execute('''
              CREATE TABLE IF NOT EXISTS ${AppConstants.tasksTable}_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                goal_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                estimated_hours REAL,
                priority TEXT DEFAULT 'medium',
                frequency TEXT DEFAULT 'one-time',
                suggested_time TEXT DEFAULT 'any',
                suggested_location TEXT DEFAULT 'any',
                is_milestone INTEGER DEFAULT 0,
                motivation_anchor TEXT,
                scheduled_date TEXT,
                is_completed INTEGER DEFAULT 0,
                completed_at TEXT,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
                  ON DELETE CASCADE
              )
            ''');

            // Copy data (excluding skill_id)
            await db.execute('''
              INSERT INTO ${AppConstants.tasksTable}_new 
              (id, goal_id, title, description, estimated_hours, priority, frequency, 
               suggested_time, suggested_location, is_milestone, motivation_anchor, 
               scheduled_date, is_completed, completed_at, created_at)
              SELECT id, goal_id, title, description, estimated_hours, priority, frequency,
                     suggested_time, suggested_location, is_milestone, motivation_anchor,
                     scheduled_date, is_completed, completed_at, created_at
              FROM ${AppConstants.tasksTable}
            ''');

            // Drop old table and rename new one
            await db.execute('DROP TABLE ${AppConstants.tasksTable}');
            await db.execute('ALTER TABLE ${AppConstants.tasksTable}_new RENAME TO ${AppConstants.tasksTable}');
            print('✅ Removed skill_id column from tasks table');
          }
        } catch (e) {
          print('⚠️ Error removing skill_id column: $e');
        }

        // Recreate indexes
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_tasks_goal 
          ON ${AppConstants.tasksTable} (goal_id)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_tasks_scheduled 
          ON ${AppConstants.tasksTable} (scheduled_date)
        ''');

        // Remove linked_skill_id from reminders (SQLite limitation - can't drop column easily)
        // We'll just ignore it in queries
        print('✅ Migration to version 12 completed');
      } catch (e) {
        print('⚠️ Error in version 12 migration: $e');
      }
    }

    // Migration to version 13: Add phases table and phase_id to tasks
    if (oldVersion < 13) {
      try {
        // Create phases table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${AppConstants.phasesTable} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            goal_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            order_index INTEGER DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (goal_id) REFERENCES ${AppConstants.goalsTable} (id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_phases_goal
          ON ${AppConstants.phasesTable} (goal_id)
        ''');

        // Add phase_id column to tasks table
        // SQLite doesn't support ALTER TABLE ADD COLUMN IF NOT EXISTS, so we check first
        final tableInfo = await db.rawQuery('PRAGMA table_info(${AppConstants.tasksTable})');
        final hasPhaseId = tableInfo.any((col) => col['name'] == 'phase_id');

        if (!hasPhaseId) {
          await db.execute(
            'ALTER TABLE ${AppConstants.tasksTable} ADD COLUMN phase_id INTEGER',
          );
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_tasks_phase
            ON ${AppConstants.tasksTable} (phase_id)
          ''');
        }

        print('✅ Migration to version 13 completed');
      } catch (e) {
        print('⚠️ Error in version 13 migration: $e');
      }
    }

    // Migration to version 14: Add image_url to goals table
    if (oldVersion < 14) {
      try {
        await db.execute(
          'ALTER TABLE ${AppConstants.goalsTable} ADD COLUMN image_url TEXT',
        );
        print('✅ Added image_url column to goals table (version 14)');
      } catch (e) {
        print('⚠️ image_url column already exists or error: $e');
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
