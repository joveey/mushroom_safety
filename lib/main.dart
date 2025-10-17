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
      title: 'Mushroom Safety (TFLite)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
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

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();
  MushroomClassifier? _clf;
  File? _image;
  String? _decision;
  Map<String, double>? _probs;
  Map<String, double>? _thr;
  bool _loading = false;
  bool _picking = false; // <<< blokir double tap

  @override
  void initState() {
    super.initState();
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
    } finally {
      _picking = false;
    }
  }

  @override
  void dispose() {
    _clf?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonsDisabled = _loading || _picking;

    return Scaffold(
      appBar: AppBar(title: const Text('Mushroom Safety (TFLite)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_image!, height: 220, fit: BoxFit.cover),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed: buttonsDisabled ? null : () => _pickAndClassify(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                    onPressed: buttonsDisabled ? null : () => _pickAndClassify(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_decision != null) ...[
              const SizedBox(height: 12),
              Text(
                _decision!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _decision!.startsWith('POISONOUS')
                      ? Colors.red
                      : _decision!.startsWith('EDIBLE')
                          ? Colors.green
                          : Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              if (_probs != null)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Probabilities', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        for (final e in _probs!.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('${e.key}: ${(e.value * 100).toStringAsFixed(2)}%'),
                          ),
                        const SizedBox(height: 8),
                        if (_thr != null)
                          Text('Thresholds → edible: ${_thr!['tau_edible']}, poison: ${_thr!['tau_poison']}, margin: ${_thr!['margin'] ?? 0.15}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'PERINGATAN: Hasil model asistif. Jika ragu, pilih ABSTAIN. Keselamatan prioritas.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
