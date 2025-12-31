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
  String? endpointName;
  String? endpointDescription;

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
    this.endpointName, // ADD THIS
    this.endpointDescription, // ADD THIS
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

// ---------------- SplitterCalculator (CORRECTED using calculator page logic) ----------------
class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};

    // Use EXACT values from calculator page
    final loss1550 = [-3.6, -6.8, -10.0, -13.0, -16.0, -19.5];
    final loss1310 = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];

    // The adjustment is based on splitterValue - 1.0
    final adjust = splitterValue - 1.0;

    result["LOSS-15 50"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value': double.parse((loss1550[i] + adjust).toStringAsFixed(2))
            });

    result["LOSS-13 10"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value': double.parse((loss1310[i] + adjust).toStringAsFixed(2))
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
  static const double blockWidth = 140.0; // Reduced to match new design
  static const double blockHeight = 80.0; // Reduced to match new design
  static const double minSpacing = 80.0; // Reduced for tighter layout

  static double calculateOptimalSpacing(int siblingCount, int level) {
    if (siblingCount <= 2) return 300.0; // Reduced
    if (siblingCount <= 4) return 400.0; // Reduced
    if (siblingCount <= 8) return 550.0; // Reduced
    return 650.0; // Reduced
  }

  static List<double> distributePositions(
      int count, double centerX, double spacing) {
    List<double> positions = [];
    final total = (count - 1) * spacing;
    final startX = centerX - total / 2;

    for (int i = 0; i < count; i++) {
      positions.add(startX + i * spacing);
    }

    return _resolveCollisions(positions, spacing);
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

  Future<void> _editCouplerLabel(DiagramNode node) async {
    final labelCtrl = TextEditingController(text: node.label);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8F00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Color(0xFFFF8F00)),
            ),
            const SizedBox(width: 12),
            const Text('Edit Coupler Label',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Label: ${node.label}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'New Label',
                hintText: 'e.g., A, B, C1, C2',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.label),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Ratio: ${node.couplerRatio ?? 50} : ${100 - (node.couplerRatio ?? 50)}',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This label will be applied to BOTH coupler outputs',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                final newLabel =
                    labelCtrl.text.isEmpty ? 'Coupler' : labelCtrl.text;

                // Find parent to update BOTH coupler children
                final parent = _findNode(root, node.parentId!);
                if (parent != null) {
                  // Update ALL coupler outputs from this parent
                  for (var child in parent.children) {
                    if (child.isCouplerOutput) {
                      child.label = newLabel;
                    }
                  }
                }

                // Force UI refresh
                _recalculateAll(root!);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update Label',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

// Update the _getBaseLabel method to handle coupler labels
  String _getBaseLabel(DiagramNode node) {
    // For coupler outputs, return the label as-is (it should already be "A" from your edit dialog)
    if (node.isCouplerOutput) {
      return node.label;
    }
    // Remove trailing numbers for splitter outputs
    else if (node.isSplitterOutput || node.deviceType == 'splitter') {
      return node.label.replaceAll(RegExp(r'\s+\d+$'), '');
    }
    // For everything else
    return node.label;
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

  List<double> _calculateCouplerLosses(
      int ratio, double inputPower, String wavelength,
      {bool isWdm = false}) {
    // For WDM, ALWAYS use 1310nm (LOSS-13 10) reference data
    final referenceWavelength = isWdm ? '1310' : wavelength;

    final calculator = CouplerCalculator(inputPower);
    final calculatedData = calculator.calculateLoss();

    final section = referenceWavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
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

    final loss1 = inputPower - val1;
    final loss2 = inputPower - val2;

    return [val1, val2, loss1, loss2];
  }

  void _recalculate(DiagramNode node) {
    if (node.children.isEmpty) return;

    final wavelength = node.wavelength;

    if (node.isCoupler && node.deviceConfig != null && !node.isCouplerOutput) {
      final parts = node.deviceConfig!.split('::');
      final ratio = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 50 : 50;

      // Recalculate coupler output powers with current input power
      final losses =
          _calculateCouplerLosses(ratio, node.signal, node.wavelength);
      final output1Power = losses[0];
      final output2Power = losses[1];

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final dLoss = child.fiberLoss; // Use stored fiber loss
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;

        if (i == 0) {
          // First output (left side)
          child.signal = output1Power - dLoss;
          child.deviceLoss = losses[2];
        } else if (i == 1) {
          // Second output (right side)
          child.signal = output2Power - dLoss;
          child.deviceLoss = losses[3];
        }

        if (node.useWdm) {
          final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
          final wdmLosses = _calculateCouplerLosses(
              ratio, wdmInput, '1310', // CHANGED: Force 1310
              isWdm: true);

          if (i == 0) {
            child.wdmOutputPower = wdmLosses[0] - dLoss;
          } else if (i == 1) {
            child.wdmOutputPower = wdmLosses[1] - dLoss;
          }
        } else {
          child.wdmOutputPower = 0.0;
        }

        _recalculate(child);
      }
    } else if (node.isSplitter && node.isSplitterOutput) {
      for (final child in node.children) {
        child.wavelength = wavelength;
        child.useWdm = node.useWdm;
        child.wdmLoss = node.wdmLoss;
      }
    } else if (node.deviceType == 'splitter' &&
        node.deviceConfig != null &&
        node.children.isNotEmpty) {
      // This handles the parent splitter node that has multiple outputs
      final parts = node.deviceConfig!.split('::');
      final split = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 2 : 2;
      final splitterVal =
          parts.length > 1 ? double.tryParse(parts[1]) ?? 1.0 : 1.0;

      final calc = SplitterCalculator(splitterVal);
      final all = calc.calculateLoss();
      final section = 'LOSS-13 10'; // Always use LOSS-13 10
      final sec = all[section]!;
      final entry =
          sec.firstWhere((e) => e['split'] == split, orElse: () => sec.first);

      final splitterLossValue = (entry['value'] as num).toDouble();
      final splitterLossDisplay = splitterLossValue.abs();

      // Get fiber loss from first child
      final firstChild = node.children[0];
      final dLoss = firstChild.fiberLoss;

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
        _recalculateAll(root!); // Changed from _recalculate to _recalculateAll
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

      // Propagate settings to ALL nodes first
      _propagateSettings(root!);

      // Then recalculate all values
      _recalculateAll(root!);
    });
  }

