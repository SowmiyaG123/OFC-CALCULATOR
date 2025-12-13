import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/rendering.dart';
import '../../html_stub.dart' if (dart.library.html) '../../html_real.dart'
    as html;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

// ---------------- Helper Functions ----------------
const double ln10 = 2.302585092994046;

double log(double x) {
  return math.log(x);
}

// ---------------- Constants ----------------
final double defaultHeadendDbm = 19.0;
final double fiberAttenuationDbPerKm = 0.25;

// ---------------- Diagram Node ----------------
class DiagramNode {
  int id;
  String label;
  double signal;
  double distance;
  List<DiagramNode> children;
  int? parentId;
  String deviceType;
  String? deviceConfig;
  int outputPort;
  double deviceLoss;
  String wavelength;
  bool useWdm;
  double wdmLoss;
  int? couplerRatio;
  bool isCouplerOutput;
  double couplerValue;
  bool isSplitterOutput;
  double wdmOutputPower;
  double fiberLoss;

  DiagramNode({
    required this.id,
    required this.label,
    required this.signal,
    required this.distance,
    List<DiagramNode>? children,
    this.parentId,
    this.deviceType = 'leaf',
    this.deviceConfig,
    this.outputPort = 0,
    this.deviceLoss = 0.0,
    this.wavelength = '1550',
    this.useWdm = false,
    this.wdmLoss = 0.0,
    this.couplerRatio,
    this.isCouplerOutput = false,
    this.couplerValue = 1.0,
    this.isSplitterOutput = false,
    this.wdmOutputPower = 0.0,
    this.fiberLoss = 0.0,
  }) : children = children ?? [];

  bool get isLeaf => children.isEmpty;
  bool get isCoupler => deviceType == 'coupler';
  bool get isSplitter => deviceType == 'splitter';
  bool get isHeadend => deviceType == 'headend';
  bool get isCouplerSplitBlock => isCouplerOutput;
}

// ---------------- CouplerCalculator ----------------
class CouplerCalculator {
  final double couplerValue;
  CouplerCalculator(this.couplerValue);

  final Map<double, Map<String, List<Map<String, double>>>> referenceData = {
    1.0: {
      "LOSS-15 50": [
        {"ratio": 5, "val1": -11.5, "val2": 0.6},
        {"ratio": 10, "val1": -9.5, "val2": 0.4},
        {"ratio": 15, "val1": -7.5, "val2": 0.0},
        {"ratio": 20, "val1": -6.5, "val2": -0.4},
        {"ratio": 25, "val1": -5.5, "val2": -0.8},
        {"ratio": 30, "val1": -4.8, "val2": -1.0},
        {"ratio": 35, "val1": -4.0, "val2": -1.2},
        {"ratio": 40, "val1": -3.5, "val2": -1.8},
        {"ratio": 45, "val1": -3.0, "val2": -2.0},
        {"ratio": 50, "val1": -2.5, "val2": -2.5},
      ],
      "LOSS-13 10": [
        {"ratio": 5, "val1": -10.5, "val2": 0.8},
        {"ratio": 10, "val1": -8.9, "val2": 0.6},
        {"ratio": 15, "val1": -7.5, "val2": 0.3},
        {"ratio": 20, "val1": -5.9, "val2": 0.1},
        {"ratio": 25, "val1": -5.1, "val2": -0.2},
        {"ratio": 30, "val1": -4.2, "val2": -0.5},
        {"ratio": 35, "val1": -3.6, "val2": -0.8},
        {"ratio": 40, "val1": -2.9, "val2": -1.2},
        {"ratio": 45, "val1": -2.5, "val2": -1.6},
        {"ratio": 50, "val1": -2.0, "val2": -2.0},
      ],
    },
    2.0: {
      "LOSS-15 50": [
        {"ratio": 5, "val1": -10.5, "val2": 1.6},
        {"ratio": 10, "val1": -8.5, "val2": 1.4},
        {"ratio": 15, "val1": -6.5, "val2": 1.0},
        {"ratio": 20, "val1": -5.5, "val2": 0.6},
        {"ratio": 25, "val1": -4.5, "val2": 0.2},
        {"ratio": 30, "val1": -3.8, "val2": 0.0},
        {"ratio": 35, "val1": -3.0, "val2": -0.2},
        {"ratio": 40, "val1": -2.5, "val2": -0.8},
        {"ratio": 45, "val1": -2.0, "val2": -1.0},
        {"ratio": 50, "val1": -1.5, "val2": -1.5},
      ],
      "LOSS-13 10": [
        {"ratio": 5, "val1": -9.5, "val2": 1.8},
        {"ratio": 10, "val1": -7.9, "val2": 1.6},
        {"ratio": 15, "val1": -6.5, "val2": 1.3},
        {"ratio": 20, "val1": -4.9, "val2": 1.1},
        {"ratio": 25, "val1": -4.1, "val2": 0.8},
        {"ratio": 30, "val1": -3.2, "val2": 0.5},
        {"ratio": 35, "val1": -2.6, "val2": 0.2},
        {"ratio": 40, "val1": -1.9, "val2": -0.2},
        {"ratio": 45, "val1": -1.5, "val2": -0.6},
        {"ratio": 50, "val1": -1.0, "val2": -1.0},
      ],
    },
    10.0: {
      "LOSS-15 50": [
        {"ratio": 5, "val1": -2.5, "val2": 9.6},
        {"ratio": 10, "val1": -0.5, "val2": 9.4},
        {"ratio": 15, "val1": 1.5, "val2": 9.0},
        {"ratio": 20, "val1": 2.5, "val2": 8.6},
        {"ratio": 25, "val1": 3.5, "val2": 8.2},
        {"ratio": 30, "val1": 4.2, "val2": 8.0},
        {"ratio": 35, "val1": 5.0, "val2": 7.8},
        {"ratio": 40, "val1": 5.5, "val2": 7.2},
        {"ratio": 45, "val1": 6.0, "val2": 7.0},
        {"ratio": 50, "val1": 6.5, "val2": 6.5},
      ],
      "LOSS-13 10": [
        {"ratio": 5, "val1": -1.5, "val2": 9.8},
        {"ratio": 10, "val1": 0.1, "val2": 9.6},
        {"ratio": 15, "val1": 1.5, "val2": 9.3},
        {"ratio": 20, "val1": 3.1, "val2": 9.1},
        {"ratio": 25, "val1": 3.9, "val2": 8.8},
        {"ratio": 30, "val1": 4.8, "val2": 8.5},
        {"ratio": 35, "val1": 5.4, "val2": 8.2},
        {"ratio": 40, "val1": 6.1, "val2": 7.8},
        {"ratio": 45, "val1": 6.5, "val2": 7.4},
        {"ratio": 50, "val1": 7.0, "val2": 7.0},
      ],
    },
    19.0: {
      "LOSS-15 50": [
        {"ratio": 5, "val1": 6.5, "val2": 18.6},
        {"ratio": 10, "val1": 8.5, "val2": 18.4},
        {"ratio": 15, "val1": 10.5, "val2": 18.0},
        {"ratio": 20, "val1": 11.5, "val2": 17.6},
        {"ratio": 25, "val1": 12.5, "val2": 17.2},
        {"ratio": 30, "val1": 13.2, "val2": 17.0},
        {"ratio": 35, "val1": 14.0, "val2": 16.8},
        {"ratio": 40, "val1": 14.5, "val2": 16.2},
        {"ratio": 45, "val1": 15.0, "val2": 16.0},
        {"ratio": 50, "val1": 15.5, "val2": 15.5},
      ],
      "LOSS-13 10": [
        {"ratio": 5, "val1": 7.5, "val2": 18.8},
        {"ratio": 10, "val1": 9.1, "val2": 18.6},
        {"ratio": 15, "val1": 10.5, "val2": 18.3},
        {"ratio": 20, "val1": 12.1, "val2": 18.1},
        {"ratio": 25, "val1": 12.9, "val2": 17.8},
        {"ratio": 30, "val1": 13.8, "val2": 17.5},
        {"ratio": 35, "val1": 14.4, "val2": 17.2},
        {"ratio": 40, "val1": 15.1, "val2": 16.8},
        {"ratio": 45, "val1": 15.5, "val2": 16.4},
        {"ratio": 50, "val1": 16.0, "val2": 16.0},
      ],
    },
  };

