import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogEntry {
  final String message;
  final DateTime timestamp;
  final String level;
  final String? source;

  const LogEntry({
    required this.message,
    required this.timestamp,
    required this.level,
    this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'source': source,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: json['level'] as String,
      source: json['source'] as String?,
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (logDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  static const String _logsKey = 'debug_logs';
  static const int _maxLogs = 500; // Maksimum log sayısı
  
  List<LogEntry> _logs = [];
  SharedPreferences? _prefs;
  bool _initialized = false;

  // Initialize logger
  static Future<void> initialize() async {
    await _instance._initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadLogs();
      _initialized = true;
    } catch (e) {
      developer.log('Failed to initialize DebugLogger: $e');
    }
  }

  // Load logs from local storage
  Future<void> _loadLogs() async {
    try {
      final logsJson = _prefs?.getString(_logsKey);
      if (logsJson != null && logsJson.isNotEmpty) {
        final List<dynamic> logsList = jsonDecode(logsJson);
        _logs = logsList.map((json) => LogEntry.fromJson(json)).toList();
        
        // Sort by timestamp descending (newest first)
        _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      developer.log('Failed to load logs: $e');
      _logs = [];
    }
  }

  // Save logs to local storage
  Future<void> _saveLogs() async {
    if (!_initialized || _prefs == null) return;
    
    try {
      // Keep only the most recent logs
      if (_logs.length > _maxLogs) {
        _logs = _logs.take(_maxLogs).toList();
      }
      
      final logsJson = jsonEncode(_logs.map((log) => log.toJson()).toList());
      await _prefs!.setString(_logsKey, logsJson);
    } catch (e) {
      developer.log('Failed to save logs: $e');
    }
  }

  // Add a log entry
  Future<void> _addLog(String message, String level, [String? source]) async {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      level: level,
      source: source,
    );
    
    _logs.insert(0, entry); // Add to beginning (newest first)
    
    // Save to local storage
    await _saveLogs();
  }

  // Public logging methods
  static Future<void> debug(String message, [String? source]) async {
    await initialize();
    if (kDebugMode) {
      developer.log('🐛 $message', name: source ?? 'DEBUG');
    }
    await _instance._addLog(message, 'DEBUG', source);
  }

  static Future<void> info(String message, [String? source]) async {
    await initialize();
    if (kDebugMode) {
      developer.log('ℹ️ $message', name: source ?? 'INFO');
    }
    await _instance._addLog(message, 'INFO', source);
  }

  static Future<void> warning(String message, [String? source]) async {
    await initialize();
    if (kDebugMode) {
      developer.log('⚠️ $message', name: source ?? 'WARNING');
    }
    await _instance._addLog(message, 'WARNING', source);
  }

  static Future<void> error(String message, [String? source]) async {
    await initialize();
    if (kDebugMode) {
      developer.log('❌ $message', name: source ?? 'ERROR');
    }
    await _instance._addLog(message, 'ERROR', source);
  }

  // Convenient method to replace print statements
  static Future<void> print(String message, [String? source]) async {
    await debug(message, source);
  }

  // Get all logs
  static Future<List<LogEntry>> getLogs() async {
    await initialize();
    return List.from(_instance._logs);
  }

  // Clear all logs
  static Future<void> clearLogs() async {
    await initialize();
    _instance._logs.clear();
    await _instance._saveLogs();
  }

  // Get logs by level
  static Future<List<LogEntry>> getLogsByLevel(String level) async {
    final logs = await getLogs();
    return logs.where((log) => log.level == level).toList();
  }

  // Get logs from specific source
  static Future<List<LogEntry>> getLogsBySource(String source) async {
    final logs = await getLogs();
    return logs.where((log) => log.source == source).toList();
  }

  // Get logs count
  static Future<int> getLogsCount() async {
    final logs = await getLogs();
    return logs.length;
  }

  // Export logs as string
  static Future<String> exportLogs() async {
    final logs = await getLogs();
    final buffer = StringBuffer();
    
    buffer.writeln('=== DEBUG LOGS EXPORT ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('');
    
    for (final log in logs) {
      buffer.writeln('[${log.level}] ${log.formattedTime} ${log.source ?? ''}: ${log.message}');
    }
    
    return buffer.toString();
  }
}