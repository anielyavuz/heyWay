import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/debug_logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> _logs = [];
  List<LogEntry> _filteredLogs = [];
  String _selectedLevel = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;

  final List<String> _logLevels = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    
    try {
      final logs = await DebugLogger.getLogs();
      setState(() {
        _logs = logs;
        _filteredLogs = logs;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<LogEntry> filtered = _logs;

    // Filter by level
    if (_selectedLevel != 'ALL') {
      filtered = filtered.where((log) => log.level == _selectedLevel).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((log) =>
          log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (log.source?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    setState(() {
      _filteredLogs = filtered;
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to delete all logs? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DebugLogger.clearLogs();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared successfully')),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final logsText = await DebugLogger.exportLogs();
      await Clipboard.setData(ClipboardData(text: logsText));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs exported to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Logs (${_filteredLogs.length})'),
        actions: [
          IconButton(
            onPressed: _exportLogs,
            icon: const Icon(Icons.copy),
            tooltip: 'Export to Clipboard',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
          ),
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search logs...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                // Level filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _logLevels.map((level) {
                      final isSelected = _selectedLevel == level;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(level),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedLevel = level;
                            });
                            _applyFilters();
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: _getLogLevelColor(level),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _logs.isEmpty ? 'No logs yet' : 'No logs match filters',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _logs.isEmpty 
                                  ? 'Debug logs will appear here'
                                  : 'Try adjusting your search or filters',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return LogEntryCard(log: log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red[100]!;
      case 'WARNING':
        return Colors.orange[100]!;
      case 'INFO':
        return Colors.blue[100]!;
      case 'DEBUG':
        return Colors.green[100]!;
      default:
        return Colors.grey[200]!;
    }
  }
}

class LogEntryCard extends StatelessWidget {
  const LogEntryCard({super.key, required this.log});

  final LogEntry log;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _showLogDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with level, time, and source
              Row(
                children: [
                  // Level badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLogLevelColor(log.level),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      log.level,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getLogLevelTextColor(log.level),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time
                  Text(
                    log.formattedTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (log.source != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.source!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  // Tap icon
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Message
              Text(
                log.message,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getLogLevelColor(log.level),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.level,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getLogLevelTextColor(log.level),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Log Details',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Time', log.timestamp.toString()),
              if (log.source != null) _buildDetailRow('Source', log.source!),
              _buildDetailRow('Level', log.level),
              const SizedBox(height: 12),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  log.message,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: log.message));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log message copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Message'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red[100]!;
      case 'WARNING':
        return Colors.orange[100]!;
      case 'INFO':
        return Colors.blue[100]!;
      case 'DEBUG':
        return Colors.green[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getLogLevelTextColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red[800]!;
      case 'WARNING':
        return Colors.orange[800]!;
      case 'INFO':
        return Colors.blue[800]!;
      case 'DEBUG':
        return Colors.green[800]!;
      default:
        return Colors.grey[800]!;
    }
  }
}