  List<Map<String, dynamic>> calculateLoss() {
    final keys = referenceData.keys.toList()..sort();
    double lower = keys.first;
    double upper = keys.last;

    for (int i = 0; i < keys.length - 1; i++) {
      if (couplerValue >= keys[i] && couplerValue <= keys[i + 1]) {
        lower = keys[i];
        upper = keys[i + 1];
        break;
      }
    }

    double ratio = (couplerValue - lower) / (upper - lower);
    final lowerData = referenceData[lower]!;
    final upperData = referenceData[upper]!;

    List<Map<String, dynamic>> result = [];

    for (var section in ["LOSS-15 50", "LOSS-13 10"]) {
      List<Map<String, double>> interpolated = [];
      for (int i = 0; i < lowerData[section]!.length; i++) {
        double val1 = lowerData[section]![i]["val1"]! +
            (upperData[section]![i]["val1"]! -
                    lowerData[section]![i]["val1"]!) *
                ratio;
        double val2 = lowerData[section]![i]["val2"]! +
            (upperData[section]![i]["val2"]! -
                    lowerData[section]![i]["val2"]!) *
                ratio;
        interpolated.add({
          "ratio": lowerData[section]![i]["ratio"]!,
          "val1": double.parse(val1.toStringAsFixed(2)),
          "val2": double.parse(val2.toStringAsFixed(2)),
        });
      }
      result.add({"section": section, "data": interpolated});
    }

    return result;
  }
}

// ---------------- SplitterCalculator (CORRECTED) ----------------
class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};

    // BASE LOSS VALUES from calculator (these are NEGATIVE in calculator)
    final baseLoss1550 = [-3.6, -6.8, -10.0, -13.0, -16.0, -19.5];
    final baseLoss1310 = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];

    final adjust = splitterValue;

    result["LOSS-15 50"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value':
                  double.parse((baseLoss1550[i] + adjust).toStringAsFixed(2))
            });

    result["LOSS-13 10"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value':
                  double.parse((baseLoss1310[i] + adjust).toStringAsFixed(2))
            });

    return result;
  }
}

// ---------------- OFC Diagram Page ----------------
class OFCDiagramPage extends StatefulWidget {
  final Map? savedData;
  const OFCDiagramPage({Key? key, this.savedData}) : super(key: key);
  @override
  State<OFCDiagramPage> createState() => _OFCDiagramPageState();
}

class BlockPositionManager {
  static const double blockWidth = 180.0;
  static const double blockHeight = 90.0;
  static const double minSpacing = 40.0;

  static double calculateOptimalSpacing(int siblingCount, int level) {
    // INCREASED SPACING to prevent overlapping
    if (siblingCount <= 2) return 450.0; // Changed from 350
    if (siblingCount <= 4) return 600.0; // Changed from 450
    if (siblingCount <= 8) return 750.0; // Changed from 550
    return 900.0; // Changed from 650
  }

  static List<double> distributePositions(
      int count, double centerX, double spacing) {
    List<double> positions = [];
    final total = (count - 1) * spacing;
    final startX = centerX - total / 2;

    for (int i = 0; i < count; i++) {
      positions.add(startX + i * spacing);
    }

    // Apply collision resolution with increased minimum spacing
    return _resolveCollisions(positions, spacing * 1.5);
  }

  static List<double> _resolveCollisions(
      List<double> positions, double spacing) {
    for (int i = 0; i < positions.length - 1; i++) {
      double overlap =
          (positions[i] + blockWidth + minSpacing) - positions[i + 1];
      if (overlap > 0) {
        for (int j = i + 1; j < positions.length; j++) {
          positions[j] += overlap;
        }
      }
    }
    return positions;
  }
}

class GridPositionManager {
  static const double gridCellWidth = 250.0;
  static const double gridCellHeight = 150.0;
  static Map<String, Offset> occupiedCells = {};

  static Offset snapToGrid(double x, double y, int level) {
    // Calculate grid-aligned position
    final baseY = 100.0 + (level * gridCellHeight);
    final gridX = (x / gridCellWidth).round() * gridCellWidth;

    return Offset(gridX, baseY);
  }

  static double findAvailableX(double preferredX, int level, String nodeId) {
    final gridY = 100.0 + (level * gridCellHeight);
    double testX = preferredX;
    int attempts = 0;

    // Try to find free spot within 10 attempts
    while (attempts < 10) {
      final testPos = Offset(testX, gridY);
      final cellKey = '${testX.round()}_${gridY.round()}';

      // Check if cell is free or occupied by same node
      if (!occupiedCells.containsKey(cellKey) ||
          occupiedCells[cellKey] == Offset(testX, gridY)) {
        occupiedCells[cellKey] = Offset(testX, gridY);
        return testX;
      }

      // Try next cell to the right
      testX += gridCellWidth;
      attempts++;
    }

    return preferredX; // Fallback
  }

  static void clearGrid() {
    occupiedCells.clear();
  }

  static void registerNode(double x, double y, String nodeId) {
    final cellKey = '${x.round()}_${y.round()}';
    occupiedCells[cellKey] = Offset(x, y);
  }
}

class _OFCDiagramPageState extends State<OFCDiagramPage> {
  final GlobalKey repaintKey = GlobalKey();
  final TextEditingController _headendNameCtrl =
      TextEditingController(text: "EDFA");
  final TextEditingController _headendDbmCtrl =
      TextEditingController(text: defaultHeadendDbm.toString());
  final TextEditingController _wdmLossCtrl = TextEditingController(text: "0.0");
  final TextEditingController _wdmPowerCtrl =
      TextEditingController(text: "0.0");
  DiagramNode? root;
  int _nodeCounter = 0;
  String _selectedWavelength = '1550';
  bool _useWdm = false;
  double _wdmLoss = 0.0;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initRoot();
    Hive.openBox('diagram_history');
    Hive.openBox('diagram_downloads');

