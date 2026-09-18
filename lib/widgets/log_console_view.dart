import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/log_entry.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class LogConsoleView extends StatefulWidget {
  final AppState state;

  const LogConsoleView({super.key, required this.state});

  @override
  State<LogConsoleView> createState() => _LogConsoleViewState();
}

class _LogConsoleViewState extends State<LogConsoleView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      widget.state.setLogFilter(_searchController.text);
    });
  }

  @override
  void didUpdateWidget(covariant LogConsoleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> _filterLogs(List<LogEntry> allLogs) {
    final query = widget.state.logFilter.toLowerCase();
    return allLogs.where((log) {
      if (_activeFilter == 'flutter' && log.source != 'flutter') return false;
      if (_activeFilter == 'build' && log.source != 'build') return false;
      if (_activeFilter == 'system' &&
          log.source != 'system' &&
          log.source != 'adb' &&
          log.source != 'bridge') {
        return false;
      }
      if (_activeFilter == 'errors' && log.level != LogLevel.error) return false;

      if (query.isNotEmpty) {
        return log.message.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.state.selectedDeviceId;
    final isSystemView = selectedId == null;

    final List<LogEntry> sourceLogs;
    if (isSystemView) {
      sourceLogs = widget.state.logs;
    } else {
      sourceLogs = widget.state.activeSession?.logs ?? [];
    }

    final logs = _filterLogs(sourceLogs);
    final debugUri = widget.state.debugUri;

    return Container(
      color: AppTheme.consoleBackground,
      child: Column(
        children: [
          // Console Toolbar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  selectedId != null
                      ? 'Console & Logs ($selectedId)'
                      : 'Console & Logs (System & Builds)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${logs.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Filter chips
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 4),
                _buildFilterChip('flutter', 'Flutter'),
                const SizedBox(width: 4),
                _buildFilterChip('build', 'Build'),
                const SizedBox(width: 4),
                _buildFilterChip('system', 'System'),
                const SizedBox(width: 4),
                _buildFilterChip('errors', 'Errors'),

                const Spacer(),

                // Search box
                SizedBox(
                  width: 200,
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
                      prefixIconConstraints: const BoxConstraints(minWidth: 28),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              onPressed: () => _searchController.clear(),
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

                const SizedBox(width: 8),

                // Auto-scroll toggle
                Tooltip(
                  message: 'Auto-scroll on new log lines',
                  child: InkWell(
                    onTap: () => widget.state.setAutoScroll(!widget.state.autoScroll),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.vertical_align_bottom_rounded,
                        size: 18,
                        color: widget.state.autoScroll ? AppTheme.primary : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),

                // Copy all logs
                Tooltip(
                  message: 'Copy logs to clipboard',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    color: AppTheme.textSecondary,
                    onPressed: () {
                      final text = logs.map((l) => l.message).join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),

                // Clear console
                Tooltip(
                  message: selectedId != null
                      ? 'Clear logs for $selectedId'
                      : 'Clear system & build logs',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: AppTheme.textSecondary,
                    onPressed: () => widget.state.clearLogs(deviceId: selectedId),
                  ),
                ),
              ],
            ),
          ),

          // Observatory Banner if available
          if (debugUri != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.primarySubtle,
              child: Row(
                children: [
                  const Icon(Icons.bug_report_rounded, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Dart DevTools & Observatory: $debugUri',
                    style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', color: AppTheme.primary),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: debugUri));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('DevTools URI copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Text(
                      'Copy URL',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),

          // Console Log Lines
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      selectedId != null
                          ? 'No logs recorded for $selectedId yet.\nClick "Run App" above to launch on this device.'
                          : 'No system or build logs recorded yet.\nRun an APK build or execute an ADB tool action.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.5),
                    ),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final entry = logs[index];
                        return _buildLogLine(entry);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _activeFilter == id;
    return InkWell(
      onTap: () => setState(() => _activeFilter = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLogLine(LogEntry entry) {
    Color textColor;
    switch (entry.level) {
      case LogLevel.error:
        textColor = AppTheme.consoleError;
        break;
      case LogLevel.warning:
        textColor = AppTheme.consoleWarning;
        break;
      case LogLevel.success:
        textColor = AppTheme.consoleSuccess;
        break;
      case LogLevel.system:
        textColor = AppTheme.consoleSystem;
        break;
      case LogLevel.info:
        textColor = AppTheme.consoleText;
        break;
    }

    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              entry.source.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
