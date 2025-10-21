import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'classifier.dart';

class AppColors {
  static const Color primary = Color(0xFF00B14F);
  static const Color secondary = Color(0xFF4DD67B);
  static const Color accent = Color(0xFF8DE7B0);
  static const Color background = Color(0xFFF6FAF7);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFE8F6EE);
  static const Color textPrimary = Color(0xFF102A19);
  static const Color textSecondary = Color(0xFF536363);
  static const Color border = Color(0xFFE0E8E3);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MushroomApp());
}

class MushroomApp extends StatelessWidget {
  const MushroomApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mushroom Safety',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.light().textTheme.apply(
                bodyColor: AppColors.textPrimary,
                displayColor: AppColors.textPrimary,
              ),
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final picker = ImagePicker();
  MushroomClassifier? _clf;
  File? _image;
  String? _decision;
  Map<String, double>? _probs;
  bool _loading = false;
  bool _picking = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      final clf = MushroomClassifier(
        modelAsset: 'assets/models/model_dynamic_calib.tflite',
        labelsAsset: 'assets/models/labels.txt',
        configAsset: 'assets/models/config.json',
      );
      await clf.load();
      setState(() => _clf = clf);
    } catch (e) {
      _showErrorSnackBar('Gagal memuat model AI: $e');
    }
  }

  Future<void> _pickAndClassify(ImageSource src) async {
    if (_clf == null || _picking) return;
    
    setState(() => _picking = true);
    
    try {
      final picked = await picker.pickImage(
        source: src,
        maxWidth: 2000,
        imageQuality: 90,
      );
      
      if (picked == null) {
        setState(() => _picking = false);
        return;
      }

      setState(() {
        _loading = true;
        _image = File(picked.path);
        _decision = null;
        _probs = null;
        _picking = false;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      final res = await _clf!.classify(_image!);

      setState(() {
        _loading = false;
        _decision = res.decision;
        _probs = res.probs;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _picking = false;
      });
      _showErrorSnackBar('Gagal memproses gambar: $e');
    }
  }

  void _resetImage() {
    setState(() {
      _image = null;
      _decision = null;
      _probs = null;
      _loading = false;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _clf?.close();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getResultColor() {
    if (_decision == null) return Colors.grey;
    if (_decision!.contains('BERACUN') || _decision!.contains('POISONOUS')) {
      return AppColors.danger;
    }
    if (_decision!.contains('AMAN') || _decision!.contains('EDIBLE')) {
      return AppColors.primary;
    }
    return AppColors.warning;
  }

  IconData _getResultIcon() {
    if (_decision == null) return Icons.help_outline;
    if (_decision!.contains('BERACUN') || _decision!.contains('POISONOUS')) {
      return Icons.dangerous_rounded;
    }
    if (_decision!.contains('AMAN') || _decision!.contains('EDIBLE')) {
      return Icons.check_circle_rounded;
    }
    return Icons.warning_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final buttonsDisabled = _loading || _picking;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildGlassmorphicHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModernImagePreview(size),
                        const SizedBox(height: 28),
                        _buildModernActionButtons(buttonsDisabled),
                        if (_decision != null) ...[
                          const SizedBox(height: 32),
                          _buildEnhancedResults(),
                        ],
                        if (_decision == null && !_loading) ...[
                          const SizedBox(height: 32),
                          _buildEnhancedInfoSection(),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      color: AppColors.background,
    );
  }

  Widget _buildGlassmorphicHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const InfoPage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.15, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceAlt,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Deteksi Jamur AI',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifikasi keamanan jamur menggunakan kecerdasan buatan.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0);
  }

  Widget _buildModernImagePreview(Size size) {
    return Container(
      width: double.infinity,
      height: size.height * 0.38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: _image != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      _image!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (!_loading)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _resetImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ).animate().scale(delay: 200.ms, duration: 300.ms),
                    ),
                  if (_loading)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  strokeWidth: 5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Menganalisis gambar...',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'AI sedang memproses data...',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 14,
                                color: AppColors.textSecondary,
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
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseController.value * 0.15);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.12 + (_pulseController.value * 0.08)),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 72,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Pilih atau Ambil Foto',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Foto jamur yang jelas untuk hasil terbaik',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildModernActionButtons(bool disabled) {
    return Row(
      children: [
        Expanded(
          child: _EnhancedButton(
            icon: Icons.collections_rounded,
            label: 'Galeri',
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            borderColor: AppColors.border,
            onPressed: disabled ? null : () => _pickAndClassify(ImageSource.gallery),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _EnhancedButton(
            icon: Icons.camera_alt_rounded,
            label: 'Kamera',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: disabled ? null : () => _pickAndClassify(ImageSource.camera),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildEnhancedWarningCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withValues(alpha: 0.12 + (_pulseController.value * 0.06)),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: AppColors.warning,
                  size: 26,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peringatan Penting',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI hanya alat bantu. Selalu konsultasikan dengan ahli jamur profesional sebelum mengonsumsi jamur apa pun.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: 0.08, end: 0);
  }

  Widget _buildEnhancedInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fitur Unggulan',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            const _EnhancedFeatureCard(
              icon: Icons.flash_on_rounded,
              title: 'Cepat',
              subtitle: 'Analisis instan',
              colors: [AppColors.primary, AppColors.secondary],
              delay: 0,
            ),
            const _EnhancedFeatureCard(
              icon: Icons.shield_rounded,
              title: 'Aman',
              subtitle: 'Terlatih ahli',
              colors: [AppColors.secondary, AppColors.accent],
              delay: 100,
            ),
            _EnhancedFeatureCard(
              icon: Icons.offline_bolt_rounded,
              title: 'Offline',
              subtitle: 'Tanpa internet',
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, AppColors.secondary, 0.5)!,
              ],
              delay: 200,
            ),
            _EnhancedFeatureCard(
              icon: Icons.psychology_rounded,
              title: 'AI Power',
              subtitle: 'TensorFlow Lite',
              colors: [
                AppColors.secondary,
                Color.lerp(AppColors.secondary, AppColors.accent, 0.6)!,
              ],
              delay: 300,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildEnhancedTipsCard(),
      ],
    );
  }

  Widget _buildEnhancedTipsCard() {
    final tips = [
      'Ambil foto yang jelas dan terang',
      'Foto dari berbagai sudut',
      'Sertakan tudung, insang & batang',
      'Jangan konsumsi tanpa verifikasi ahli'
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Tips Penggunaan',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...tips.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceAlt,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: Duration(milliseconds: 400 + (entry.key * 100)))
                .fadeIn(duration: 400.ms)
                .slideX(begin: -0.2, end: 0);
          }),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildEnhancedResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hasil Analisis',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.surface,
            border: Border.all(
              color: _getResultColor().withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: _getResultColor().withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getResultColor().withValues(alpha: 0.12 + (_pulseController.value * 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: _getResultColor().withValues(alpha: 0.18 + (_pulseController.value * 0.12)),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getResultIcon(),
                      size: 64,
                      color: _getResultColor(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                _translateDecision(_decision!),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tingkat risiko dihitung otomatis oleh model AI.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
            ),
        if (_probs != null) ...[
          const SizedBox(height: 20),
          _buildEnhancedConfidenceCard(),
        ],
        const SizedBox(height: 20),
        _buildEnhancedWarningCard(),
      ],
    );
  }

  String _translateDecision(String decision) {
    if (decision.contains('POISONOUS')) {
      return 'BERACUN - JANGAN KONSUMSI!';
    } else if (decision.contains('EDIBLE')) {
      return 'AMAN? (Baca peringatan di bawah)';
    } else if (decision.contains('ABSTAIN')) {
      return 'TIDAK YAKIN - Perlu Verifikasi Ahli';
    }
    return decision;
  }

  Widget _buildEnhancedConfidenceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tingkat Kepercayaan',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._probs!.entries.map((entry) {
            final percent = entry.value * 100;
            final isPoison = entry.key.toLowerCase().contains('poison');
            final label = isPoison ? 'BERACUN' : 'AMAN';
            final color = isPoison ? AppColors.danger : AppColors.primary;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 12,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideX(begin: -0.1, end: 0);
  }
}

