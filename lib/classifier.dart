import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MushroomClassifier {
  // Assets
  final String modelAsset;   // e.g. assets/models/model_dynamic_calib.tflite
  final String labelsAsset;  // fallback kalau class_names di config kosong
  final String configAsset;  // berisi class_names, img_size, thresholds, tta

  // Runtime
  late Interpreter _interpreter;
  late List<String> _labels;
  late int _inputH, _inputW;

  // Thresholds & options (safety-first)
  late double tauEdible;   // contoh default 0.95
  late double tauPoison;   // contoh default 0.70
  late double tauOod;      // OOD cutoff (maxProb < tauOod -> ABSTAIN)
  final double margin;     // p_edible - p_poison minimal untuk "EDIBLE?"
  late bool ttaEnabled;    // pakai TTA atau tidak
  late int ttaViews;       // jumlah view TTA (1..5)

  MushroomClassifier({
    this.modelAsset = 'assets/models/model_dynamic_calib.tflite',
    this.labelsAsset = 'assets/models/labels.txt',
    this.configAsset = 'assets/models/config.json',
    this.margin = 0.15,
  });

  Future<void> load() async {
    // --- config & labels ---
    final cfg = json.decode(await rootBundle.loadString(configAsset)) as Map<String, dynamic>;

    final classNames = (cfg['class_names'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (classNames.isNotEmpty) {
      _labels = classNames;
    } else {
      _labels = (await rootBundle.loadString(labelsAsset))
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final sz = (cfg['img_size'] as List<dynamic>? ?? [224, 224]);
    _inputH = (sz[0] as num).toInt();
    _inputW = (sz[1] as num).toInt();

    tauEdible = (cfg['tau_edible'] ?? 0.95).toDouble();
    tauPoison = (cfg['tau_poison'] ?? 0.70).toDouble();
    tauOod    = (cfg['tau_ood']    ?? 0.55).toDouble();

    final tta = (cfg['tta'] as Map?) ?? {};
    ttaEnabled = (tta['enabled'] ?? true) == true;
    ttaViews   = (tta['n'] ?? 5) is int ? (tta['n'] as int) : 5;
    ttaViews = ttaViews.clamp(1, 5);

    // --- interpreter ---
    _interpreter = await Interpreter.fromAsset(modelAsset);
  }

  // ---------- image utils ----------
  Uint8List _bytes(File f) => f.readAsBytesSync();

  img.Image _decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Cannot decode image');
    return decoded;
  }

  img.Image _resize(img.Image im) =>
      img.copyResize(im, width: _inputW, height: _inputH);

  /// Buat 5-view TTA: id, hflip, vflip, rot90, rot270 (dipangkas sesuai ttaViews)
  List<img.Image> _ttaViews(img.Image base) {
    final v0 = _resize(base);
    final v1 = _resize(img.flipHorizontal(base.clone()));
    final v2 = _resize(img.flipVertical(base.clone()));
    final v3 = _resize(img.copyRotate(base, angle: 90));
    final v4 = _resize(img.copyRotate(base, angle: 270));
    final all = [v0, v1, v2, v3, v4];
    return all.take(ttaViews).toList();
  }

  /// Konversi img.Image -> tensor [1,H,W,3] float32 0..255 (normalisasi sudah di model)
  List _toInput(img.Image rgb) {
    return [
      List.generate(_inputH, (y) {
        return List.generate(_inputW, (x) {
          final px = rgb.getPixel(x, y);
          return [px.r.toDouble(), px.g.toDouble(), px.b.toDouble()];
        });
      })
    ];
  }

  Future<ClassificationResult> classify(File imageFile) async {
    // decode sekali, generate views sesuai TTA
    final base = _decode(_bytes(imageFile));
    final views = ttaEnabled ? _ttaViews(base) : [_resize(base)];

    // jalankan semua view -> rata-ratakan probabilitas
    List<double>? sum;
    for (final v in views) {
      final input = _toInput(v);
      final out = List.generate(1, (_) => List.filled(_labels.length, 0.0));
      _interpreter.run(input, out);
      final probs = (out.first as List).cast<double>();
      if (sum == null) {
        sum = List<double>.from(probs);
      } else {
        for (int i = 0; i < sum.length; i++) sum[i] += probs[i];
      }
    }
    var probs = sum!.map((e) => e / views.length).toList();

    // normalisasi (jaga-jaga)
    final s = probs.fold<double>(0.0, (a, b) => a + b);
    if (s > 0) probs = probs.map((e) => e / s).toList();

    // ---------- OOD / low-confidence ----------
    final maxProb = probs.reduce(math.max);
    if (maxProb < tauOod) {
      return ClassificationResult(
        decision: 'ABSTAIN — OOD/low-confidence',
        probs: {
          for (int i = 0; i < _labels.length; i++)
            _labels[i]: double.parse(probs[i].toStringAsFixed(4))
        },
        thresholds: {
          'tau_edible': tauEdible,
          'tau_poison': tauPoison,
          'tau_ood': tauOod,
          'margin': margin,
          'tta_views': views.length.toDouble(),
        },
      );
    }

    // ---------- keputusan safety-first ----------
    // map index 'edible' & 'poisonous' dengan guard
    int iEd = _labels.indexOf('edible');
    int iPo = _labels.indexOf('poisonous');
    if (iEd < 0 || iPo < 0) {
      final lower = _labels.map((e) => e.toLowerCase()).toList();
      iEd = iEd < 0 ? lower.indexWhere((e) => e.contains('edible')) : iEd;
      iPo = iPo < 0 ? lower.indexWhere((e) => e.contains('poison')) : iPo;
    }
    if (iEd < 0 || iPo < 0 || probs.length != _labels.length) {
      // fallback dua kelas
      iEd = 0; iPo = 1;
    }

    final pEd = probs[iEd];
    final pPo = probs[iPo];

    String decision;
    if (pPo >= tauPoison && pPo > pEd) {
      decision = 'POISONOUS — JANGAN KONSUMSI';
    } else if (pEd >= tauEdible && (pEd - pPo) >= margin) {
      decision = 'EDIBLE? (baca peringatan)';
    } else {
      decision = 'ABSTAIN — Perlu verifikasi';
    }

    return ClassificationResult(
      decision: decision,
      probs: {
        for (int i = 0; i < _labels.length; i++)
          _labels[i]: double.parse(probs[i].toStringAsFixed(4))
      },
      thresholds: {
        'tau_edible': tauEdible,
        'tau_poison': tauPoison,
        'tau_ood': tauOod,
        'margin': margin,
        'tta_views': views.length.toDouble(),
      },
    );
  }

  void close() => _interpreter.close();
}

class ClassificationResult {
  final String decision;
  final Map<String, double> probs;
  final Map<String, double> thresholds;
  ClassificationResult({
    required this.decision,
    required this.probs,
    required this.thresholds,
  });
}
