import 'package:flutter/material.dart';
import '../models/avd_creation_options.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class CreateAvdDialog extends StatefulWidget {
  final AppState state;

  const CreateAvdDialog({super.key, required this.state});

  @override
  State<CreateAvdDialog> createState() => _CreateAvdDialogState();
}

class _CreateAvdDialogState extends State<CreateAvdDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  List<DeviceProfile> _devices = [];
  List<SystemImageInfo> _systemImages = [];

  String? _selectedDeviceId;
  String? _selectedImagePackage;
  int _selectedRamMb = 4096;
  int _selectedStorageMb = 6144;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoading = true);

    try {
      final images = await widget.state.avdService.listInstalledSystemImages();
      final devices = await widget.state.avdService.listDeviceProfiles();

      setState(() {
        _systemImages = images;
        _devices = devices;
        if (devices.isNotEmpty) {
          // Default to pixel_7_pro, pixel_7, or first device
          final preferred = devices.firstWhere(
            (d) => d.id == 'pixel_7_pro' || d.id == 'pixel_7' || d.id == 'pixel_6',
            orElse: () => devices.first,
          );
          _selectedDeviceId = preferred.id;
        }

        if (images.isNotEmpty) {
          _selectedImagePackage = images.first.packagePath;
        }

        _updateDefaultName();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to scan SDK system images: $e';
      });
    }
  }

  void _updateDefaultName() {
    if (_nameController.text.isNotEmpty && !_nameController.text.startsWith('Pixel') && !_nameController.text.startsWith('Device')) {
      return;
    }

    final devName = _selectedDeviceId ?? 'Device';
    final sanitizedDev = devName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    String apiTag = 'API';
    if (_selectedImagePackage != null) {
      final match = RegExp(r'android-([0-9.]+)').firstMatch(_selectedImagePackage!);
      if (match != null) {
        apiTag = 'API_${match.group(1)!.replaceAll('.', '_')}';
      }
    }

    _nameController.text = '${sanitizedDev}_$apiTag';
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeviceId == null || _selectedImagePackage == null) {
      setState(() => _errorMessage = 'Please select a device profile and system image.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final result = await widget.state.createAvd(
      name: name,
      deviceProfileId: _selectedDeviceId!,
      systemImagePackage: _selectedImagePackage!,
      ramMb: _selectedRamMb,
      internalStorageMb: _selectedStorageMb,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Virtual Device "$name" created successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isCreating = false;
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.phonelink_setup_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Android Virtual Device (AVD)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Direct native hardware definition & system image creation without Android Studio.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            // 2. Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                            SizedBox(height: 16),
                            Text(
                              'Scanning Android SDK system images & device profiles...',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // AVD Name Field
                            const Text(
                              'Virtual Device Name',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isCreating,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Pixel_7_API34',
                                prefixIcon: Icon(Icons.edit_rounded, size: 16),
                                helperText: 'Use letters, numbers, and underscores (no spaces).',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Device name is required.';
                                }
                                if (val.contains(' ')) {
                                  return 'Spaces are not allowed in AVD names. Use underscores.';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(val)) {
                                  return 'Only alphanumeric characters and underscores are permitted.';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Hardware Profile Selector
                            const Text(
                              'Hardware Device Profile',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDeviceId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.smartphone_rounded, size: 16),
                              ),
                              items: _devices.map((device) {
                                return DropdownMenuItem<String>(
                                  value: device.id,
                                  child: Text(
                                    '${device.name} [${device.oem}]',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _isCreating
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedDeviceId = val;
                                          _updateDefaultName();
                                        });
                                      }
                                    },
                            ),

                            const SizedBox(height: 16),

                            // Android System Image Selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Android System Image (OS Version)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  '${_systemImages.length} installed',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_systemImages.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No system images detected in your Android SDK.\nPlease download a system image using SDK Manager first.',
                                        style: TextStyle(fontSize: 12, color: AppTheme.warning),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedImagePackage,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.android_rounded, size: 16),
                                ),
                                items: _systemImages.map((img) {
                                  return DropdownMenuItem<String>(
                                    value: img.packagePath,
                                    child: Text(
                                      img.displayName,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isCreating
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedImagePackage = val;
                                            _updateDefaultName();
                                          });
                                        }
                                      },
                              ),

                            const SizedBox(height: 16),

                            // Hardware Sizing (RAM & Internal Storage)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'RAM Allocation',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<int>(
                                        initialValue: _selectedRamMb,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(Icons.memory_rounded, size: 16),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 2048, child: Text('2048 MB (2 GB)')),
                                          DropdownMenuItem(value: 4096, child: Text('4096 MB (4 GB - Fast)')),
                                          DropdownMenuItem(value: 8192, child: Text('8192 MB (8 GB)')),
                                        ],
                                        onChanged: _isCreating ? null : (v) => setState(() => _selectedRamMb = v ?? 4096),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Internal Storage',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<int>(
                                        initialValue: _selectedStorageMb,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          prefixIcon: Icon(Icons.sd_storage_rounded, size: 16),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 4096, child: Text('4 GB')),
                                          DropdownMenuItem(value: 6144, child: Text('6 GB (Standard)')),
                                          DropdownMenuItem(value: 8192, child: Text('8 GB')),
                                          DropdownMenuItem(value: 12288, child: Text('12 GB (Large)')),
                                        ],
                                        onChanged: _isCreating ? null : (v) => setState(() => _selectedStorageMb = v ?? 6144),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // 3. Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceMuted,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: (_isCreating || _isLoading || _systemImages.isEmpty) ? null : _handleCreate,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 16),
                    label: Text(_isCreating ? 'Creating Device...' : 'Create Virtual Device'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