    // Load saved data if provided
    if (widget.savedData != null) {
      _loadSavedDiagram(widget.savedData!);
    }
  }

  void _initRoot() {
    root = DiagramNode(
      id: _nodeCounter++,
      label: _headendNameCtrl.text,
      signal: double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
      distance: 0,
      deviceType: 'headend',
      wavelength: _selectedWavelength,
      useWdm: _useWdm,
      wdmLoss: _wdmLoss,
    );
  }
  // Add AFTER _initRoot() method

  void _loadSavedDiagram(Map data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        if (data['headendName'] != null) {
          _headendNameCtrl.text = data['headendName'];
        }
        if (data['headendPower'] != null) {
          _headendDbmCtrl.text = data['headendPower'].toString();
        }
        if (data['wavelength'] != null) {
          _selectedWavelength = data['wavelength'];
        }
        if (data['useWdm'] != null) {
          _useWdm = data['useWdm'];
        }
        if (data['wdmLoss'] != null) {
          _wdmLoss = data['wdmLoss'];
          _wdmLossCtrl.text = _wdmLoss.toString();
        }

        // Load entire diagram tree if available
        if (data['diagramTree'] != null) {
          try {
            root = _deserializeDiagramTree(data['diagramTree'], null);
          } catch (e) {
            print('Error deserializing diagram: $e');
            _initRoot();
          }
        } else {
          _updateHeadend();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagram loaded! You can continue editing.'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  // Helper method to calculate coupler losses using reference data
  List<double> _calculateCouplerLosses(
      int ratio, double inputPower, String wavelength) {
    final calculator = CouplerCalculator(inputPower);
    final calculatedData = calculator.calculateLoss();

    final section = wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
    final sectionData = calculatedData.firstWhere(
      (s) => s['section'] == section,
      orElse: () => calculatedData[0],
    );

    final dataList = (sectionData['data'] as List).cast<Map<String, dynamic>>();

    final entry = dataList.firstWhere(
      (e) => e['ratio'] == ratio,
      orElse: () => dataList.first,
    );

    final val1 = (entry['val1'] as num).toDouble();
    final val2 = (entry['val2'] as num).toDouble();

    // CRITICAL FIX: For ALL input powers, calculate loss correctly
    final loss1 = inputPower - val1;
    final loss2 = inputPower - val2;

    print(
        'DEBUG Coupler Calc: Input=$inputPower, Ratio=$ratio, Wavelength=$wavelength');
    print('  Output1=$val1 (Loss=${loss1.toStringAsFixed(2)}dB)');
    print('  Output2=$val2 (Loss=${loss2.toStringAsFixed(2)}dB)');

    return [
      val1, // Output power for port 1
      val2, // Output power for port 2
      loss1, // Loss value for port 1
      loss2 // Loss value for port 2
    ];
  }

  void _recalculate(DiagramNode node) {
    if (node.children.isEmpty) return;

    final wavelength = node.wavelength;
    final wdmLoss = node.useWdm ? node.wdmLoss : 0.0;

    if (node.isCoupler && node.deviceConfig != null && !node.isCouplerOutput) {
      final parts = node.deviceConfig!.split('::');
      final ratio = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 50 : 50;

      // FIXED: Use node's wavelength, not parent's
      final losses =
          _calculateCouplerLosses(ratio, node.signal, node.wavelength);
      final output1Power = losses[0]; // Output power from reference
      final output2Power = losses[1]; // Output power from reference

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final dLoss = child.distance * fiberAttenuationDbPerKm;
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;

        if (i == 0) {
          // Apply WDM loss and distance loss to reference output
          child.signal = output1Power - wdmLoss - dLoss;
          child.deviceLoss = losses[2]; // Update loss value
        } else if (i == 1) {
          // Apply WDM loss and distance loss to reference output
          child.signal = output2Power - wdmLoss - dLoss;
          child.deviceLoss = losses[3]; // Update loss value
        }

        _recalculate(child);
      }
    } else if (node.isSplitter && node.isSplitterOutput) {
      // This is a splitter OUTPUT node - just propagate to children with their own splitter logic
      for (final child in node.children) {
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;

        // If child is a splitter parent, it will handle its own calculations
        // Otherwise, just maintain the signal from this splitter output

        _recalculate(child);
      }
    } else if (node.deviceType == 'splitter' &&
        node.deviceConfig != null &&
        node.children.isNotEmpty) {
      // This is a PARENT splitter node that has splitter output children
      final parts = node.deviceConfig!.split('::');
      final split = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2 : 2;
      final splitterVal =
          parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0;

      final calc = SplitterCalculator(splitterVal);
      final all = calc.calculateLoss();
      final section = wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
      final sec = all[section]!;
      final entry =
          sec.firstWhere((e) => e['split'] == split, orElse: () => sec.first);

      // IMPORTANT: This value is NEGATIVE (e.g., -3.6)
      final splitterLossValue = (entry['value'] as num).toDouble();
      final splitterLossDisplay = splitterLossValue.abs();

      // Get distance from first child
      final firstChildDistance = node.children[0].distance;
      final dLoss = firstChildDistance * fiberAttenuationDbPerKm;

      // Calculate final device loss and output signal
      final finalDeviceLoss = splitterLossDisplay - dLoss;
      final outputSignal = node.signal - splitterLossDisplay - dLoss;

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;
        child.deviceLoss = finalDeviceLoss;
        child.signal = outputSignal;

        _recalculate(child);
      }
    } else {
      // For regular nodes - just propagate wavelength and WDM settings
      for (final child in node.children) {
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;

        _recalculate(child);
      }
    }
  }

  void _onHeadendPowerChanged(String value) {
    final newPower = double.tryParse(value) ?? defaultHeadendDbm;
    if (newPower != root!.signal) {
      setState(() {
        root!.signal = newPower;
        // Force recalculation of entire tree
        _recalculate(root!);
      });
    }
  }

  void _updateHeadend() {
    setState(() {
      root!.label =
          _headendNameCtrl.text.isEmpty ? 'EDFA' : _headendNameCtrl.text;
      root!.signal = double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm;
      root!.wavelength = _selectedWavelength;
      root!.useWdm = _useWdm;
      root!.wdmLoss = _wdmLoss;

      // Force recalculate ALL children with new values
      _recalculateAll(root!);
    });
  }

  void _recalculateAll(DiagramNode node) {
    if (node.children.isEmpty) return;

    for (var child in node.children) {
      // Update wavelength and WDM settings
      child.wavelength = node.wavelength;
      child.useWdm = node.useWdm;
      child.wdmLoss = node.wdmLoss;

      // If it's a coupler output, recalculate with current parent power
      if (child.isCouplerOutput) {
        final ratio = child.couplerRatio ?? 50;
        final losses =
            _calculateCouplerLosses(ratio, node.signal, node.wavelength);
        final fiberLoss = child.fiberLoss;
        // REMOVE THIS LINE: final wdmLoss = node.useWdm ? node.wdmLoss : 0.0;

        // Check if this child is the first output by comparing with parent's children
        final isFirstOutput = node.children.indexOf(child) == 0;

        if (isFirstOutput) {
          // First output gets losses[0] and losses[2]
          child.signal = losses[0] - fiberLoss; // REMOVED wdmLoss
          child.deviceLoss = losses[2];
        } else {
          // Second output gets losses[1] and losses[3]
          child.signal = losses[1] - fiberLoss; // REMOVED wdmLoss
          child.deviceLoss = losses[3];
        }

        // Recalculate WDM if enabled
        if (node.useWdm) {
          final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
          final wdmLosses =
              _calculateCouplerLosses(ratio, wdmInput, node.wavelength);
          if (isFirstOutput) {
            child.wdmOutputPower = wdmLosses[0] - fiberLoss;
          } else {
            child.wdmOutputPower = wdmLosses[1] - fiberLoss;
          }
        } else {
          child.wdmOutputPower = 0.0;
        }
      } else if (child.isSplitterOutput) {
        // Splitter outputs share the same signal, just propagate
        final parts = child.deviceConfig?.split('::');
        if (parts != null && parts.length >= 2) {
          final split = int.tryParse(parts[0]) ?? 2;
          final splitterVal = double.tryParse(parts[1]) ?? 0.0;

          final calc = SplitterCalculator(splitterVal);
          final all = calc.calculateLoss();
          final section =
              node.wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
          final sec = all[section]!;
          final entry = sec.firstWhere((e) => e['split'] == split,
              orElse: () => sec.first);

          final splitterLossValue = (entry['value'] as num).toDouble();
          final splitterLossDisplay = splitterLossValue.abs();
          final fiberLoss = child.fiberLoss;

          child.deviceLoss = splitterLossDisplay - fiberLoss;
          child.signal = node.signal - splitterLossDisplay - fiberLoss;
        }
      }

      _recalculateAll(child);
    }
  }

  Future<void> _addSingleChild(DiagramNode parent) async {
    final labelCtrl = TextEditingController(text: 'Node');
    final distanceCtrl =
        TextEditingController(text: parent.isHeadend ? '0.0' : '0.5');
    String distanceUnit = 'km';
    bool showDistanceInput = !parent.isHeadend;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Child Node',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                    labelText: 'Node Label',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.label)),
              ),
              const SizedBox(height: 16),
              if (showDistanceInput) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: distanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Distance',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: distanceUnit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['km', 'm'].map((String unit) {
                          return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setInner(() {
                            distanceUnit = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Input Power: ${parent.signal.toStringAsFixed(2)} dBm\n'
                        '${showDistanceInput ? 'Fiber Loss: 0.25 dB/km' : 'First block - no distance loss'}',
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                setState(() {
                  double distance = showDistanceInput
                      ? (double.tryParse(distanceCtrl.text) ?? 0.5)
                      : 0.0;

                  if (showDistanceInput && distanceUnit == 'm') {
                    distance = distance / 1000;
                  }

                  final label =
                      labelCtrl.text.isEmpty ? 'Node' : labelCtrl.text;
                  final fiberLoss = distance * fiberAttenuationDbPerKm;
                  final outputPower = showDistanceInput
                      ? (parent.signal - fiberLoss)
                      : parent.signal;

                  final child = DiagramNode(
                    id: _nodeCounter++,
                    label: label,
                    signal: outputPower,
                    distance: distance,
                    parentId: parent.id,
                    deviceType: 'leaf',
                    outputPort: parent.children.length,
                    wavelength: parent.wavelength,
                    useWdm: parent.useWdm,
                    wdmLoss: parent.wdmLoss,
                    fiberLoss: fiberLoss,
                  );

                  parent.children.add(child);
                  if (parent.isLeaf) {
                    parent.deviceType = 'pass';
                  }
                  _recalculate(root!);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Node',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        );
      }),
    );
  }

  Future<void> _addCoupler(DiagramNode parent) async {
    final labelCtrl = TextEditingController(text: 'Coupler');
    final distanceCtrl = TextEditingController(text: '0.5');
    bool showWdmWarning = false;
    String distanceUnit = 'km';
    bool showDistanceInput = !parent.isHeadend;
    distanceCtrl.text = showDistanceInput ? '0.5' : '0.0';

    // MOVE ratio OUTSIDE StatefulBuilder - THIS IS THE KEY FIX
    int ratio = 50;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        // REMOVE: int ratio = 50; from here

        void checkWdmValidation() {
          final is1310Wavelength = _selectedWavelength == '1310';
          final isWdmEnabled = _useWdm;
          final isInvalidCombination = is1310Wavelength && isWdmEnabled;
          setInner(() {
            showWdmWarning = isInvalidCombination;
          });
        }

        checkWdmValidation();

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.call_split, color: Color(0xFF0288D1)),
              ),
              const SizedBox(width: 12),
              const Text('Add Coupler',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Input Power: ${parent.signal.toStringAsFixed(2)} dBm',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: ratio,
                  decoration: InputDecoration(
                      labelText: 'Split Ratio',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.tune),
                      filled: true,
                      fillColor: Colors.grey.shade50),
                  items: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('$r : ${100 - r}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      // FIX: Update ratio and trigger rebuild
                      ratio = v; // Update the outer variable
                      setInner(() {
                        // This triggers the rebuild with new ratio
                      });
                      checkWdmValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Coupler Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.label),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                if (showDistanceInput) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: distanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Distance',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.straighten),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: distanceUnit,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['km', 'm'].map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setInner(() {
                              distanceUnit = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Input Power: ${parent.signal.toStringAsFixed(2)} dBm\n'
                              '${showDistanceInput ? 'Fiber Loss: 0.25 dB/km' : 'First block - no distance loss'}',
                              style: const TextStyle(
                                  color: Colors.blue, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final losses = _calculateCouplerLosses(
                              ratio, parent.signal, parent.wavelength);
                          return Column(
                            children: [
                              Text(
                                'Expected Output: ${losses[0].toStringAsFixed(2)} dBm : ${losses[1].toStringAsFixed(2)} dBm',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Losses: ${losses[2].toStringAsFixed(2)} dB : ${losses[3].toStringAsFixed(2)} dB',
                                style: const TextStyle(
                                    color: Colors.blue, fontSize: 11),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (showWdmWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WDM is only compatible with 1550nm wavelength and 15-50 configuration',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      showWdmWarning ? Colors.grey : const Color(0xFF0288D1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: showWdmWarning
                  ? null
                  : () {
                      setState(() {
                        double distance = showDistanceInput
                            ? (double.tryParse(distanceCtrl.text) ?? 0.5)
                            : 0.0;

                        if (showDistanceInput && distanceUnit == 'm') {
                          distance = distance / 1000;
                        }

                        final couplerName =
                            labelCtrl.text.isEmpty ? 'Coupler' : labelCtrl.text;

                        final fiberLoss = distance * fiberAttenuationDbPerKm;

                        final losses = _calculateCouplerLosses(
                            ratio, parent.signal, parent.wavelength);
                        final output1Power = losses[0];
                        final output2Power = losses[1];

                        double wdm1Power = 0.0;
                        double wdm2Power = 0.0;

                        if (parent.useWdm) {
                          final wdmInput =
                              double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
                          final wdmLosses = _calculateCouplerLosses(
                              ratio, wdmInput, parent.wavelength);
                          wdm1Power = wdmLosses[0] - fiberLoss;
                          wdm2Power = wdmLosses[1] - fiberLoss;
                        }

                        final output1Signal = output1Power - fiberLoss;
                        final output2Signal = output2Power - fiberLoss;

                        final device1Loss = losses[2];
                        final device2Loss = losses[3];

                        final output1 = DiagramNode(
                          id: _nodeCounter++,
                          label: '$couplerName $ratio',
                          signal: output1Signal,
                          distance: distance,
                          parentId: parent.id,
                          deviceType: 'coupler',
                          deviceConfig: '$ratio::1.0',
                          wavelength: parent.wavelength,
                          useWdm: parent.useWdm,
                          wdmLoss: parent.wdmLoss,
                          wdmOutputPower: wdm1Power,
                          couplerRatio: ratio,
                          isCouplerOutput: true,
                          deviceLoss: device1Loss,
                          fiberLoss: fiberLoss,
                        );

                        final output2 = DiagramNode(
                          id: _nodeCounter++,
                          label: '$couplerName ${100 - ratio}',
                          signal: output2Signal,
                          distance: distance,
                          parentId: parent.id,
                          deviceType: 'coupler',
                          deviceConfig: '$ratio::1.0',
                          wavelength: parent.wavelength,
                          useWdm: parent.useWdm,
                          wdmLoss: parent.wdmLoss,
                          wdmOutputPower: wdm2Power,
                          couplerRatio: 100 - ratio,
                          isCouplerOutput: true,
                          deviceLoss: device2Loss,
                          fiberLoss: fiberLoss,
                        );

                        parent.children.add(output1);
                        parent.children.add(output2);
                        _recalculate(root!);
                      });
                      Navigator.pop(ctx);
                    },
              child: const Text('Add Coupler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        );
      }),
    );
  }

  Future<void> _addSplitter(DiagramNode parent) async {
    final labelCtrl = TextEditingController(text: 'Splitter');
    final distanceCtrl = TextEditingController(text: '0.5');
    int split = 2;
    final splits = [2, 4, 8, 16, 32, 64];
    String distanceUnit = 'km';
    bool showDistanceInput = !parent.isHeadend;
    distanceCtrl.text = showDistanceInput ? '0.5' : '0.0';

    // Check if this is being added below a coupler
    bool isBelowCoupler = parent.isCouplerOutput;
    double inputPower = parent.signal;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree, color: Color(0xFF7B1FA2)),
              ),
              const SizedBox(width: 12),
              Text(
                isBelowCoupler
                    ? 'Add Splitter to ${parent.label}'
                    : 'Add Splitter',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show previous block info when adding below coupler
                if (isBelowCoupler) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous Block: ${parent.label}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Input Power: ${inputPower.toStringAsFixed(2)} dBm',
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text('Input Power: ${parent.signal.toStringAsFixed(2)} dBm',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  value: split,
                  decoration: InputDecoration(
                    labelText: 'Split Configuration',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.tune),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: splits
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('1x$s Split',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                  onChanged: (v) => setInner(() => split = v ?? split),
                ),
                const SizedBox(height: 16),

                if (showDistanceInput) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: distanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Distance',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.straighten),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: distanceUnit,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['km', 'm'].map((String unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setInner(() {
                              distanceUnit = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: 'Splitter Name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.label),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Calculation preview
                Builder(
                  builder: (context) {
                    double distance = showDistanceInput
                        ? (double.tryParse(distanceCtrl.text) ?? 0.5)
                        : 0.0;

                    if (showDistanceInput && distanceUnit == 'm') {
                      distance = distance / 1000;
                    }

                    final fiberLoss = distance * fiberAttenuationDbPerKm;

                    // Use splitter value of 0.0 (exact values from calculator)
                    final splitterVal = 0.0;

                    final calc = SplitterCalculator(splitterVal);
                    final all = calc.calculateLoss();
                    final section = parent.wavelength == '1310'
                        ? 'LOSS-13 10'
                        : 'LOSS-15 50';
                    final sec = all[section]!;
                    final entry = sec.firstWhere(
                      (e) => e['split'] == split,
                      orElse: () => sec.first,
                    );

                    // IMPORTANT: This value is NEGATIVE (e.g., -3.6)
                    final splitterLossValue =
                        (entry['value'] as num).toDouble();

                    // Get the ABSOLUTE value for display (positive)
                    final splitterLossDisplay = splitterLossValue.abs();

                    final wdmLoss = parent.useWdm ? parent.wdmLoss : 0.0;

                    // CORRECT: Calculate device loss
                    final finalDeviceLoss = splitterLossDisplay - fiberLoss;

                    // CORRECT: Calculate output signal
                    // Output = Input - splitterLossDisplay - fiberLoss
                    final outputSignal =
                        parent.signal - splitterLossDisplay - fiberLoss;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info,
                                  color: Colors.purple, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Using ${parent.wavelength}nm wavelength${parent.useWdm ? ' + WDM (${parent.wdmLoss}dB)' : ''}\n'
                                  '${showDistanceInput ? 'Fiber Loss: 0.25 dB/km' : 'First block - no distance loss'}',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isBelowCoupler) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Splitter Loss: ${splitterLossDisplay.toStringAsFixed(2)} dB',
                              style: const TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                              ),
                            ),
                            if (showDistanceInput) ...[
                              Text(
                                'Distance Loss: ${fiberLoss.toStringAsFixed(2)} dB',
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Final Device Loss: ${finalDeviceLoss.toStringAsFixed(2)} dB',
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            Text(
                              'Output Power: ${outputSignal.toStringAsFixed(2)} dBm',
                              style: const TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  double distance = showDistanceInput
                      ? (double.tryParse(distanceCtrl.text) ?? 0.5)
                      : 0.0;

                  if (showDistanceInput && distanceUnit == 'm') {
                    distance = distance / 1000;
                  }

                  final fiberLoss = distance * fiberAttenuationDbPerKm;

                  // Use splitter value of 0.0 (exact values from calculator)
                  final splitterVal = 0.0;

                  final calc = SplitterCalculator(splitterVal);
                  final all = calc.calculateLoss();
                  final section =
                      parent.wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
                  final sec = all[section]!;
                  final entry = sec.firstWhere(
                    (e) => e['split'] == split,
                    orElse: () => sec.first,
                  );

                  // IMPORTANT: This value is NEGATIVE (e.g., -3.6)
                  final splitterLossValue = (entry['value'] as num).toDouble();

                  // Get the ABSOLUTE value for device loss
                  final splitterLossDisplay = splitterLossValue.abs();

                  // CORRECT: Calculate device loss as: splitter loss - distance loss
                  final finalDeviceLoss = splitterLossDisplay - fiberLoss;

                  // CORRECT: Calculate output signal
                  final outputSignal =
                      parent.signal - splitterLossDisplay - fiberLoss;

                  // Create ALL splitter outputs with the SAME values
                  for (int i = 0; i < split; i++) {
                    final outputNode = DiagramNode(
                      id: _nodeCounter++,
                      label: labelCtrl.text.isEmpty
                          ? '${i + 1}'
                          : '${labelCtrl.text} ${i + 1}',
                      signal: outputSignal, // Same output signal for all
                      distance: distance, // Same distance for all
                      parentId: parent.id,
                      deviceType: 'splitter',
                      deviceConfig: '$split::$splitterVal',
                      wavelength: parent.wavelength,
                      useWdm: parent.useWdm,
                      wdmLoss: parent.wdmLoss,
                      isSplitterOutput: true,
                      deviceLoss: finalDeviceLoss, // Same device loss for all
                      fiberLoss: fiberLoss,
                    );
                    parent.children.add(outputNode);
                  }
                  _recalculate(root!);
                });
                Navigator.pop(ctx);
              },
              child: Text(
                isBelowCoupler ? 'Add Splitter Below' : 'Add Splitter',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          ],
        );
      }),
    );
  }

  Future<void> _editNode(DiagramNode node) async {
    if (node.isCoupler && node.isCouplerOutput) {
      final parent = _findNode(root, node.parentId!);
      if (parent == null) return;

      // MOVE currentRatio and newRatio OUTSIDE StatefulBuilder
      int currentRatio = node.couplerRatio ?? 50;
      int newRatio = currentRatio;
      bool showWdmWarning = false;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
          // REMOVE: int newRatio = currentRatio; from here

          void checkWdmValidation() {
            final is1310Wavelength = _selectedWavelength == '1310';
            final isWdmEnabled = _useWdm;
            final isInvalidCombination = is1310Wavelength && isWdmEnabled;
            setInner(() {
              showWdmWarning = isInvalidCombination;
            });
          }

          checkWdmValidation();

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0288D1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit, color: Color(0xFF0288D1)),
                ),
                const SizedBox(width: 12),
                const Text('Edit Coupler Ratio',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Input Power: ${parent.signal.toStringAsFixed(2)} dBm',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: newRatio,
                  decoration: InputDecoration(/*...*/),
                  items: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
                      .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text('$r : ${100 - r}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      // FIX: Update both variables
                      newRatio = v;
                      currentRatio = v;
                      setInner(() {
                        // Trigger rebuild
                      });
                      checkWdmValidation();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final losses = _calculateCouplerLosses(
                        newRatio, parent.signal, parent.wavelength);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Expected Output: ${losses[0].toStringAsFixed(2)} dBm : ${losses[1].toStringAsFixed(2)} dBm',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Losses: ${losses[2].toStringAsFixed(2)} dB : ${losses[3].toStringAsFixed(2)} dB',
                            style: const TextStyle(
                                color: Colors.blue, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (showWdmWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WDM is only compatible with 1550nm wavelength',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: showWdmWarning
                          ? Colors.grey
                          : const Color(0xFF0288D1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: showWdmWarning
                      ? null
                      : () {
                          setState(() {
                            // Update both coupler outputs
                            final distance = parent.children[0].distance;
                            final fiberLoss =
                                distance * fiberAttenuationDbPerKm;

                            final losses = _calculateCouplerLosses(
                                newRatio, parent.signal, parent.wavelength);
                            final output1Power = losses[0];
                            final output2Power = losses[1];

                            // Calculate WDM outputs if enabled
                            double wdm1Power = 0.0;
                            double wdm2Power = 0.0;
                            if (parent.useWdm) {
                              final wdmInput =
                                  double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
                              final wdmLosses = _calculateCouplerLosses(
                                  newRatio, wdmInput, parent.wavelength);
                              wdm1Power = wdmLosses[0] - fiberLoss;
                              wdm2Power = wdmLosses[1] - fiberLoss;
                            }

                            // Update first output
                            parent.children[0].couplerRatio = newRatio;
                            parent.children[0].label = '$newRatio';
                            parent.children[0].signal =
                                output1Power - fiberLoss;
                            parent.children[0].deviceLoss = losses[2];
                            parent.children[0].deviceConfig = '$newRatio::1.0';
                            parent.children[0].wdmOutputPower = wdm1Power;

                            // Update second output
                            if (parent.children.length > 1) {
                              parent.children[1].couplerRatio = 100 - newRatio;
                              parent.children[1].label = '${100 - newRatio}';
                              parent.children[1].signal =
                                  output2Power - fiberLoss;
                              parent.children[1].deviceLoss = losses[3];
                              parent.children[1].deviceConfig =
                                  '$newRatio::1.0';
                              parent.children[1].wdmOutputPower = wdm2Power;
                            }

                            _recalculate(root!);
                          });
                          Navigator.pop(ctx);
                        },
                  child: const Text('Update Ratio',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          );
        }),
      );
    }
  }

  void _deleteNode(DiagramNode node) {
    if (node.parentId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot delete headend')));
      return;
    }

    // Count total nodes that will be deleted
    int totalToDelete = 1 + _countDescendants(node);

    if (node.isCouplerOutput) {
      final parent = _findNode(root, node.parentId!);
      if (parent != null) {
        // Count total for both coupler outputs
        int couplerTotal = 0;
        for (var child in parent.children) {
          if (child.isCouplerOutput) {
            couplerTotal += 1 + _countDescendants(child);
          }
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Coupler Outputs?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
                'This will delete BOTH coupler outputs and ALL $couplerTotal connected node(s).'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    setState(() {
                      // Remove ALL coupler outputs and their children
                      parent.children
                          .removeWhere((child) => child.isCouplerOutput);
                      _recalculate(root!);
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                      'Delete All ($couplerTotal nodes)', // REMOVED CONST HERE
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Node?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Delete "${node.label}" and ALL $totalToDelete connected node(s)?\n\nThis includes all descendants in the tree.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 16))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                setState(() {
                  final parent = _findNode(root, node.parentId!);
                  if (parent != null) {
                    // This automatically removes the node and ALL its children
                    parent.children.removeWhere((c) => c.id == node.id);
                    _recalculate(root!);
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text('Delete All ($totalToDelete nodes)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)))
        ],
      ),
    );
  }

  int _countDescendants(DiagramNode node) {
    int cnt = node.children.length;
    for (final c in node.children) cnt += _countDescendants(c);
    return cnt;
  }

  DiagramNode? _findNode(DiagramNode? n, int id) {
    if (n == null) return null;
    if (n.id == id) return n;
    for (final c in n.children) {
      final f = _findNode(c, id);
      if (f != null) return f;
    }
    return null;
  }
  // Add AFTER _findNode method

// Serialize diagram tree to JSON
  Map<String, dynamic> _serializeDiagramTree(DiagramNode node) {
    return {
      'id': node.id,
      'label': node.label,
      'signal': node.signal,
      'distance': node.distance,
      'deviceType': node.deviceType,
      'deviceConfig': node.deviceConfig,
      'wavelength': node.wavelength,
      'useWdm': node.useWdm,
      'wdmLoss': node.wdmLoss,
      'couplerRatio': node.couplerRatio,
      'isCouplerOutput': node.isCouplerOutput,
      'isSplitterOutput': node.isSplitterOutput,
      'deviceLoss': node.deviceLoss,
      'fiberLoss': node.fiberLoss,
      'children':
          node.children.map((child) => _serializeDiagramTree(child)).toList(),
    };
  }

// Deserialize JSON back to diagram tree
  DiagramNode _deserializeDiagramTree(
      Map<String, dynamic> data, int? parentId) {
    final node = DiagramNode(
      id: data['id'],
      label: data['label'],
      signal: data['signal'],
      distance: data['distance'],
      deviceType: data['deviceType'] ?? 'leaf',
      deviceConfig: data['deviceConfig'],
      wavelength: data['wavelength'] ?? '1550',
      useWdm: data['useWdm'] ?? false,
      wdmLoss: data['wdmLoss'] ?? 0.0,
      couplerRatio: data['couplerRatio'],
      isCouplerOutput: data['isCouplerOutput'] ?? false,
      isSplitterOutput: data['isSplitterOutput'] ?? false,
      deviceLoss: data['deviceLoss'] ?? 0.0,
      fiberLoss: data['fiberLoss'] ?? 0.0,
      parentId: parentId,
    );

    if (data['children'] != null) {
      for (var childData in data['children']) {
        node.children.add(_deserializeDiagramTree(childData, node.id));
      }
    }

    if (node.id >= _nodeCounter) {
      _nodeCounter = node.id + 1;
    }

    return node;
  }

  void _showNodeOptions(DiagramNode node) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Node Options - ${node.label}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
          ),
          const Divider(),
          // ADD THIS OPTION FIRST

          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.call_split, color: Colors.blue)),
            title: const Text('Add Coupler',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('2-port unequal split device'),
            onTap: () {
              Navigator.pop(ctx);
              _addCoupler(node);
            },
          ),
          // ... rest of the options remain the same
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.account_tree, color: Colors.purple)),
            title: const Text('Add Splitter',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('1xN equal split device'),
            onTap: () {
              Navigator.pop(ctx);
              _addSplitter(node);
            },
          ),
          const Divider(),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit, color: Colors.orange)),
            title: const Text('Edit Node / Device',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Modify node properties'),
            onTap: () {
              Navigator.pop(ctx);
              _editNode(node);
            },
          ),
          if (node.parentId != null)
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete, color: Colors.red)),
              title: const Text('Delete Node',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Remove this node and children'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteNode(node);
              },
            ),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _saveDiagram() async {
    // Show loading indicator immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating diagram...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null || !boundary.attached) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagram not ready. Please try again.')),
        );
        return;
      }

      final ui.Image img = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Navigator.pop(context); // Close loading dialog
        throw Exception('Failed to encode image');
      }
      final bytes = byteData.buffer.asUint8List();

      String fileName =
          'ofc_diagram_${DateTime.now().millisecondsSinceEpoch}.png';
      String? localPath;

      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory dir;
        final possible = Directory('/storage/emulated/0/Download');
        if (await possible.exists()) {
          dir = possible;
        } else {
          dir = await getApplicationDocumentsDirectory();
        }
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        localPath = file.path;
      }

      // Upload to cloud in background (don't wait)
      String? publicUrl;
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _uploadToCloud(bytes, fileName, user.id).then((url) {
          publicUrl = url;
        }).catchError((e) {
          print('Background upload error: $e');
        });
      }

      // Save to Hive
      final downloadsBox = await Hive.openBox('diagram_downloads');
      await downloadsBox.add({
        'name': 'OFC Diagram ${DateTime.now().toString().split('.').first}',
        'fileName': fileName,
        'path': localPath,
        'cloudUrl': publicUrl,
        'date': DateTime.now().toIso8601String(),
        'type': 'diagram',
        'size': bytes.length,
        'headendName': _headendNameCtrl.text,
        'headendPower':
            double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
        'wavelength': _selectedWavelength,
        'useWdm': _useWdm,
        'wdmLoss': _wdmLoss,
        'diagramTree': root != null ? _serializeDiagramTree(root!) : null,
      });

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Diagram saved successfully!${localPath != null ? '\nLocation: $localPath' : ''}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