// Add this helper method
  void _propagateSettings(DiagramNode node) {
    for (var child in node.children) {
      child.wavelength = node.wavelength;
      child.useWdm = node.useWdm;
      child.wdmLoss = node.wdmLoss;
      _propagateSettings(child);
    }
  }

// Add this helper method after _propagateSettings
  void _resetWdmInTree(DiagramNode node) {
    node.wdmOutputPower = 0.0;
    for (var child in node.children) {
      _resetWdmInTree(child);
    }
  }

  void _recalculateAll(DiagramNode node) {
    if (node.children.isEmpty) return;

    for (var child in node.children) {
      child.wavelength = node.wavelength;
      child.useWdm = node.useWdm;
      child.wdmLoss = node.wdmLoss;

      if (child.isCouplerOutput) {
        // Get the parent node to find both coupler outputs
        final parentNode = node;

        // Find which output this is by checking the FIRST child's ratio
        int actualRatio = 50;
        if (parentNode.children.isNotEmpty &&
            parentNode.children[0].couplerRatio != null) {
          // Use the first child's ratio as the reference
          actualRatio = parentNode.children[0].couplerRatio!;
        }

        final fiberLoss = child.fiberLoss;

        // Determine which output this is (left=0, right=1)
        final isFirstOutput = (parentNode.children.indexOf(child) == 0);

        // Get fresh calculations using the ACTUAL ratio from first child
        final losses = _calculateCouplerLosses(
            actualRatio, parentNode.signal, parentNode.wavelength);

        if (isFirstOutput) {
          child.signal = losses[0] - fiberLoss;
          child.deviceLoss = losses[2];
          child.couplerRatio = actualRatio; // Update to match
        } else {
          child.signal = losses[1] - fiberLoss;
          child.deviceLoss = losses[3];
          child.couplerRatio = 100 - actualRatio; // Update to match
        }

        // WDM calculation
        if (parentNode.useWdm) {
          final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
          final wdmLosses = _calculateCouplerLosses(
              actualRatio, wdmInput, '1310',
              isWdm: true);

          if (isFirstOutput) {
            child.wdmOutputPower = wdmLosses[0] - fiberLoss;
          } else {
            child.wdmOutputPower = wdmLosses[1] - fiberLoss;
          }
        } else {
          child.wdmOutputPower = 0.0;
        }
      } else if (child.isSplitterOutput && child.deviceConfig != null) {
        final parts = child.deviceConfig!.split('::');
        if (parts.length >= 2) {
          final split = int.tryParse(parts[0]) ?? 2;
          final splitterVal = double.tryParse(parts[1]) ?? 1.0;
          final fiberLoss = child.fiberLoss;

          final calc = SplitterCalculator(splitterVal);
          final all = calc.calculateLoss();
          final section =
              node.wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
          final sec = all[section]!;
          final entry = sec.firstWhere(
            (e) => e['split'] == split,
            orElse: () => sec.first,
          );

          final splitterLossValue = (entry['value'] as num).toDouble();
          final splitterLossDisplay = splitterLossValue.abs();

          child.signal = node.signal - splitterLossDisplay - fiberLoss;
          child.deviceLoss = splitterLossDisplay - fiberLoss;
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
              TextField(
                controller: TextEditingController(),
                decoration: InputDecoration(
                    labelText: 'Endpoint Name (Optional)',
                    hintText: 'e.g., John Doe',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person)),
                onChanged: (value) =>
                    labelCtrl.text = '${labelCtrl.text.split('|')[0]}|$value',
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., Building A, Floor 3',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.description)),
                onChanged: (value) =>
                    labelCtrl.text = '${labelCtrl.text.split('||')[0]}||$value',
              ),
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
              // In _addSingleChild method, find the onPressed section and replace it:
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

                  // Get endpoint info - these should be separate text fields
                  // You need to create these controllers in your dialog
                  // For now, let's assume you have endpointNameCtrl and endpointDescCtrl
                  final endpointNameCtrl = TextEditingController();
                  final endpointDescCtrl = TextEditingController();

                  final endpointName = endpointNameCtrl.text.isNotEmpty
                      ? endpointNameCtrl.text
                      : null;
                  final endpointDesc = endpointDescCtrl.text.isNotEmpty
                      ? endpointDescCtrl.text
                      : null;

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
                    endpointName: endpointName,
                    endpointDescription: endpointDesc,
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
    final labelCtrl = TextEditingController(text: 'Coupler'); // ADD THIS LINE
    final couplerName = labelCtrl.text.isEmpty ? 'Coupler' : labelCtrl.text;
    final distanceCtrl = TextEditingController(text: '0.5');
    int ratio = 50;
    bool showWdmWarning = false;
    String distanceUnit = 'km';
    bool showDistanceInput = !parent.isHeadend;
    distanceCtrl.text = showDistanceInput ? '0.5' : '0.0';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
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
                    setInner(() => ratio = v ?? ratio);
                    checkWdmValidation();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller:
                      labelCtrl, // Add: final labelCtrl = TextEditingController(text: 'Coupler');
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
                      // Calculation preview
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

                        // GET THE COUPLER NAME FROM THE TEXT FIELD
                        final couplerName =
                            labelCtrl.text.isEmpty ? 'Coupler' : labelCtrl.text;

                        final fiberLoss = distance * fiberAttenuationDbPerKm;

                        final losses = _calculateCouplerLosses(
                            ratio, parent.signal, parent.wavelength);
                        final output1Power = losses[0];
                        final output2Power = losses[1];

                        final wdmLoss = parent.useWdm ? parent.wdmLoss : 0.0;

                        // WDM Power Calculation
                        double wdm1Power = 0.0;
                        double wdm2Power = 0.0;

                        if (parent.useWdm) {
                          final wdmInput =
                              double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
                          // REMOVE parent.wavelength - WDM always uses 1310nm reference
                          final wdmLosses = _calculateCouplerLosses(
                              ratio,
                              wdmInput,
                              '1310', // CHANGED: Force 1310 instead of parent.wavelength
                              isWdm: true);
                          wdm1Power = wdmLosses[0] - fiberLoss;
                          wdm2Power = wdmLosses[1] - fiberLoss;
                        }

                        final output1Signal =
                            output1Power - fiberLoss; // Remove wdmLoss
                        final output2Signal =
                            output2Power - fiberLoss; // Remove wdmLoss

                        final device1Loss = losses[2]; // Remove wdmLoss
                        final device2Loss = losses[3]; // Remove wdmLoss
                        // 1) In _addCoupler(...), set both outputs to use EXACT entered name (no auto-append ratio).
// Replace the two DiagramNode creations for output1 and output2 with the following:

                        final output1 = DiagramNode(
                          id: _nodeCounter++,
                          label:
                              couplerName, // keep the exact user-entered name
                          signal: output1Signal,
                          distance: distance,
                          parentId: parent.id,
                          deviceType: 'coupler',
                          deviceConfig: '$ratio::1.0',
                          wavelength: parent.wavelength,
                          useWdm: parent.useWdm,
                          wdmLoss: parent.wdmLoss,
                          wdmOutputPower: wdm1Power,
                          couplerRatio: ratio, // this block's side
                          isCouplerOutput: true,
                          deviceLoss: device1Loss,
                          fiberLoss: fiberLoss,
                        );

                        final output2 = DiagramNode(
                          id: _nodeCounter++,
                          label:
                              couplerName, // keep same name; ratio will be drawn in painter
                          signal: output2Signal,
                          distance: distance,
                          parentId: parent.id,
                          deviceType: 'coupler',
                          deviceConfig: '$ratio::1.0',
                          wavelength: parent.wavelength,
                          useWdm: parent.useWdm,
                          wdmLoss: parent.wdmLoss,
                          wdmOutputPower: wdm2Power,
                          couplerRatio: 100 - ratio, // other side
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

  void _debugPrintLabels(DiagramNode node, int depth) {
    String indent = '  ' * depth;
    print('$indent${node.label} (ID: ${node.id}, Type: ${node.deviceType})');
    for (var child in node.children) {
      _debugPrintLabels(child, depth + 1);
    }
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
                // In _addSplitter dialog, update the calculation preview section:
                Builder(
                  builder: (context) {
                    double distance = showDistanceInput
                        ? (double.tryParse(distanceCtrl.text) ?? 0.5)
                        : 0.0;

                    if (showDistanceInput && distanceUnit == 'm') {
                      distance = distance / 1000;
                    }

                    final fiberLoss = distance * fiberAttenuationDbPerKm;

                    // Use correct splitter value logic
                    final splitterVal =
                        1.0; // Default value as in calculator page

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
                              'Splitter Loss: ${splitterLossDisplay.toStringAsFixed(1)} dB',
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
                              'Output Power: ${outputSignal.toStringAsFixed(1)} dBm',
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
                  final baseLabel =
                      labelCtrl.text.isEmpty ? 'Splitter' : labelCtrl.text;

                  for (int i = 0; i < split; i++) {
                    final outputNode = DiagramNode(
                      id: _nodeCounter++,
                      label: baseLabel,
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
      // Find parent to get both outputs
      final parent = _findNode(root, node.parentId!);
      if (parent == null) return;

      // Get current ratio from the parent's deviceConfig, not from the clicked node
      final parentConfig =
          parent.children.isNotEmpty && parent.children[0].deviceConfig != null
              ? parent.children[0].deviceConfig!.split('::')
              : ['50'];
      int currentRatio = int.tryParse(parentConfig[0]) ?? 50;
      int newRatio = currentRatio;
      bool showWdmWarning = false;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
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
                    setInner(() => newRatio = v ?? newRatio);
                    checkWdmValidation();
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
                                fontWeight: FontWeight.bold),
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
                                fontSize: 12),
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
                                  newRatio,
                                  wdmInput,
                                  '1310', // CHANGED: Force 1310
                                  isWdm: true);
                              wdm1Power = wdmLosses[0] - fiberLoss;
                              wdm2Power = wdmLosses[1] - fiberLoss;
                            }

                            // Update BOTH outputs correctly
                            parent.children[0].couplerRatio = newRatio;
                            parent.children[0].signal =
                                output1Power - fiberLoss;
                            parent.children[0].deviceLoss = losses[2];
                            parent.children[0].deviceConfig = '$newRatio::1.0';
                            parent.children[0].wdmOutputPower = wdm1Power;

                            if (parent.children.length > 1) {
                              parent.children[1].couplerRatio = 100 - newRatio;
                              parent.children[1].label =
                                  parent.children[1].label;
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

    if (node.isCouplerOutput) {
      final parent = _findNode(root, node.parentId!);
      if (parent != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Coupler Outputs?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
                'This will delete both coupler outputs and all their descendants.'),
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
                      parent.children
                          .removeWhere((child) => child.isCouplerOutput);
                      _recalculate(root!);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Delete Both',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          ),
        );
        return;
      }
    } else if (node.isSplitterOutput) {
      final parent = _findNode(root, node.parentId!);
      if (parent != null) {
        // Find all splitter outputs with same config
        final deviceConfig = node.deviceConfig;
        final splitterOutputs = parent.children
            .where((child) =>
                child.isSplitterOutput && child.deviceConfig == deviceConfig)
            .toList();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Splitter Outputs?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
                'This will delete all ${splitterOutputs.length} splitter outputs and their descendants.'),
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
                      parent.children.removeWhere((child) =>
                          child.isSplitterOutput &&
                          child.deviceConfig == deviceConfig);
                      _recalculate(root!);
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('Delete All (${splitterOutputs.length})',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
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
            'Delete "${node.label}" and ${_countDescendants(node)} descendant(s)?'),
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
                    parent.children.removeWhere((c) => c.id == node.id);
                    _recalculate(root!);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Delete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
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
      'endpointName': node.endpointName, // ADD THIS
      'endpointDescription': node.endpointDescription, // ADD THIS
      'children':
          node.children.map((child) => _serializeDiagramTree(child)).toList(),
    };
  }

  List<DiagramNode> _findSiblingSplitterOutputs(DiagramNode node) {
    final parent = _findNode(root, node.parentId!);
    if (parent == null) return [];

    return parent.children
        .where((child) =>
            child.isSplitterOutput && child.deviceConfig == node.deviceConfig)
        .toList();
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
      endpointName: data['endpointName'], // ADD THIS
      endpointDescription: data['endpointDescription'], // ADD THIS
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

  Future<void> _editEndpointInfo(DiagramNode node) async {
    final nameCtrl = TextEditingController(text: node.endpointName ?? '');
    final descCtrl =
        TextEditingController(text: node.endpointDescription ?? '');
    final labelCtrl = TextEditingController(text: node.label);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Endpoint Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: 'Node Label',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Endpoint Name (e.g., Person/Building)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (e.g., Location, Details)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
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
                    const Text('Current Information:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    Text('Power: ${node.signal.toStringAsFixed(2)} dBm'),
                    Text('Distance: ${node.distance.toStringAsFixed(2)} km'),
                    Text('Wavelength: ${node.wavelength}nm'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            // Update the _editEndpointInfo method's onPressed action:
            onPressed: () {
              setState(() {
                node.label =
                    labelCtrl.text.isEmpty ? 'Endpoint' : labelCtrl.text;
                node.endpointName =
                    nameCtrl.text.isEmpty ? null : nameCtrl.text;
                node.endpointDescription =
                    descCtrl.text.isEmpty ? null : descCtrl.text;

                // If this is a coupler output, also update the parent coupler's children
                if (node.isCouplerOutput) {
                  final parent = _findNode(root, node.parentId!);
                  if (parent != null) {
                    // Find all coupler outputs from the same parent and update their labels
                    for (var child in parent.children) {
                      if (child.isCouplerOutput) {
                        child.label =
                            labelCtrl.text.isEmpty ? 'Coupler' : labelCtrl.text;
                      }
                    }
                  }
                }

                // Force recalculation to ensure power values are updated
                _recalculateAll(root!);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Add this helper method to calculate final power including all losses
  double _calculateFinalPower(DiagramNode node) {
    // If it's a coupler output, the signal already includes all losses
    if (node.isCouplerOutput || node.isSplitterOutput) {
      return node.signal;
    }

    // For regular nodes, calculate: input - deviceLoss - fiberLoss
    final parent = _findNode(root, node.parentId!);
    if (parent != null) {
      return node.signal; // This should already be calculated correctly
    }

    return node.signal;
  }

  void _showNodeOptions(DiagramNode node) {
    // ALLOW adding devices to ALL nodes including headend
    final canAddDevices = true;
    final canEdit =
        (node.isCouplerOutput || node.isSplitterOutput) && !node.isHeadend;
    final canDelete = !node.isHeadend;
    final isEndpoint = node.isLeaf && !node.isHeadend;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true, // ADD THIS for better scrolling
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          // WRAP with SingleChildScrollView
          child: Wrap(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Node Options - ${_getBaseLabel(node)}', // USE HELPER
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${node.isHeadend ? "Headend" : node.isSplitterOutput ? "Splitter Output" : node.isCouplerOutput ? "Coupler Output" : node.deviceType}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (isEndpoint && node.endpointName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Endpoint: ${node.endpointName}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                  ],
                  if (isEndpoint && node.endpointDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Description: ${node.endpointDescription}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),

            // Add Coupler - Show for ALL nodes
            if (canAddDevices)
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.call_split, color: Colors.blue)),
                title: const Text('Add Coupler',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '2-port unequal split device',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _addCoupler(node);
                },
              ),

            // Add Splitter - Show for ALL nodes
            if (canAddDevices)
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        const Icon(Icons.account_tree, color: Colors.purple)),
                title: const Text('Add Splitter',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '1xN equal split device',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _addSplitter(node);
                },
              ),

            if (canAddDevices) const Divider(),

            // Edit Endpoint Info - Show for leaf nodes only
            if (isEndpoint)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: Colors.green),
                ),
                title: const Text('Edit Endpoint Info',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  node.endpointName ?? 'Add name/description',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _editEndpointInfo(node);
                },
              ),

            // In _showNodeOptions method, update the "Edit Node" section:
            if (canEdit)
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit, color: Colors.orange)),
                title: Text(
                  node.isCouplerOutput
                      ? 'Edit Coupler Label' // CHANGED from 'Edit Coupler Ratio'
                      : 'Edit Splitter Configuration',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  node.isCouplerOutput
                      ? 'Modify coupler name/label' // CHANGED
                      : 'Modify splitter configuration',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (node.isCouplerOutput) {
                    _editCouplerLabel(node); // CHANGED: Call new method
                  } else if (node.isSplitterOutput) {
                    _editSplitterNode(node);
                  }
                },
              ),

            // Delete Node - Show for all non-headend nodes
            if (canDelete)
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete, color: Colors.red)),
                title: const Text('Delete Node',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Remove this node and all its children',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteNode(node);
                },
              ),

            const Divider(),

            // Close
            ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Close',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx)),

            const SizedBox(height: 20), // Add extra space at bottom
          ]),
        ),
      ),
    );
  }

  Future<void> _editSplitterNode(DiagramNode node) async {
    // Find all splitter outputs that belong to the same parent and have same config
    final parent = _findNode(root, node.parentId!);
    if (parent == null) return;

    // Find all splitter outputs that share the same parent and config
    final splitterOutputs = parent.children
        .where((child) =>
            child.isSplitterOutput && child.deviceConfig == node.deviceConfig)
        .toList();

    if (splitterOutputs.isEmpty) return;

    // Get current split configuration
    final firstOutput = splitterOutputs.first;
    final parts = firstOutput.deviceConfig?.split('::') ?? ['2', '0.0'];
    final currentSplit = int.tryParse(parts[0]) ?? 2;
    final currentSplitterVal = double.tryParse(parts[1]) ?? 0.0;

    final labelCtrl = TextEditingController(
        text: firstOutput.label.replaceAll(RegExp(r'\s+\d+$'), ''));
    final distanceCtrl =
        TextEditingController(text: firstOutput.distance.toString());
    int newSplit = currentSplit;
    final splits = [2, 4, 8, 16, 32, 64];
    String distanceUnit = 'km';
    double distance = firstOutput.distance;

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
                child: const Icon(Icons.edit, color: Color(0xFF7B1FA2)),
              ),
              const SizedBox(width: 12),
              const Text('Edit Splitter Configuration',
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
                  value: newSplit,
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
                  onChanged: (v) => setInner(() => newSplit = v ?? newSplit),
                ),
                const SizedBox(height: 16),

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

                // Calculation preview
                Builder(
                  builder: (context) {
                    double updatedDistance =
                        double.tryParse(distanceCtrl.text) ?? distance;
                    if (distanceUnit == 'm') {
                      updatedDistance = updatedDistance / 1000;
                    }

                    final fiberLoss = updatedDistance * fiberAttenuationDbPerKm;
                    final splitterVal = 0.0;

                    final calc = SplitterCalculator(splitterVal);
                    final all = calc.calculateLoss();
                    final section = parent.wavelength == '1310'
                        ? 'LOSS-13 10'
                        : 'LOSS-15 50';
                    final sec = all[section]!;
                    final entry = sec.firstWhere(
                      (e) => e['split'] == newSplit,
                      orElse: () => sec.first,
                    );

                    final splitterLossValue =
                        (entry['value'] as num).toDouble();
                    final splitterLossDisplay = splitterLossValue.abs();
                    final finalDeviceLoss = splitterLossDisplay - fiberLoss;
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
                                  'Fiber Loss: 0.25 dB/km',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Splitter Loss: ${splitterLossDisplay.toStringAsFixed(1)} dB',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                            ),
                          ),
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
                          Text(
                            'Output Power: ${outputSignal.toStringAsFixed(1)} dBm',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  // Remove all existing splitter outputs
                  parent.children.removeWhere((child) =>
                      child.isSplitterOutput &&
                      child.deviceConfig == node.deviceConfig);

                  // Calculate new values
                  double updatedDistance =
                      double.tryParse(distanceCtrl.text) ?? distance;
                  if (distanceUnit == 'm') {
                    updatedDistance = updatedDistance / 1000;
                  }

                  final fiberLoss = updatedDistance * fiberAttenuationDbPerKm;
                  final splitterVal = 0.0;

                  final calc = SplitterCalculator(splitterVal);
                  final all = calc.calculateLoss();
                  final section =
                      parent.wavelength == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
                  final sec = all[section]!;
                  final entry = sec.firstWhere(
                    (e) => e['split'] == newSplit,
                    orElse: () => sec.first,
                  );

                  final splitterLossValue = (entry['value'] as num).toDouble();
                  final splitterLossDisplay = splitterLossValue.abs();
                  final finalDeviceLoss = splitterLossDisplay - fiberLoss;
                  final outputSignal =
                      parent.signal - splitterLossDisplay - fiberLoss;

                  // Create new splitter outputs
                  final baseLabel =
                      labelCtrl.text.isEmpty ? 'Splitter' : labelCtrl.text;
                  for (int i = 0; i < newSplit; i++) {
                    final outputNode = DiagramNode(
                      id: _nodeCounter++,
                      label: baseLabel,
                      signal: outputSignal,
                      distance: updatedDistance,
                      parentId: parent.id,
                      deviceType: 'splitter',
                      deviceConfig: '$newSplit::$splitterVal',
                      wavelength: parent.wavelength,
                      useWdm: parent.useWdm,
                      wdmLoss: parent.wdmLoss,
                      isSplitterOutput: true,
                      deviceLoss: finalDeviceLoss,
                      fiberLoss: fiberLoss,
                    );
                    parent.children.add(outputNode);
                  }

                  _recalculate(root!);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Update Splitter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        );
      }),
    );
  }