class _EnhancedButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  const _EnhancedButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onPressed,
  });

  @override
  State<_EnhancedButton> createState() => _EnhancedButtonState();
}

class _EnhancedButtonState extends State<_EnhancedButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null;
    final Color bg = disabled
        ? Color.lerp(widget.backgroundColor, AppColors.border, 0.5)!
        : widget.backgroundColor;
    final Color fg = disabled
        ? Color.lerp(widget.foregroundColor, AppColors.textSecondary, 0.5)!
        : widget.foregroundColor;

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!, width: 1.2)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: fg,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EnhancedFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final int delay;

  const _EnhancedFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: Text(
          'Tentang Aplikasi',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoCard(
                icon: Icons.eco_rounded,
                title: 'Mushroom Safety',
                description:
                    'Aplikasi ini memanfaatkan model TensorFlow Lite untuk membantu menilai jamur dari foto. Fokus utama kami tetap pada keselamatan pengguna.',
              ),
              const SizedBox(height: 16),
              _infoCard(
                icon: Icons.psychology_rounded,
                title: 'Cara Kerja',
                description:
                    'Model AI menganalisis beberapa augmentasi gambar (Test-Time Augmentation) untuk memperoleh tingkat kepercayaan terbaik sebelum memberikan keputusan.',
              ),
              const SizedBox(height: 16),
              _infoCard(
                icon: Icons.warning_rounded,
                title: 'Disarankan Tetap Konsultasi',
                description:
                    'Keputusan AI tidak menggantikan pakar jamur. Pastikan selalu berkonsultasi dengan ahli mikologi sebelum mengonsumsi jamur apa pun.',
                isWarning: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
    bool isWarning = false,
  }) {
    final gradientColors = isWarning
        ? [const Color(0xFFFFF6E6), const Color(0xFFFFE4D6)]
        : [const Color(0xFFF5FFFA), const Color(0xFFE8FFF0)];

    final iconColor = isWarning ? AppColors.warning : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: (isWarning ? AppColors.warning : AppColors.primary)
              .withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}