// Add this helper method for background upload
  Future<String?> _uploadToCloud(
      Uint8List bytes, String fileName, String userId) async {
    try {
      final storagePath = '$userId/$fileName';
      await _supabase.storage.from('diagrams').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          );
      return _supabase.storage.from('diagrams').getPublicUrl(storagePath);
    } catch (e) {
      print('Cloud upload error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('OFC Diagram Generator',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _nodeCounter = 0;
                _initRoot();
              });
            },
            icon: const Icon(Icons.refresh,
                color: Colors.white70), // Add comma here
            tooltip: 'Reset Diagram',
          ),
          IconButton(
            onPressed: _saveDiagram,
            icon: const Icon(Icons.download,
                color: Colors.white70), // Add comma here
            tooltip: 'Save Diagram',
          )
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ]),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _headendNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Headend Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.router, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _headendDbmCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Power (dBm)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon:
                          const Icon(Icons.flash_on, color: Colors.white70),
                    ),
                    onChanged: _onHeadendPowerChanged, // Add this line
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wavelength Configuration',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Row(
                            children: [
                              _buildWavelengthOption('1550', '1550 nm'),
                              const SizedBox(width: 16),
                              _buildWavelengthOption('1310', '1310 nm'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildWdmOption())]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _updateHeadend,
                    icon: const Icon(Icons.update),
                    label: const Text('Update Headend'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 12))
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.1,
                maxScale: 8.0,
                constrained: false,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: 8000,
                    height: 5000,
                    child: root != null
                        ? DiagramWidget(
                            root: root!, onTapNode: _showNodeOptions)
                        : const Center(child: Text('No diagram')),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveDiagram,
              icon: const Icon(Icons.download_for_offline),
              label: const Text('Generate & Download Diagram',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildWavelengthOption(String value, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedWavelength = value;
            root!.wavelength = value;
            if (value == '1310' && _useWdm) {
              _showWdmWarningDialog();
            }
            // Force recalculation when wavelength changes
            _recalculateAll(root!); // Use the new method
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _selectedWavelength == value
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _selectedWavelength == value
                    ? Colors.white
                    : Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedWavelength == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  void _showWdmWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('WDM Compatibility Warning')
        ]),
        content: const Text(
            'WDM (14-90) is only compatible with 1550nm wavelength and 15-50 configuration. WDM functionality will be disabled for 1310nm wavelength.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _useWdm = false;
                _wdmLoss = 0.0;
                _wdmLossCtrl.text = "0.0";
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildWdmOption() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _useWdm ? Colors.amber.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _useWdm ? Colors.amber : Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _useWdm,
            onChanged: (value) {
              if (value == true && _selectedWavelength == '1310') {
                _showWdmWarningDialog();
                return;
              }
              setState(() {
                _useWdm = value ?? false;
                root!.useWdm = _useWdm;
                if (!_useWdm) {
                  _wdmPowerCtrl.text = "0.0";
                }
                _recalculate(root!);
              });
            },
            checkColor: Colors.white,
            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.selected)) return Colors.amber;
              return Colors.transparent;
            }),
          ),
          const SizedBox(width: 8),
          const Text('WDM (14-90)',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          if (_useWdm) ...[
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _wdmPowerCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {
                    _recalculate(root!);
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'WDM Power (dBm)',
                  labelStyle:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.amber)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.amber, width: 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  helperText: 'WDM output calculated automatically',
                  helperStyle:
                      const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DiagramWidget extends StatelessWidget {
  final DiagramNode root;
  final void Function(DiagramNode) onTapNode;
  const DiagramWidget({super.key, required this.root, required this.onTapNode});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _DiagramPainter(root: root),
        child: Stack(children: _overlay(root, 3000, 100)));
  }

  List<Widget> _overlay(DiagramNode node, double x, double y) {
    final widgets = <Widget>[];

    widgets.add(Positioned(
        left: x - 100,
        top: y - 55,
        width: 200,
        height: 110,
        child: GestureDetector(
            onTap: () => onTapNode(node),
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
            ))));

    if (node.children.isNotEmpty) {
      final count = node.children.length;

      final baseSpacing =
          BlockPositionManager.calculateOptimalSpacing(count, 0);
      final spacing = baseSpacing * 1.5; // CHANGED from 1.2 to 1.5

      final positions =
          BlockPositionManager.distributePositions(count, x, spacing);

      for (int i = 0; i < count; i++) {
        final childX = positions[i];
        final childY = y + 250;
        widgets.addAll(_overlay(node.children[i], childX, childY));
      }
    }
    return widgets;
  }
}