// Add this method for editing headend
  void _showEditHeadendDialog() {
    final nameCtrl = TextEditingController(text: root!.label);
    final powerCtrl =
        TextEditingController(text: root!.signal.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.edit, color: Color(0xFF1A237E)),
            ),
            const SizedBox(width: 12),
            const Text('Edit Headend',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Headend Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.router),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: powerCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Power (dBm)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.flash_on),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                root!.label = nameCtrl.text.isEmpty ? 'EDFA' : nameCtrl.text;
                root!.signal =
                    double.tryParse(powerCtrl.text) ?? defaultHeadendDbm;
                _recalculateAll(root!);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
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
        foregroundColor: Colors.white, // Add this line
        iconTheme: const IconThemeData(color: Colors.white), // Add this line
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _nodeCounter = 0;
                _initRoot();
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reset Diagram',
          ),
          IconButton(
            onPressed: _saveDiagram,
            icon: const Icon(Icons.download, color: Colors.white70),
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
                  // Reset all WDM values in tree
                  _resetWdmInTree(root!);
                }
                _recalculateAll(root!); // Changed from _recalculate
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
                    _recalculateAll(root!); // Changed from _recalculate
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

  List<Widget> _overlay(DiagramNode node, double x, double y, {int level = 0}) {
    final widgets = <Widget>[];

    // Clickable area for node
    widgets.add(Positioned(
        left: x - 100,
        top: y - 50,
        width: 200,
        height: 100,
        child: GestureDetector(
            onTap: () => onTapNode(node),
            behavior: HitTestBehavior.translucent,
            child: Container())));
// Add clickable area for the "add" button on leaf nodes - MOVED CLOSER
    if (node.isLeaf && !node.isHeadend) {
      widgets.add(Positioned(
          left: x - 15,
          top: y + 35, // Changed from y + 45 to y + 35
          width: 30,
          height: 30,
          child: GestureDetector(
              onTap: () => onTapNode(node),
              behavior: HitTestBehavior.translucent,
              child: Container())));
    }

    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final spacing =
          BlockPositionManager.calculateOptimalSpacing(count, level);
      final positions =
          BlockPositionManager.distributePositions(count, x, spacing);

      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = positions[i];
        final childY = y + 250;
        widgets.addAll(_overlay(child, childX, childY, level: level + 1));
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
// Update line colors to match new theme
  void _draw(Canvas canvas, DiagramNode node, double x, double y) {
    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final spacing = BlockPositionManager.calculateOptimalSpacing(count, 0);
      final positions =
          BlockPositionManager.distributePositions(count, x, spacing);

      final paintLine = Paint()
        ..color = Color(0xFF424242) // Professional gray
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = positions[i];
        final childY = y + 250;

        canvas.drawLine(Offset(x, y + 45), Offset(x, y + 150), paintLine);
        canvas.drawLine(Offset(x, y + 150), Offset(childX, y + 150), paintLine);
        canvas.drawLine(
            Offset(childX, y + 150), Offset(childX, childY - 45), paintLine);

        if (child.distance > 0) {
          String distanceText;
          if (child.distance < 1.0) {
            distanceText = '${(child.distance * 1000).toStringAsFixed(0)}m';
          } else {
            distanceText = '${child.distance.toStringAsFixed(2)}km';
          }

          final distanceTp = _text(distanceText, 10, Colors.white,
              fontWeight: FontWeight.bold);
          final bgRect = Rect.fromCenter(
              center: Offset(childX, y + 150),
              width: distanceTp.width + 16,
              height: 20);

          // Professional gradient background
          final gradient = LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

          canvas.drawRRect(
              RRect.fromRectAndRadius(bgRect, const Radius.circular(10)),
              Paint()..shader = gradient.createShader(bgRect));

          distanceTp.paint(
              canvas,
              Offset(childX - distanceTp.width / 2,
                  y + 150 - distanceTp.height / 2));
        }
        _draw(canvas, child, childX, childY);
      }
    }
    if (node.isHeadend) {
      _drawHeadendBlock(canvas, x, y, node);
    } else if (node.isCouplerOutput) {
      _drawCouplerBlock(canvas, x, y, node);
    } else if (node.isSplitterOutput) {
      _drawSplitterBlock(canvas, x, y, node);
    } else {
      _drawStandardBlock(canvas, x, y, node);
    }

    if (node.isLeaf && !node.isHeadend) {
      _drawHouseIcon(canvas, Offset(x, y + 100), node);
    }
  }

  void _drawHeadendBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 140.0; // Slightly wider
    final blockHeight = 72.0; // Increased for consistency
    final headerHeight = 22.0;

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.fill);

    final mainRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y), width: blockWidth, height: blockHeight),
        const Radius.circular(6));

    final headerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
            width: blockWidth,
            height: headerHeight),
        const Radius.circular(6));

    final headerGradient = LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    canvas.drawRRect(
        headerRect,
        Paint()
          ..shader = headerGradient.createShader(Rect.fromCenter(
              center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
              width: blockWidth,
              height: headerHeight)));

    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Color(0xFF1976D2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Header text - always show "Headend"
    final headerTp =
        _text('Headend', 11, Colors.white, fontWeight: FontWeight.bold);
    headerTp.paint(
        canvas,
        Offset(x - headerTp.width / 2,
            y - blockHeight / 2 + headerHeight / 2 - headerTp.height / 2));

    // Body content - Name and Power
    String displayName = node.label.isEmpty ? 'EDFA' : node.label;
    final nameTp =
        _text(displayName, 12, Colors.black87, fontWeight: FontWeight.w600);
    nameTp.paint(canvas, Offset(x - nameTp.width / 2, y - 10));

    final powerTp = _text(
        '${node.signal.toStringAsFixed(1)} dBm', 13, Color(0xFF4CAF50),
        fontWeight: FontWeight.bold);
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, y + 10));
  }

  void _drawCouplerBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 120.0;
    final blockHeight = 90.0; // Increased height to fit all info
    final headerHeight = 22.0;

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.fill);

    // Main block
    final mainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );

    // Header gradient
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
          width: blockWidth,
          height: headerHeight),
      const Radius.circular(6),
    );
    final headerGradient = const LinearGradient(
      colors: [Color(0xFFFF8F00), Color(0xFFEF6C00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas.drawRRect(
        headerRect,
        Paint()
          ..shader = headerGradient.createShader(Rect.fromCenter(
            center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
            width: blockWidth,
            height: headerHeight,
          )));

    // Body
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = const Color(0xFFFF8F00)
          ..style = PaintingStyle.stroke // Fix: PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // HEADER: Display user-entered label (e.g., "abc1")
    final label = node.label.isEmpty ? 'Coupler' : node.label;
    final nameTp = _text(label, 10, Colors.white, fontWeight: FontWeight.bold);

    if (nameTp.width > blockWidth - 10) {
      final shorterTp =
          _text(label, 8, Colors.white, fontWeight: FontWeight.bold);
      shorterTp.paint(
          canvas,
          Offset(x - shorterTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - shorterTp.height / 2));
    } else {
      nameTp.paint(
          canvas,
          Offset(x - nameTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2));
    }

    // BODY CONTENT: Display in order - Ratio, Input dBm, Final Power
    double contentY = y - 18;

    // 1. Ratio (e.g., "30")
    final sideRatio = node.couplerRatio ?? 50;
    final ratioTp = _text('$sideRatio', 13, const Color(0xFFEF6C00),
        fontWeight: FontWeight.bold);
    ratioTp.paint(canvas, Offset(x - ratioTp.width / 2, contentY));

    contentY += 18;

    // 2. Input Power (parent's signal before losses)
    // This needs to be calculated from parent
    final inputPowerText =
        'In: ${_getParentPower(node).toStringAsFixed(1)} dBm';
    final inputTp =
        _text(inputPowerText, 9, Colors.black54, fontWeight: FontWeight.w500);
    inputTp.paint(canvas, Offset(x - inputTp.width / 2, contentY));

    contentY += 16;

    // 3. Final Output Power
    final finalPower = node.signal;
    final powerTp = _text(
        '${finalPower.toStringAsFixed(1)} dBm', 11, const Color(0xFF4CAF50),
        fontWeight: FontWeight.bold);
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, contentY));
  }

