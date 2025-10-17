// File: lib/main.dart
// Ganti seluruh isi file lib/main.dart dengan kode ini

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'classifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MushroomApp());
}

class MushroomApp extends StatelessWidget {
  const MushroomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mushroom Safety',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final picker = ImagePicker();
  MushroomClassifier? _clf;
  File? _image;
  String? _decision;
  Map<String, double>? _probs;
  Map<String, double>? _thr;
  bool _loading = false;
  bool _picking = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _initModel();
  }

  Future<void> _initModel() async {
    final clf = MushroomClassifier(
      modelAsset: 'assets/models/model_dynamic_calib.tflite',
      labelsAsset: 'assets/models/labels.txt',
      configAsset: 'assets/models/config.json',
    );
    await clf.load();
    setState(() => _clf = clf);
  }

  Future<void> _pickAndClassify(ImageSource src) async {
    if (_clf == null || _picking) return;
    _picking = true;
    try {
      final picked = await picker.pickImage(source: src, maxWidth: 2000);
      if (picked == null) return;

      setState(() {
        _loading = true;
        _image = File(picked.path);
        _decision = null;
        _probs = null;
        _thr = null;
      });

      final res = await _clf!.classify(_image!);

      setState(() {
        _loading = false;
        _decision = res.decision;
        _probs = res.probs;
        _thr = res.thresholds;
      });
      _animController.forward(from: 0);
    } finally {
      _picking = false;
    }
  }

  @override
  void dispose() {
    _clf?.close();
    _animController.dispose();
    super.dispose();
  }

  Color _getResultColor() {
    if (_decision == null) return Colors.grey;
    if (_decision!.startsWith('POISONOUS')) return const Color(0xFFD32F2F);
    if (_decision!.startsWith('EDIBLE')) return const Color(0xFF388E3C);
    return const Color(0xFFF57C00);
  }

  IconData _getResultIcon() {
    if (_decision == null) return Icons.help_outline;
    if (_decision!.startsWith('POISONOUS')) return Icons.dangerous_rounded;
    if (_decision!.startsWith('EDIBLE')) return Icons.check_circle_rounded;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonsDisabled = _loading || _picking;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.science_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Mushroom Safety', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Image Display Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _image != null ? 280 : 200,
              child: Card(
                color: theme.colorScheme.surfaceContainer,
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _image!,
                              fit: BoxFit.cover,
                            ),
                            if (_loading)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No image selected',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    onPressed: buttonsDisabled
                        ? null
                        : () => _pickAndClassify(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Camera'),
                    onPressed: buttonsDisabled
                        ? null
                        : () => _pickAndClassify(ImageSource.camera),
                  ),
                ),
              ],
            ),

            if (_loading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                borderRadius: BorderRadius.circular(8),
              ),
            ],

            // Results Section
            if (_decision != null) ...[
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Main Result Card
                    Card(
                      color: _getResultColor().withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              _getResultIcon(),
                              size: 64,
                              color: _getResultColor(),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _decision!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getResultColor(),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confidence Details Card
                    if (_probs != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.analytics_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Confidence Analysis',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ..._probs!.entries.map((e) {
                                final pct = e.value * 100;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            e.key.toUpperCase(),
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${pct.toStringAsFixed(1)}%',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: e.value,
                                          minHeight: 8,
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation(
                                            e.key.toLowerCase().contains('poison')
                                                ? const Color(0xFFD32F2F)
                                                : const Color(0xFF388E3C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Technical Details Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.settings_rounded,
                                    size: 20,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Model Parameters',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_thr != null) ...[
                                _buildInfoRow(
                                  'Edible Threshold',
                                  '${(_thr!['tau_edible']! * 100).toStringAsFixed(0)}%',
                                  Icons.check_circle_outline,
                                ),
                                _buildInfoRow(
                                  'Poison Threshold',
                                  '${(_thr!['tau_poison']! * 100).toStringAsFixed(0)}%',
                                  Icons.warning_amber_rounded,
                                ),
                                _buildInfoRow(
                                  'Safety Margin',
                                  '${((_thr!['margin'] ?? 0.15) * 100).toStringAsFixed(0)}%',
                                  Icons.security_rounded,
                                ),
                                _buildInfoRow(
                                  'TTA Views',
                                  '${_thr!['tta_views']!.toInt()}x',
                                  Icons.view_carousel_rounded,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Warning Card
                    Card(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: theme.colorScheme.error,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI predictions are assistive only. When in doubt, always abstain. Your safety is the priority.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Info Section (when no results)
            if (_decision == null && !_loading) ...[
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'How It Works',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload or capture a mushroom image. Our AI model will analyze it using advanced TensorFlow Lite technology to determine if it\'s edible or poisonous.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildFeatureChip(Icons.speed_rounded, 'Fast', theme),
                          _buildFeatureChip(Icons.security_rounded, 'Safe', theme),
                          _buildFeatureChip(Icons.offline_bolt_rounded, 'Offline', theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, ThemeData theme) {
    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label),
      backgroundColor: theme.colorScheme.primaryContainer,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}