class _DiagramPainter extends CustomPainter {
  final DiagramNode root;
  _DiagramPainter({required this.root});

  @override
  void paint(Canvas canvas, Size size) => _draw(canvas, root, 3000, 100);

  // In _DiagramPainter class - replace _draw method
  void _draw(Canvas canvas, DiagramNode node, double x, double y) {
    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final baseSpacing =
          BlockPositionManager.calculateOptimalSpacing(count, 0);
      final spacing = baseSpacing * 1.5; // CHANGED from 1.2 to 1.5
      final positions =
          BlockPositionManager.distributePositions(count, x, spacing);

      final paintLine = Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = positions[i];
        final childY = y + 250;

        final path = Path();
        path.moveTo(x, y + 40);
        path.quadraticBezierTo(x, y + 120, childX, childY - 40);
        canvas.drawPath(path, paintLine);

        // Distance label (same as before)
        if (child.distance > 0) {
          final midX = (x + childX) / 2;
          final midY = (y + 40 + childY - 40) / 2;
          String distanceText;
          if (child.distance < 0.001) {
            distanceText = '${(child.distance * 1000).toStringAsFixed(0)} m';
          } else if (child.distance < 1.0) {
            distanceText = '${(child.distance * 1000).toStringAsFixed(0)} m';
          } else {
            distanceText = '${child.distance.toStringAsFixed(2)} km';
          }
          final distanceTp = _text(distanceText, 10, Colors.blue.shade700,
              fontWeight: FontWeight.bold);
          final backgroundRect = Rect.fromCenter(
              center: Offset(midX, midY - 10),
              width: distanceTp.width + 8,
              height: distanceTp.height + 4);
          canvas.drawRRect(
              RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
              Paint()..color = Colors.white.withOpacity(0.9));
          canvas.drawRRect(
              RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
              Paint()
                ..color = Colors.blue.shade300
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
          distanceTp.paint(
              canvas,
              Offset(midX - distanceTp.width / 2,
                  midY - 10 - distanceTp.height / 2));
        }
        _draw(canvas, child, childX, childY);
      }
    }
    // Rest of drawing code continues...
    // Rest of the _draw method stays the same...
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 180, height: 90),
        const Radius.circular(14));
    Color fill;
    IconData icon;
    Color iconColor;

    if (node.isHeadend) {
      fill = const Color(0xFF1A237E);
      icon = Icons.router;
      iconColor = Colors.white;
    } else if (node.isCoupler && node.isCouplerOutput) {
      fill = const Color(0xFF0288D1);
      icon = Icons.output;
      iconColor = Colors.white;
    } else if (node.isSplitter && node.isSplitterOutput) {
      fill = const Color(0xFF7B1FA2);
      icon = Icons.output;
      iconColor = Colors.white;
    } else if (node.isSplitter) {
      fill = const Color(0xFF6A1B9A);
      icon = Icons.account_tree;
      iconColor = Colors.white;
    } else if (node.deviceType == 'pass') {
      fill = const Color(0xFF546E7A);
      icon = Icons.arrow_forward;
      iconColor = Colors.white;
    } else {
      fill = const Color(0xFF2E7D32);
      icon = Icons.circle;
      iconColor = Colors.white;
    }

    canvas.drawRRect(
        rect.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [fill, fill.withOpacity(0.8)]);
    canvas.drawRRect(
        rect,
        Paint()
          ..shader = gradient.createShader(
              Rect.fromCenter(center: Offset(x, y), width: 180, height: 90)));
    canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    _drawIcon(canvas, icon, Offset(x - 70, y), iconColor);
    final labelTp =
        _text(node.label, 14, Colors.white, fontWeight: FontWeight.bold);
    labelTp.paint(canvas, Offset(x - labelTp.width / 2, y - 22));
    if (node.isCouplerOutput || node.isSplitterOutput) {
      final nodeSignalText = '${node.signal.toStringAsFixed(2)} dBm';
      final sigTp = _text(nodeSignalText, 13, Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.bold);
      sigTp.paint(canvas, Offset(x - sigTp.width / 2, y + 2));

      // WDM Display - FIXED
      if (node.useWdm && node.wdmOutputPower != 0.0) {
        final wdmText =
            '${node.wdmOutputPower.toStringAsFixed(2)} dBm (PON 1310nm)';
        final wdmTp = _text(wdmText, 11, Colors.amber.shade200,
            fontWeight: FontWeight.w600);
        wdmTp.paint(canvas, Offset(x - wdmTp.width / 2, y + 18));
      }
    } else {
      if (node.deviceLoss != 0.0) {
        final lossText = '${node.deviceLoss.toStringAsFixed(2)} dB';
        final lossTp = _text(lossText, 12, Colors.white.withOpacity(0.95));
        lossTp.paint(canvas, Offset(x - lossTp.width / 2, y + 4));
      }
      final nodeSignalText = '${node.signal.toStringAsFixed(2)} dBm';
      final sigTp = _text(nodeSignalText, 10, Colors.white.withOpacity(0.8));
      sigTp.paint(canvas, Offset(x - sigTp.width / 2, y + 20));
    }
    String wavelengthText = '${node.wavelength}nm';
    if (node.useWdm) {
      wavelengthText += ' + WDM (${node.wdmLoss}dB)';
    }
    final wavelengthTp =
        _text(wavelengthText, 10, Colors.white.withOpacity(0.8));
    wavelengthTp.paint(canvas, Offset(x + 50, y - 35));
    if (node.isLeaf && !node.isHeadend) _drawHouse(canvas, Offset(x, y + 60));
  }

  void _drawIcon(
      Canvas canvas, IconData iconData, Offset position, Color color) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 24,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
    );

    final textSpan = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawHouse(Canvas canvas, Offset c) {
    final size = 24.0;
    final roof = Path();
    roof.moveTo(c.dx, c.dy - size * 0.5);
    roof.lineTo(c.dx - size * 0.7, c.dy);
    roof.lineTo(c.dx + size * 0.7, c.dy);
    roof.close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + size * 0.4), // FIXED: Added comma
                width: size * 1.2,
                height: size * 0.8),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFFFE082));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + size * 0.6), // FIXED: Added comma
                width: size * 0.35,
                height: size * 0.5),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF8B4513));
    canvas.drawCircle(Offset(c.dx + size * 0.3, c.dy + size * 0.3), size * 0.15,
        Paint()..color = const Color(0xFF64B5F6));
    canvas.drawRect(
        Rect.fromLTWH(
            c.dx + size * 0.3, c.dy - size * 0.6, size * 0.2, size * 0.3),
        Paint()..color = const Color(0xFF8B4513));
  }

  TextPainter _text(String text, double size, Color color,
      {FontWeight fontWeight = FontWeight.normal}) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: size, color: color, fontWeight: fontWeight)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