// Helper method to get parent power (add this near other helper methods)
  double _getParentPower(DiagramNode node) {
    // For coupler output, we need to find the parent's signal
    // The parent signal is stored before coupler loss is applied
    if (node.parentId != null) {
      final parent = _findNodeInTree(root, node.parentId!);
      if (parent != null) {
        return parent.signal;
      }
    }
    return 0.0;
  }

  DiagramNode? _findNodeInTree(DiagramNode? current, int targetId) {
    if (current == null) return null;
    if (current.id == targetId) return current;
    for (var child in current.children) {
      final found = _findNodeInTree(child, targetId);
      if (found != null) return found;
    }
    return null;
  }

  void _drawSplitterBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 120.0;
    final blockHeight = 90.0; // Increased height
    final headerHeight = 22.0;

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.fill);

    final mainRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y), width: blockWidth, height: blockHeight),
        const Radius.circular(6));

    final headerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
            width: blockWidth,
            height: headerHeight),
        const Radius.circular(6));

    final headerGradient = LinearGradient(
      colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    canvas.drawRRect(
        headerRect,
        Paint()
          ..shader = headerGradient.createShader(Rect.fromCenter(
              center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
              width: blockWidth,
              height: headerHeight)));

    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Color(0xFF7B1FA2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // HEADER: Display user-entered label
    final displayName = node.label.isEmpty ? 'Splitter' : node.label;
    final nameTp =
        _text(displayName, 10, Colors.white, fontWeight: FontWeight.bold);

    if (nameTp.width > blockWidth - 10) {
      final shorterTp =
          _text(displayName, 8, Colors.white, fontWeight: FontWeight.bold);
      shorterTp.paint(
          canvas,
          Offset(x - shorterTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - shorterTp.height / 2));
    } else {
      nameTp.paint(
          canvas,
          Offset(x - nameTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2));
    }

    // BODY: Display in order - Split Ratio, Input dBm, Final Power
    double contentY = y - 18;

    // 1. Split ratio (e.g., "1x2")
    String splitInfo = '1x?';
    if (node.deviceConfig != null) {
      final parts = node.deviceConfig!.split('::');
      if (parts.isNotEmpty) {
        final split = int.tryParse(parts[0]) ?? 2;
        splitInfo = '1x$split';
      }
    }
    final splitTp =
        _text(splitInfo, 13, Color(0xFF7B1FA2), fontWeight: FontWeight.bold);
    splitTp.paint(canvas, Offset(x - splitTp.width / 2, contentY));

    contentY += 18;

    // 2. Input Power (parent's signal)
    final inputPowerText =
        'In: ${_getParentPower(node).toStringAsFixed(1)} dBm';
    final inputTp =
        _text(inputPowerText, 9, Colors.black54, fontWeight: FontWeight.w500);
    inputTp.paint(canvas, Offset(x - inputTp.width / 2, contentY));

    contentY += 16;

    // 3. Final Output Power
    final finalPower = node.signal;
    final powerTp = _text(
        '${finalPower.toStringAsFixed(1)} dBm', 11, const Color(0xFF4CAF50),
        fontWeight: FontWeight.bold);
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, contentY));
  }

  void _drawStandardBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 120.0;
    final blockHeight = 72.0;
    final headerHeight = 22.0;

    // Draw main rectangle
    final mainRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y), width: blockWidth, height: blockHeight),
        const Radius.circular(6));

    // Draw header background (dark blue)
    final headerRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
            width: blockWidth,
            height: headerHeight),
        const Radius.circular(6));

    final headerGradient = LinearGradient(
      colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    canvas.drawRRect(
        headerRect,
        Paint()
          ..shader = headerGradient.createShader(Rect.fromCenter(
              center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
              width: blockWidth,
              height: headerHeight)));

    // Draw main background
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);

    // Draw border
    canvas.drawRRect(
        mainRect,
        Paint()
          ..color = const Color(0xFF1A237E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // Header text - node name - JUST display the label as-is
    final displayName = node.label.isEmpty ? 'Node' : node.label;
    final nameTp =
        _text(displayName, 10, Colors.white, fontWeight: FontWeight.bold);

    // Adjust font size if name is too long
    if (nameTp.width > blockWidth - 10) {
      final shorterTp =
          _text(displayName, 8, Colors.white, fontWeight: FontWeight.bold);
      shorterTp.paint(
          canvas,
          Offset(x - shorterTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - shorterTp.height / 2));
    } else {
      nameTp.paint(
          canvas,
          Offset(x - nameTp.width / 2,
              y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2));
    }

    // Main content - power value
    final powerTp = _text(
        '${node.signal.toStringAsFixed(1)} dBm', 12, Colors.black87,
        fontWeight: FontWeight.bold);
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, y + 5));
  }

  void _drawHouseIcon(Canvas canvas, Offset center, DiagramNode node) {
    final c = center;

    // [Keep all existing house drawing code until the end, then add:]

    // Display endpoint data

    // Shadow
    final shadowRect =
        Rect.fromCenter(center: Offset(c.dx, c.dy + 12), width: 36, height: 8);
    canvas.drawOval(shadowRect, Paint()..color = const Color(0x22000000));

    // House body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 40, height: 28),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, Paint()..color = Colors.white);
    canvas.drawRRect(
        bodyRect,
        Paint()
          ..color = Colors.red.shade300
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Roof
    final roofPath = Path()
      ..moveTo(c.dx, c.dy - 24)
      ..lineTo(c.dx - 26, c.dy - 8)
      ..lineTo(c.dx + 26, c.dy - 8)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = Colors.red.shade700);

    // Chimney
    final chimneyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(c.dx + 10, c.dy - 20), width: 6, height: 12),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(chimneyRect, Paint()..color = Colors.red.shade900);

    // Circular attic window
    canvas.drawCircle(
        Offset(c.dx, c.dy - 14), 4, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(c.dx, c.dy - 14),
        4,
        Paint()
          ..color = Colors.red.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // Windows
    final windowPaint = Paint()..color = Colors.white;
    final framePaint = Paint()
      ..color = Colors.red.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left window
    final winL = Rect.fromCenter(
        center: Offset(c.dx - 12, c.dy - 2), width: 8, height: 8);
    canvas.drawRect(winL, windowPaint);
    canvas.drawRect(winL, framePaint);

    // Right window
    final winR = Rect.fromCenter(
        center: Offset(c.dx + 12, c.dy - 2), width: 8, height: 8);
    canvas.drawRect(winR, windowPaint);
    canvas.drawRect(winR, framePaint);

    // Center window above door
    final winC =
        Rect.fromCenter(center: Offset(c.dx, c.dy - 2), width: 8, height: 8);
    canvas.drawRect(winC, windowPaint);
    canvas.drawRect(winC, framePaint);

    // Door
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx, c.dy + 8), width: 10, height: 14),
      const Radius.circular(2),
    );
    canvas.drawRRect(doorRect, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(
        Offset(c.dx + 3, c.dy + 8), 1.2, Paint()..color = Colors.amber);

    double textY = c.dy + 30;
    if (node.endpointName != null && node.endpointName!.isNotEmpty) {
      final nameTp = _text(node.endpointName!, 11, const Color(0xFF1A237E),
          fontWeight: FontWeight.bold);
      final rect = Rect.fromCenter(
          center: Offset(c.dx, textY), width: nameTp.width + 16, height: 20);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = Colors.blue.shade50);
      nameTp.paint(canvas, Offset(c.dx - nameTp.width / 2, textY - 10));
      textY += 26;
    }

    if (node.endpointDescription != null &&
        node.endpointDescription!.isNotEmpty) {
      final descTp = _text(node.endpointDescription!, 9, Colors.black87);
      final rect = Rect.fromCenter(
          center: Offset(c.dx, textY), width: descTp.width + 12, height: 18);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = Colors.grey.shade100);
      descTp.paint(canvas, Offset(c.dx - descTp.width / 2, textY - 9));
    }
  }

  // Helper method for text
  TextPainter _text(String text, double size, Color color,
      {FontWeight fontWeight = FontWeight.normal}) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: size,
                color: color,
                fontWeight: fontWeight,
                fontFamily: 'Roboto')),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
