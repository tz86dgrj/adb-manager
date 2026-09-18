import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AdbToolsCard extends StatefulWidget {
  final AppState state;

  const AdbToolsCard({
    super.key,
    required this.state,
  });

  @override
  State<AdbToolsCard> createState() => _AdbToolsCardState();
}

class _AdbToolsCardState extends State<AdbToolsCard> {
  bool _showDeepLink = false;
  final TextEditingController _deepLinkController = TextEditingController();

  @override
  void dispose() {
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _pushClipboardToDevice() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Windows clipboard is empty.')),
        );
      }
      return;
    }
    await widget.state.sendClipboardToDevice(text);
  }

  Future<void> _sideloadApk() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select APK file to install on device',
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      final apkPath = result.first.path!;
      await widget.state.installApkToActiveDevice(apkPath);
    }
  }

  Future<void> _fireDeepLink() async {
    final url = _deepLinkController.text.trim();
    if (url.isEmpty) return;
    await widget.state.launchDeepLink(url);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasDevice = state.selectedDeviceId != null;
    final pkg = state.detectedPackageName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'ADB Productivity Tools',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (pkg != null)
                  Tooltip(
                    message: 'Auto-detected active project package name',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        pkg,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tools Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Clear App Data
                OutlinedButton.icon(
                  onPressed: hasDevice && pkg != null ? () => state.clearAppData() : null,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 15, color: AppTheme.warning),
                  label: const Text('Clear Data'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Send Clipboard Text
                OutlinedButton.icon(
                  onPressed: hasDevice ? _pushClipboardToDevice : null,
                  icon: const Icon(Icons.paste_rounded, size: 15, color: AppTheme.primary),
                  label: const Text('Push Clipboard'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Sideload APK
                OutlinedButton.icon(
                  onPressed: hasDevice ? _sideloadApk : null,
                  icon: const Icon(Icons.install_mobile_rounded, size: 15, color: AppTheme.success),
                  label: const Text('Install APK...'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Deep Link Toggle
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => setState(() => _showDeepLink = !_showDeepLink) : null,
                  icon: Icon(_showDeepLink ? Icons.expand_less_rounded : Icons.link_rounded, size: 15, color: AppTheme.primary),
                  label: Text(_showDeepLink ? 'Hide Deep Link' : 'Deep Link'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    backgroundColor: _showDeepLink ? AppTheme.primarySubtle : null,
                  ),
                ),

                // Light Mode
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => state.toggleDeviceDarkMode(false) : null,
                  icon: const Icon(Icons.light_mode_rounded, size: 15, color: AppTheme.warning),
                  label: const Text('Light'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Dark Mode
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => state.toggleDeviceDarkMode(true) : null,
                  icon: const Icon(Icons.dark_mode_rounded, size: 15, color: AppTheme.textSecondary),
                  label: const Text('Dark'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Screenshot
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => state.captureScreenshot() : null,
                  icon: const Icon(Icons.camera_alt_rounded, size: 15, color: AppTheme.primary),
                  label: const Text('Screenshot'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Home Key
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => state.adbService.sendKeyEvent(state.selectedDeviceId!, 3) : null,
                  icon: const Icon(Icons.home_rounded, size: 15),
                  label: const Text('Home'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),

                // Back Key
                OutlinedButton.icon(
                  onPressed: hasDevice ? () => state.adbService.sendKeyEvent(state.selectedDeviceId!, 4) : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 15),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),

            // Deep Link Expansion Panel
            if (_showDeepLink && hasDevice) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deep Link / Intent Dispatcher',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _deepLinkController,
                              style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                              decoration: const InputDecoration(
                                hintText: 'e.g. myapp://login?token=abc or https://...',
                                hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _fireDeepLink,
                          icon: const Icon(Icons.send_rounded, size: 13),
                          label: const Text('Fire Intent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Quick Prefixes: ', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        InkWell(
                          onTap: () {
                            if (pkg != null) {
                              _deepLinkController.text = '$pkg://';
                            } else {
                              _deepLinkController.text = 'myapp://';
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              pkg != null ? '$pkg://' : 'myapp://',
                              style: const TextStyle(fontSize: 10, fontFamily: 'Consolas', color: AppTheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _deepLinkController.text = 'https://',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: const Text(
                              'https://',
                              style: TextStyle(fontSize: 10, fontFamily: 'Consolas', color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
