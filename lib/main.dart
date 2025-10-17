// File: lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'classifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
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
          seedColor: const Color(0xFF00AA13), // Gojek Green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final picker = ImagePicker();
  MushroomClassifier? _clf;
  File? _image;
  String? _decision;
  Map<String, double>? _probs;
  Map<String, double>? _thr;
  bool _loading = false;
  bool _picking = false;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
      _bounceController.forward(from: 0);
    } finally {
      _picking = false;
    }
  }

  @override
  void dispose() {
    _clf?.close();
    _bounceController.dispose();
    super.dispose();
  }

  Color _getResultColor() {
    if (_decision == null) return Colors.grey;
    if (_decision!.startsWith('POISONOUS')) return const Color(0xFFE53935);
    if (_decision!.startsWith('EDIBLE')) return const Color(0xFF00AA13);
    return const Color(0xFFFF6F00);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonsDisabled = _loading || _picking;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar - Gojek Style
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00AA13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mushroom Safety',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1C),
                        ),
                      ),
                      Text(
                        'AI-powered identification',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InfoPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 28),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF00AA13),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Image Card - Mobile Friendly
                    Container(
                      width: double.infinity,
                      height: size.height * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _image != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    _image!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                if (_loading)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Shimmer.fromColors(
                                            baseColor: Colors.white54,
                                            highlightColor: Colors.white,
                                            child: const Icon(
                                              Icons.psychology_outlined,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Analyzing...',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 72,
                                    color: Colors.grey[300],
                                  )
                                      .animate(onPlay: (controller) =>
                                          controller.repeat())
                                      .fade(duration: 1500.ms)
                                      .scale(
                                          begin: const Offset(0.9, 0.9),
                                          end: const Offset(1, 1),
                                          duration: 1500.ms),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tap button below',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons - Gojek Style
                    Row(
                      children: [
                        Expanded(
                          child: _GojekButton(
                            icon: Icons.collections_outlined,
                            label: 'Gallery',
                            onPressed: buttonsDisabled
                                ? null
                                : () => _pickAndClassify(ImageSource.gallery),
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GojekButton(
                            icon: Icons.camera_alt_outlined,
                            label: 'Camera',
                            onPressed: buttonsDisabled
                                ? null
                                : () => _pickAndClassify(ImageSource.camera),
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),

                    // Results Section
                    if (_decision != null) ...[
                      const SizedBox(height: 24),
                      _buildResults(),
                    ],

                    // Info Cards when no result
                    if (_decision == null && !_loading) ...[
                      const SizedBox(height: 24),
                      _buildInfoCards(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Result Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _getResultColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getResultColor().withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getResultColor().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _decision!.startsWith('POISONOUS')
                      ? Icons.dangerous_outlined
                      : _decision!.startsWith('EDIBLE')
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                  size: 64,
                  color: _getResultColor(),
                ),
              )
                  .animate(controller: _bounceController)
                  .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 800.ms)
                  .fade(),
              const SizedBox(height: 16),
              Text(
                _decision!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _getResultColor(),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),

        if (_probs != null) ...[
          const SizedBox(height: 16),
          _buildConfidenceCard(),
        ],

        const SizedBox(height: 16),
        _buildWarningCard(),
      ],
    );
  }

  Widget _buildConfidenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF00AA13),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Confidence Level',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._probs!.entries.map((e) {
            final pct = e.value * 100;
            final isPoison = e.key.toLowerCase().contains('poison');
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
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPoison
                              ? const Color(0xFFE53935)
                              : const Color(0xFF00AA13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: e.value,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        isPoison
                            ? const Color(0xFFE53935)
                            : const Color(0xFF00AA13),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6F00).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            color: Color(0xFFFF6F00),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI is assistive only. Always consult an expert when in doubt.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF5D4037),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        // Features Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _FeatureCard(
              icon: Icons.flash_on_outlined,
              title: 'Fast',
              subtitle: 'Instant analysis',
              color: const Color(0xFFFF9800),
            ),
            _FeatureCard(
              icon: Icons.shield_outlined,
              title: 'Safe',
              subtitle: 'Expert trained',
              color: const Color(0xFF00AA13),
            ),
            _FeatureCard(
              icon: Icons.offline_bolt_outlined,
              title: 'Offline',
              subtitle: 'No internet needed',
              color: const Color(0xFF2196F3),
            ),
            _FeatureCard(
              icon: Icons.psychology_outlined,
              title: 'AI-Powered',
              subtitle: 'TensorFlow Lite',
              color: const Color(0xFF9C27B0),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tips Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00AA13), Color(0xFF008A0E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Pro Tips',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...[
                'Take clear, well-lit photos',
                'Capture multiple angles',
                'Include cap, gills & stem',
                'Never consume without expert verification'
              ].map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// Gojek Style Button
class _GojekButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _GojekButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? const Color(0xFF00AA13) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isPrimary ? 0 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : const Color(0xFF00AA13),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : const Color(0xFF00AA13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Feature Card
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Info Page
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Information',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF00AA13),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              icon: Icons.info_outline,
              title: 'About This App',
              content:
                  'Mushroom Safety uses advanced AI (TensorFlow Lite) to help identify whether mushrooms are potentially edible or poisonous. This is an assistive tool only and should never replace expert consultation.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.psychology_outlined,
              title: 'How It Works',
              content:
                  'Our model analyzes mushroom images using Test-Time Augmentation (TTA) with multiple views (rotation, flipping) to improve accuracy. It applies safety-first thresholds to minimize false positives.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.warning_amber_outlined,
              title: 'Important Warning',
              content:
                  'Never consume any mushroom based solely on this app. Many poisonous mushrooms closely resemble edible ones. Always consult a professional mycologist or expert before consumption.',
              isWarning: true,
            ),
            const SizedBox(height: 20),
            _buildFactsCard(),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.science_outlined,
              title: 'Model Details',
              content:
                  '• Model: TFLite with dynamic quantization\n'
                  '• Input: 224x224 RGB images\n'
                  '• Classes: Edible & Poisonous\n'
                  '• Safety thresholds: 95% (edible), 70% (poison)\n'
                  '• TTA: 5-view augmentation',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFFFF3E0)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFFF6F00).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isWarning ? const Color(0xFFFF6F00) : const Color(0xFF00AA13),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00AA13), Color(0xFF008A0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Mushroom Facts',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            '🍄 14,000+ species worldwide',
            '⚠️ Only ~3% are poisonous',
            '🔬 100+ species cause serious illness',
            '💀 Some toxins have no antidote',
            '👨‍🔬 Always verify with experts'
          ].map(
            (fact) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                fact,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}