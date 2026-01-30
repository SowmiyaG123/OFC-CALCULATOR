import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/rendering.dart';
// Replace the HTML import at the top with:
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:async' show unawaited;
import 'package:image/image.dart' as img;

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
  Color? flowColor;

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
    this.flowColor, // ADD THIS
  }) : children = children ?? [];

  bool get isLeaf => children.isEmpty;
  bool get isCoupler => deviceType == 'coupler';
  bool get isSplitter => deviceType == 'splitter';
  bool get isHeadend => deviceType == 'headend';
  bool get isCouplerSplitBlock => isCouplerOutput;
}

// 1. ADD THIS: Color management system
class FlowColorManager {
  static final List<Color> _availableColors = [
    Color(0xFF1976D2),
    Color(0xFFE91E63),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFFEB3B),
    Color(0xFF795548),
    Color(0xFFFF5722),
    Color(0xFF009688),
    Color(0xFF3F51B5),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
    Color(0xFF673AB7),
    Color(0xFF00897B),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFFCDDC39),
    Color(0xFFFF6F00),
    Color(0xFF6A1B9A),
    Color(0xFF1565C0),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFFF57C00),
    Color(0xFF5E35B1),
    Color(0xFF0277BD),
    Color(0xFFC2185B),
    Color(0xFF7B1FA2),
    Color(0xFF0288D1),
    Color(0xFFAFB42B),
    Color(0xFFE64A19),
    Color(0xFF00796B),
    Color(0xFF303F9F),
    Color(0xFFFBC02D),
    Color(0xFF512DA8),
    Color(0xFF0097A7),
    Color(0xFF689F38),
    Color(0xFFFF8F00),
    Color(0xFF455A64),
    Color(0xFFD81B60),
    Color(0xFF00ACC1),
    Color(0xFFF4511E),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF1E88E5),
    Color(0xFFAB47BC),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFF5C6BC0),
    Color(0xFF9CCC65),
    Color(0xFFFFCA28),
    Color(0xFF78909C),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFFFF7043),
    Color(0xFF29B6F6),
    Color(0xFFBDBDBD),
    Color(0xFFFFEE58),
    Color(0xFFBA68C8),
    Color(0xFF42A5F5),
    Color(0xFF8D6E63),
  ];

  static int _currentColorIndex = 0;

  static Color getNextColor() {
    final color =
        _availableColors[_currentColorIndex % _availableColors.length];
    _currentColorIndex++;
    return color;
  }

  static void reset() {
    _currentColorIndex = 0;
  }
}

class OccupiedEnvelope {
  final double xStart;
  final double xEnd;
  final double yTop;
  final double yBottom;
  final int nodeId; // Track which node owns this space

  OccupiedEnvelope({
    required this.xStart,
    required this.xEnd,
    required this.yTop,
    required this.yBottom,
    required this.nodeId,
  });

  bool overlapsWith(double x1, double x2, double y1, double y2) {
    final xOverlap = !(x2 < xStart || x1 > xEnd);
    final yOverlap = !(y2 < yTop || y1 > yBottom);
    return xOverlap && yOverlap;
  }
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

String? _projectId;
String? _projectName;

class EnvelopeLayoutManager {
  static const double blockWidth = 140.0;
  static const double blockHeight = 120.0;
  static const double horizontalPadding = 60.0; // Space around blocks
  static const double verticalPadding = 40.0;
  static const double verticalStep = 25.0; // Search step for free Y position
  static const double minHorizontalSpacing =
      200.0; // Min spacing between siblings
  static const double verticalSpacing = 290.0; // Distance between parent-child

  // Global occupancy tracker
  static final List<OccupiedEnvelope> _occupiedZones = [];

  // Clear all occupied zones (call at start of layout)
  static void reset() {
    _occupiedZones.clear();
  }

  // Find a free Y position for a block at given X
  static double findFreeY({
    required double xCenter,
    required double preferredY,
    required int nodeId,
  }) {
    final xStart = xCenter - blockWidth / 2 - horizontalPadding;
    final xEnd = xCenter + blockWidth / 2 + horizontalPadding;
    final height = blockHeight + verticalPadding * 2;

    double testY = preferredY;
    int maxIterations = 200; // Prevent infinite loops
    int iterations = 0;

    while (iterations < maxIterations) {
      bool hasCollision = false;

      for (final zone in _occupiedZones) {
        if (zone.overlapsWith(xStart, xEnd, testY, testY + height)) {
          hasCollision = true;
          break;
        }
      }

      if (!hasCollision) {
        return testY;
      }

      testY += verticalStep;
      iterations++;
    }

    // Fallback: return far below everything
    return preferredY + (iterations * verticalStep);
  }

  // Reserve space for a block
  static void reserveSpace({
    required double xCenter,
    required double yTop,
    required int nodeId,
  }) {
    final envelope = OccupiedEnvelope(
      xStart: xCenter - blockWidth / 2 - horizontalPadding,
      xEnd: xCenter + blockWidth / 2 + horizontalPadding,
      yTop: yTop - verticalPadding,
      yBottom: yTop + blockHeight + verticalPadding,
      nodeId: nodeId,
    );

    _occupiedZones.add(envelope);
  }

  // Calculate initial X positions for siblings (same as before)
  static List<double> calculateInitialPositions({
    required int count,
    required double parentX,
  }) {
    if (count == 1) return [parentX];

    final spacing = minHorizontalSpacing;
    final totalWidth = (count - 1) * spacing;
    final startX = parentX - totalWidth / 2;

    return List.generate(count, (i) => startX + i * spacing);
  }

  // Adjust X positions to avoid horizontal collisions (quick check)
  static List<double> adjustForHorizontalCollisions({
    required List<double> positions,
    required double y,
  }) {
    // Check each position for horizontal conflicts at this Y level
    List<double> adjusted = List.from(positions);
    bool changed = true;
    int maxIterations = 50;
    int iterations = 0;

    while (changed && iterations < maxIterations) {
      changed = false;
      iterations++;

      for (int i = 0; i < adjusted.length - 1; i++) {
        double x1 = adjusted[i];
        double x2 = adjusted[i + 1];
        double gap = x2 - x1;

        if (gap < blockWidth + horizontalPadding * 2) {
          // Too close, push apart
          double pushAmount = (blockWidth + horizontalPadding * 2 - gap) / 2;
          adjusted[i] -= pushAmount;
          adjusted[i + 1] += pushAmount;
          changed = true;
        }
      }
    }

    return adjusted;
  }

  // Check if a position would collide with any existing envelope
  static bool wouldCollide({
    required double xCenter,
    required double yTop,
  }) {
    final xStart = xCenter - blockWidth / 2 - horizontalPadding;
    final xEnd = xCenter + blockWidth / 2 + horizontalPadding;
    final yBottom = yTop + blockHeight + verticalPadding;

    return _occupiedZones
        .any((zone) => zone.overlapsWith(xStart, xEnd, yTop, yBottom));
  }

  // Get all occupied zones (for debugging)
  static List<OccupiedEnvelope> getOccupiedZones() {
    return List.from(_occupiedZones);
  }
}

class _OFCDiagramPageState extends State<OFCDiagramPage> {
  final GlobalKey repaintKey = GlobalKey(); // Fixed: Proper key declaration
  final TextEditingController _headendNameCtrl =
      TextEditingController(text: "EDFA");
  final TextEditingController _headendDbmCtrl =
      TextEditingController(text: defaultHeadendDbm.toString());
  final TextEditingController _wdmLossCtrl = TextEditingController(text: "0.0");
  final TextEditingController _wdmPowerCtrl =
      TextEditingController(text: "0.0");

  bool _isSaving = false; // Add saving state

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DiagramNode> _highlightedNodes = [];
  DiagramNode? root;
  DiagramNode? _highlightedNode;

  // Add these class variables at the top of _OFCDiagramPageState
  final List<Map<String, dynamic>> _historyStack = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

// Add these methods
  void _saveToHistory() {
    // Remove any redo history
    if (_historyIndex < _historyStack.length - 1) {
      _historyStack.removeRange(_historyIndex + 1, _historyStack.length);
    }

    // Add current state
    final state = {
      'headendName': _headendNameCtrl.text,
      'headendPower':
          double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
      'wavelength': _selectedWavelength,
      'useWdm': _useWdm,
      'wdmLoss': _wdmLoss,
      'wdmPower': double.tryParse(_wdmPowerCtrl.text) ?? 0.0,
      'diagramTree': root != null ? _serializeDiagramTree(root!) : null,
      'nodeCounter': _nodeCounter,
    };

    _historyStack.add(state);
    _historyIndex++;

    // Limit history size
    if (_historyStack.length > _maxHistorySize) {
      _historyStack.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _restoreFromHistory(_historyStack[_historyIndex]);
    }
  }

  void _redo() {
    if (_historyIndex < _historyStack.length - 1) {
      _historyIndex++;
      _restoreFromHistory(_historyStack[_historyIndex]);
    }
  }

  void _restoreFromHistory(Map<String, dynamic> state) {
    setState(() {
      _headendNameCtrl.text = state['headendName'];
      _headendDbmCtrl.text = state['headendPower'].toString();
      _selectedWavelength = state['wavelength'];
      _useWdm = state['useWdm'];
      _wdmLoss = state['wdmLoss'];
      _wdmPowerCtrl.text = state['wdmPower'].toString();
      _nodeCounter = state['nodeCounter'];

      if (state['diagramTree'] != null) {
        root = _deserializeDiagramTree(state['diagramTree'], null);
        _recalculateAll(root!);
      }
    });
  }

// Replace the existing _findAllMatchingNodes method with:
  List<DiagramNode> _findAllMatchingNodes(DiagramNode node, String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();
    final matches = <DiagramNode>[];

    void searchRecursive(DiagramNode current) {
      // Check endpoint name
      if (current.endpointName != null &&
          current.endpointName!.toLowerCase().contains(lowerQuery)) {
        matches.add(current);
      }
      // Check node label
      else if (current.label.toLowerCase().contains(lowerQuery)) {
        matches.add(current);
      }
      // Check description
      else if (current.endpointDescription != null &&
          current.endpointDescription!.toLowerCase().contains(lowerQuery)) {
        matches.add(current);
      }

      // Search children
      for (var child in current.children) {
        searchRecursive(child);
      }
    }

    searchRecursive(node);
    return matches;
  }

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

    if (widget.savedData != null) {
      _projectId = widget.savedData!['projectId'];
      _projectName = widget.savedData!['projectName'];
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
    FlowColorManager.reset(); // 🎨 RESET COLORS
    root = DiagramNode(
      id: _nodeCounter++,
      label: _headendNameCtrl.text,
      signal: double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
      distance: 0,
      deviceType: 'headend',
      wavelength: _selectedWavelength,
      useWdm: _useWdm,
      wdmLoss: _wdmLoss,
      flowColor: Color(0xFF1A237E), // 🎨 HEADEND COLOR
    );
  }

  void _loadSavedDiagram(Map data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ✅ CRITICAL: Load WDM power FIRST before setState
      double loadedWdmPower = 0.0;
      if (data['wdmPower'] != null) {
        loadedWdmPower = (data['wdmPower'] as num).toDouble();
      }

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

        // ✅ CRITICAL FIX: Set WDM power in controller BEFORE deserializing tree
        _wdmPowerCtrl.text = loadedWdmPower.toString();
        print('✅ WDM power set to controller: ${_wdmPowerCtrl.text}');

        if (data['diagramTree'] != null) {
          try {
            root = _deserializeDiagramTree(data['diagramTree'], null);

            // ✅ Propagate WDM to tree after loading
            if (_useWdm && loadedWdmPower > 0) {
              _propagateWdmToTree(root!, loadedWdmPower);
            }

            _recalculateAll(root!);
          } catch (e) {
            print('Error deserializing diagram: $e');
            _initRoot();
          }
        } else {
          _updateHeadend();
        }
      });

      // ✅ Force UI rebuild after 100ms to ensure WDM input shows value
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            // Trigger rebuild with loaded value
            print('✅ UI rebuild - WDM value: ${_wdmPowerCtrl.text}');
          });
        }
      });
    });
  }

  // Add this method after _loadSavedDiagram
  void _restoreFromSavedData(Map data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final loadedWdmPower = (data['wdmPower'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        // Restore headend settings
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

        // ✅ Set WDM power
        _wdmPowerCtrl.text = loadedWdmPower.toString();

        // Restore diagram tree
        if (data['diagramTree'] != null) {
          try {
            root = _deserializeDiagramTree(data['diagramTree'], null);

            if (_useWdm && loadedWdmPower > 0) {
              _propagateWdmToTree(root!, loadedWdmPower);
            }

            _recalculateAll(root!);
          } catch (e) {
            print('❌ Error restoring diagram: $e');
            _initRoot();
          }
        } else {
          _updateHeadend();
        }
      });

      debugPrint(
          '🔁 Diagram restored with WDM: $_useWdm, Power: $loadedWdmPower');
    });
  }

// Add this helper method to propagate WDM power to all nodes
  void _propagateWdmToTree(DiagramNode node, double wdmPower) {
    if (node.useWdm) {
      // For coupler outputs
      if (node.isCouplerOutput) {
        final parent = _findNode(root, node.parentId!);
        if (parent != null) {
          final ratio = node.couplerRatio ?? 50;
          final wdmLosses =
              _calculateCouplerLosses(ratio, wdmPower, '1310', isWdm: true);
          final index = parent.children.indexOf(node);
          if (index == 0) {
            node.wdmOutputPower = wdmLosses[0] - node.fiberLoss;
          } else if (index == 1) {
            node.wdmOutputPower = wdmLosses[1] - node.fiberLoss;
          }
        }
      }
      // For splitter outputs
      else if (node.isSplitterOutput && node.deviceConfig != null) {
        final parts = node.deviceConfig!.split('::');
        if (parts.length >= 2) {
          final split = int.tryParse(parts[0]) ?? 2;
          final splitterVal = double.tryParse(parts[1]) ?? 1.0;
          final calc = SplitterCalculator(splitterVal);
          final all = calc.calculateLoss();
          final section = 'LOSS-13 10';
          final sec = all[section]!;
          final entry = sec.firstWhere(
            (e) => e['split'] == split,
            orElse: () => sec.first,
          );
          final splitterLossValue = (entry['value'] as num).toDouble();
          final splitterLossDisplay = splitterLossValue.abs();
          node.wdmOutputPower = wdmPower - splitterLossDisplay - node.fiberLoss;
        }
      }
    }

    // Recursively process children
    for (var child in node.children) {
      _propagateWdmToTree(child, wdmPower);
    }
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
    // ✅ CRITICAL: Get WDM input value BEFORE setState
    final currentWdmValue = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;

    setState(() {
      root!.label =
          _headendNameCtrl.text.isEmpty ? 'EDFA' : _headendNameCtrl.text;
      root!.signal = double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm;
      root!.wavelength = _selectedWavelength;
      root!.useWdm = _useWdm;
      root!.wdmLoss = _wdmLoss;

      _highlightedNode = null;
      _searchController.clear();

      _propagateSettings(root!);

      // ✅ CRITICAL: Propagate WDM with current value
      if (_useWdm && currentWdmValue > 0) {
        _propagateWdmToTree(root!, currentWdmValue);
      }

      _recalculateAll(root!);
      _saveToHistory(); // ADD THIS
    });
  }

  void _propagateSettings(DiagramNode node) {
    for (var child in node.children) {
      child.wavelength = node.wavelength;
      child.useWdm = node.useWdm;
      child.wdmLoss = node.wdmLoss;

      // ✅ Propagate WDM power changes for BOTH couplers AND splitters
      if (node.useWdm) {
        if (child.isCouplerOutput) {
          // Recalculate WDM for coupler outputs
          final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
          final ratio = child.couplerRatio ?? 50;
          final wdmLosses =
              _calculateCouplerLosses(ratio, wdmInput, '1310', isWdm: true);

          if (child.parentId != null) {
            final parent = _findNode(root, child.parentId!);
            if (parent != null) {
              final index = parent.children.indexOf(child);
              if (index == 0) {
                child.wdmOutputPower = wdmLosses[0] - child.fiberLoss;
              } else if (index == 1) {
                child.wdmOutputPower = wdmLosses[1] - child.fiberLoss;
              }
            }
          }
        } else if (child.isSplitterOutput && child.deviceConfig != null) {
          // ✅ Calculate WDM for splitter outputs
          final parts = child.deviceConfig!.split('::');
          if (parts.length >= 2) {
            final split = int.tryParse(parts[0]) ?? 2;
            final splitterVal = double.tryParse(parts[1]) ?? 1.0;

            final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
            final calc = SplitterCalculator(splitterVal);
            final all = calc.calculateLoss();
            final section = '1310' == '1310' ? 'LOSS-13 10' : 'LOSS-15 50';
            final sec = all[section]!;
            final entry = sec.firstWhere(
              (e) => e['split'] == split,
              orElse: () => sec.first,
            );

            final splitterLossValue = (entry['value'] as num).toDouble();
            final splitterLossDisplay = splitterLossValue.abs();

            child.wdmOutputPower =
                wdmInput - splitterLossDisplay - child.fiberLoss;
          }
        }
      }

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
                    flowColor: parent.flowColor,
                  );

                  parent.children.add(child);

                  _saveToHistory(); // ADD THIS
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
                        final couplerFlowColor =
                            FlowColorManager.getNextColor();
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
                          flowColor: couplerFlowColor, // 🎨 ASSIGN COLOR
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
                          flowColor: couplerFlowColor, // 🎨 ASSIGN COLO
                        );

                        parent.children.add(output1);
                        parent.children.add(output2);

                        _saveToHistory(); // ADD THIS
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

                  final splitterLossValue = (entry['value'] as num).toDouble();
                  final splitterLossDisplay = splitterLossValue.abs();
                  final finalDeviceLoss = splitterLossDisplay - fiberLoss;
                  final outputSignal =
                      parent.signal - splitterLossDisplay - fiberLoss;

                  // ✅ Calculate WDM output power for splitter
                  double wdmOutputPower = 0.0;
                  if (parent.useWdm) {
                    final wdmInput = double.tryParse(_wdmPowerCtrl.text) ?? 0.0;
                    wdmOutputPower = wdmInput - splitterLossDisplay - fiberLoss;
                  }

                  final baseLabel =
                      labelCtrl.text.isEmpty ? 'Splitter' : labelCtrl.text;
                  final splitterFlowColor = FlowColorManager.getNextColor();
                  for (int i = 0; i < split; i++) {
                    final outputNode = DiagramNode(
                      id: _nodeCounter++,
                      label: baseLabel,
                      signal: outputSignal,
                      distance: distance,
                      parentId: parent.id,
                      deviceType: 'splitter',
                      deviceConfig: '$split::$splitterVal',
                      wavelength: parent.wavelength,
                      useWdm: parent.useWdm,
                      wdmLoss: parent.wdmLoss,
                      isSplitterOutput: true,
                      deviceLoss: finalDeviceLoss,
                      fiberLoss: fiberLoss,
                      wdmOutputPower: wdmOutputPower, // ✅ ADD THIS
                      flowColor: splitterFlowColor, // 🎨 ASSIGN COLOR
                    );
                    parent.children.add(outputNode);
                  }
                  _saveToHistory(); // ADD THIS
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
                            _saveToHistory(); // ADD THIS
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
                    _saveToHistory(); // ADD THIS
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

// In _DiagramPainter class, add this method:
  DiagramNode? _findNode(DiagramNode? n, int id) {
    if (n == null) return null;
    if (n.id == id) return n;
    for (final c in n.children) {
      final f = _findNode(c, id);
      if (f != null) return f;
    }
    return null;
  }

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
      'wdmOutputPower': node.wdmOutputPower, // ✅ ADD THIS
      'endpointName': node.endpointName,
      'endpointDescription': node.endpointDescription,
      'children':
          node.children.map((child) => _serializeDiagramTree(child)).toList(),
      'flowColor': node.flowColor?.value, // 🎨 SAVE COLOR
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
      wdmOutputPower: data['wdmOutputPower'] ?? 0.0, // ✅ ADD THIS
      endpointName: data['endpointName'],
      endpointDescription: data['endpointDescription'],
      parentId: parentId,
      flowColor: data['flowColor'] != null
          ? Color(data['flowColor'])
          : null, // 🎨 RESTORE COLOR
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
    if (root == null) return;

    // ENHANCED PROGRESS DIALOG with steps
    bool isDialogShowing = true;
    String currentStep = 'Initializing...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated progress indicator
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                        ),
                        Icon(Icons.image, size: 32, color: Color(0xFF4CAF50)),
                      ],
                    ),
                  ),
                  SizedBox(height: 28),
                  Text(
                    'Generating Diagram',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    currentStep,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⚡ Please wait...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF9800),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => isDialogShowing = false);

    try {
      // TURBO OPTIMIZATION 1: Ultra-lightweight position scan
      final positions = <Offset>[];

      void ultraFastScan(DiagramNode node, double x, double y,
          {int level = 0}) {
        if (level == 0) EnvelopeLayoutManager.reset();

        positions.add(Offset(x - 70, y - 60));
        positions.add(Offset(x + 70, y + 60));
        if (node.isLeaf && !node.isHeadend) positions.add(Offset(x, y + 150));

        if (node.children.isNotEmpty) {
          final count = node.children.length;
          final xPos = EnvelopeLayoutManager.calculateInitialPositions(
              count: count, parentX: x);
          final childY = y + 290;
          final adjusted = EnvelopeLayoutManager.adjustForHorizontalCollisions(
              positions: xPos, y: childY);

          for (int i = 0; i < count; i++) {
            final child = node.children[i];
            final cX = adjusted[i];
            final cY = EnvelopeLayoutManager.findFreeY(
                xCenter: cX, preferredY: childY, nodeId: child.id);
            EnvelopeLayoutManager.reserveSpace(
                xCenter: cX, yTop: cY, nodeId: child.id);
            ultraFastScan(child, cX, cY, level: level + 1);
          }
        }
        EnvelopeLayoutManager.reserveSpace(
            xCenter: x, yTop: y - 60, nodeId: node.id);
      }

      EnvelopeLayoutManager.reset();
      ultraFastScan(root!, 1000, 100);

      // TURBO OPTIMIZATION 2: Lightning-fast bounds
      double minX = positions[0].dx, maxX = positions[0].dx;
      double minY = positions[0].dy, maxY = positions[0].dy;

      for (final pos in positions) {
        if (pos.dx < minX) minX = pos.dx;
        if (pos.dx > maxX) maxX = pos.dx;
        if (pos.dy < minY) minY = pos.dy;
        if (pos.dy > maxY) maxY = pos.dy;
      }

      final padding = 250.0;
      double width = maxX - minX + padding * 2;
      double height = maxY - minY + padding * 2;

      // TURBO OPTIMIZATION 3: Aggressive scaling for speed
      double scale = 1.0;
      if (width > 12000 || height > 8000) {
        scale = 0.5; // 50% reduction - massive speed boost
      } else if (width > 8000 || height > 5000) {
        scale = 0.65;
      } else if (width > 5000 || height > 3000) {
        scale = 0.8;
      }

      width = (width * scale).clamp(1200.0, 15000.0);
      height = (height * scale).clamp(900.0, 12000.0);

      final offsetX = (padding - minX) * scale;
      final offsetY = (padding - minY) * scale;

      // TURBO OPTIMIZATION 4: Direct rendering (zero overhead)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);
      canvas.scale(scale);
      canvas.translate(offsetX / scale, offsetY / scale);

      EnvelopeLayoutManager.reset();
      _renderFullDiagram(canvas, root!, 1000, 100);

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // TURBO OPTIMIZATION 5: Skip thumbnail for speed
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ofc_diagram_$timestamp.png';
      String? fullImagePath;

      if (kIsWeb) {
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory dir;
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          dir = await downloadsDir.exists()
              ? downloadsDir
              : await getApplicationDocumentsDirectory();
        } catch (e) {
          dir = await getApplicationDocumentsDirectory();
        }

        final fullFile = File('${dir.path}/$fileName');
        await fullFile.writeAsBytes(pngBytes);
        fullImagePath = fullFile.path;
      }

      // TURBO OPTIMIZATION 6: Ultra-fast Hive save (no blocking)
      unawaited(Future.microtask(() async {
        try {
          final box = await Hive.openBox('diagram_downloads');
          await box.add({
            'name': _projectName ??
                'OFC Diagram ${DateTime.now().toString().split('.').first}',
            'fileName': fileName,
            'date': DateTime.now().toIso8601String(),
            'type': 'png',
            'path': fullImagePath,
            'imageBytes': pngBytes.length < 8000000 ? pngBytes : null,
            'thumbnailBytes': null, // Skip for speed
            'headendName': _headendNameCtrl.text,
            'headendPower':
                double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
            'wavelength': _selectedWavelength,
            'useWdm': _useWdm,
            'wdmLoss': _wdmLoss,
            'wdmPower': double.tryParse(_wdmPowerCtrl.text) ?? 0.0,
            'diagramTree': _serializeDiagramTree(root!),
          });
        } catch (e) {
          print('⚠️ Background save: $e');
        }
      }));

      // Close dialog
      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }

      // Success with confetti effect
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✅ Diagram Ready!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        kIsWeb
                            ? 'Downloaded successfully'
                            : 'Saved to Downloads',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e, stack) {
      print('❌ Error: $e\n$stack');

      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Generation failed: ${e.toString().substring(0, 40)}...'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Size _calculateFullDiagramSize(DiagramNode root) {
    final positions = <Offset>[];

    void collectPositions(DiagramNode node, double x, double y,
        {int level = 0}) {
      if (level == 0) {
        EnvelopeLayoutManager.reset();
      }

      // Record this node's position
      positions.add(Offset(x, y));

      // If leaf, add house icon position (extends below)
      if (node.isLeaf && !node.isHeadend) {
        positions.add(Offset(x, y + 150)); // House + text area
      }

      // Process children with EXACT layout logic
      if (node.children.isNotEmpty) {
        final count = node.children.length;
        final xPositions = EnvelopeLayoutManager.calculateInitialPositions(
          count: count,
          parentX: x,
        );

        final childBaseY = y + EnvelopeLayoutManager.verticalSpacing;
        final adjustedPositions =
            EnvelopeLayoutManager.adjustForHorizontalCollisions(
          positions: xPositions,
          y: childBaseY,
        );

        for (int i = 0; i < count; i++) {
          final child = node.children[i];
          final childX = adjustedPositions[i];
          final childY = EnvelopeLayoutManager.findFreeY(
            xCenter: childX,
            preferredY: childBaseY,
            nodeId: child.id,
          );

          EnvelopeLayoutManager.reserveSpace(
            xCenter: childX,
            yTop: childY,
            nodeId: child.id,
          );

          collectPositions(child, childX, childY, level: level + 1);
        }
      }

      EnvelopeLayoutManager.reserveSpace(
        xCenter: x,
        yTop: y - EnvelopeLayoutManager.blockHeight / 2,
        nodeId: node.id,
      );
    }

    // Collect all positions starting from same position as rendering
    EnvelopeLayoutManager.reset();
    collectPositions(root, 1000, 100);

    if (positions.isEmpty) {
      return Size(2000, 1000);
    }

    // Find actual bounds from collected positions
    double minX = positions.first.dx;
    double maxX = positions.first.dx;
    double minY = positions.first.dy;
    double maxY = positions.first.dy;

    for (final pos in positions) {
      minX = math.min(minX, pos.dx);
      maxX = math.max(maxX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxY = math.max(maxY, pos.dy);
    }

    // Add padding for blocks (blocks extend 70px left/right, 60px top/bottom)
    final blockPadding = 300.0; // Generous padding
    final width = (maxX - minX + blockPadding * 2).clamp(1000.0, 25000.0);
    final height = (maxY - minY + blockPadding * 2).clamp(800.0, 20000.0);

    print('📏 Bounds: X[$minX → $maxX] Y[$minY → $maxY]');
    print('📏 Canvas: ${width}x$height');

    return Size(width, height);
  }
  // Replace the _captureUsingHtmlCanvas method:

  Future<Uint8List> _captureUsingHtmlCanvas() async {
    final size = _calculateDiagramSize(root!);
    final width = size.width.toInt();
    final height = size.height.toInt();

    print('📐 Capturing FULL diagram: ${width}x$height');

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // ✅ CRITICAL: Reset layout manager before rendering
    EnvelopeLayoutManager.reset();

    // Render the diagram starting from the CALCULATED center position
    final startX = size.width / 2; // Center horizontally
    final startY = 100.0; // Top margin

    _renderFullDiagram(canvas, root!, startX, startY);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final bytes = byteData!.buffer.asUint8List();
    print('✅ Generated FULL image: ${bytes.length} bytes');

    return bytes;
  }

  void _renderFullDiagram(Canvas canvas, DiagramNode node, double x, double y,
      {int level = 0}) {
    if (node.isHeadend && level == 0) {
      EnvelopeLayoutManager.reset();
    }

    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final xPositions = EnvelopeLayoutManager.calculateInitialPositions(
        count: count,
        parentX: x,
      );

      final childBaseY = y + EnvelopeLayoutManager.verticalSpacing;
      final adjustedPositions =
          EnvelopeLayoutManager.adjustForHorizontalCollisions(
        positions: xPositions,
        y: childBaseY,
      );

      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = adjustedPositions[i];
        final childY = EnvelopeLayoutManager.findFreeY(
          xCenter: childX,
          preferredY: childBaseY,
          nodeId: child.id,
        );

        EnvelopeLayoutManager.reserveSpace(
          xCenter: childX,
          yTop: childY,
          nodeId: child.id,
        );

        _drawConnectionForCapture(canvas, x, y, childX, childY, child);
        _renderFullDiagram(canvas, child, childX, childY, level: level + 1);
      }
    }

    _drawNodeForCapture(canvas, x, y, node);

    EnvelopeLayoutManager.reserveSpace(
      xCenter: x,
      yTop: y - EnvelopeLayoutManager.blockHeight / 2,
      nodeId: node.id,
    );

    if (node.isLeaf && !node.isHeadend) {
      _drawHouseForCapture(canvas, Offset(x, y + 100), node);
    }
  }

// Add helper methods for drawing:
  void _drawConnectionForCapture(Canvas canvas, double parentX, double parentY,
      double childX, double childY, DiagramNode child) {
    final paintLine = Paint()
      ..color = Color(0xFF757575)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final trunkY = parentY + 60;
    final blockTop = childY - 70;

    // Simple connection without collision detection for speed
    canvas.drawLine(
        Offset(parentX, trunkY), Offset(parentX, trunkY + 60), paintLine);
    canvas.drawLine(
        Offset(parentX, trunkY + 60), Offset(childX, trunkY + 60), paintLine);
    canvas.drawLine(
        Offset(childX, trunkY + 60), Offset(childX, blockTop), paintLine);

    // Arrow
    final arrowPath = Path()
      ..moveTo(childX, blockTop)
      ..lineTo(childX - 6, blockTop - 10)
      ..lineTo(childX + 6, blockTop - 10)
      ..close();
    canvas.drawPath(
        arrowPath,
        Paint()
          ..color = Color(0xFF757575)
          ..style = PaintingStyle.fill);
  }

  void _drawNodeForCapture(
      Canvas canvas, double x, double y, DiagramNode node) {
    // Use the existing painter's draw methods
    final painter = _DiagramPainter(root: root!, highlightedNodes: []);

    if (node.isHeadend) {
      painter._drawHeadendBlock(canvas, x, y, node);
    } else if (node.isCouplerOutput) {
      painter._drawCouplerBlock(canvas, x, y, node);
    } else if (node.isSplitterOutput) {
      painter._drawSplitterBlock(canvas, x, y, node);
    } else {
      painter._drawStandardBlock(canvas, x, y, node);
    }
  }

  void _drawHouseForCapture(Canvas canvas, Offset center, DiagramNode node) {
    final painter = _DiagramPainter(root: root!, highlightedNodes: []);
    painter._drawHouseIcon(canvas, center, node);
  }
// Also update _captureUsingCustomPainter with the same approach:

  Future<Uint8List> _captureUsingCustomPainter() async {
    final size = _calculateDiagramSize(root!);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // ✅ Reset and render full diagram
    EnvelopeLayoutManager.reset();
    final startX = size.width / 2;
    final startY = 100.0;
    _renderFullDiagram(canvas, root!, startX, startY);

    // Convert to image
    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  // In _OFCDiagramPageState class, replace _calculateDiagramSize:

  Size _calculateDiagramSize(DiagramNode root) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    void traverse(DiagramNode node, double x, double y) {
      // Track all positions
      minX = math.min(minX, x - 300);
      maxX = math.max(maxX, x + 300);
      minY = math.min(minY, y - 200);
      maxY = math.max(maxY, y + 350);

      if (node.children.isNotEmpty) {
        final count = node.children.length;
        final xPositions = EnvelopeLayoutManager.calculateInitialPositions(
          count: count,
          parentX: x,
        );

        final childBaseY = y + EnvelopeLayoutManager.verticalSpacing;
        final adjustedPositions =
            EnvelopeLayoutManager.adjustForHorizontalCollisions(
          positions: xPositions,
          y: childBaseY,
        );

        for (int i = 0; i < count; i++) {
          final child = node.children[i];
          final childX = adjustedPositions[i];
          final childY = EnvelopeLayoutManager.findFreeY(
            xCenter: childX,
            preferredY: childBaseY,
            nodeId: child.id,
          );
          traverse(child, childX, childY);
        }
      }
    }

    EnvelopeLayoutManager.reset();
    traverse(root, 3000, 100);

    // Add generous padding
    final width = (maxX - minX + 600).clamp(1500.0, 25000.0);
    final height = (maxY - minY + 600).clamp(1000.0, 20000.0);

    print('📏 Full diagram size: ${width}x$height');
    return Size(width, height);
  }

  Future<void> _verifyImageFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final img.Image? decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          print(
              '✅ File verified: ${decodedImage.width}x${decodedImage.height}, ${bytes.length} bytes');
        } else {
          print('❌ File exists but cannot be decoded as image');
        }
      } else {
        print('❌ File does not exist at: $path');
      }
    } catch (e) {
      print('❌ Error verifying file: $e');
    }
  }

  @override
  void dispose() {
    if (_projectId != null) {
      _saveProjectData();
    }
    super.dispose();
  }

  Future<void> _saveProjectData() async {
    if (_projectId == null) return;

    final projectsBox = await Hive.openBox('network_projects');
    final existingData = projectsBox.get(_projectId);

    if (existingData != null) {
      final updated = {
        ...Map<String, dynamic>.from(existingData),
        'updatedAt': DateTime.now().toIso8601String(),
        'headendName': _headendNameCtrl.text,
        'headendPower':
            double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
        'wavelength': _selectedWavelength,
        'useWdm': _useWdm,
        'wdmLoss': _wdmLoss,
        'wdmPower': double.tryParse(_wdmPowerCtrl.text) ?? 0.0, // ✅ ADD THIS
        'diagramTree': root != null ? _serializeDiagramTree(root!) : null,
      };
      await projectsBox.put(_projectId, updated);

      print('✅ Project saved with WDM power: ${_wdmPowerCtrl.text}'); // Debug
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

  // Add this method to _OFCDiagramPageState class
  Future<void> _zoomOutAndSave() async {
    // First show a message about zooming out
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-zooming out to capture entire diagram...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Wait a bit for the message to be seen
    await Future.delayed(const Duration(milliseconds: 500));

    // Now save the diagram
    await _saveDiagram();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _projectName ?? 'OFC Diagram Generator',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Undo button
          IconButton(
            onPressed: _historyIndex > 0 ? _undo : null,
            icon: Icon(
              Icons.undo,
              color: _historyIndex > 0 ? Colors.white70 : Colors.white24,
            ),
            tooltip: 'Undo',
          ),
          // Redo button
          IconButton(
            onPressed: _historyIndex < _historyStack.length - 1 ? _redo : null,
            icon: Icon(
              Icons.redo,
              color: _historyIndex < _historyStack.length - 1
                  ? Colors.white70
                  : Colors.white24,
            ),
            tooltip: 'Redo',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _nodeCounter = 0;
                _initRoot();
                _searchController.clear();
                _searchQuery = '';
                _historyStack.clear();
                _historyIndex = -1;
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _headendNameCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Headend Name',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Power (dBm)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon:
                              const Icon(Icons.flash_on, color: Colors.white70),
                        ),
                        onChanged: _onHeadendPowerChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Wavelength section
                    Expanded(
                      flex: 3,
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
                            const Text(
                              'Wavelength',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                            Row(
                              children: [
                                _buildWavelengthOption('1550', '1550nm'),
                                const SizedBox(width: 8),
                                _buildWavelengthOption('1310', '1310nm'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // WDM section - COMPACT
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _useWdm
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _useWdm
                                ? Colors.amber
                                : Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _useWdm,
                                    onChanged: (value) {
                                      if (value == true &&
                                          _selectedWavelength == '1310') {
                                        _showWdmWarningDialog();
                                        return;
                                      }
                                      setState(() {
                                        _useWdm = value ?? false;
                                        root!.useWdm = _useWdm;
                                        if (!_useWdm) {
                                          _wdmPowerCtrl.text = "0.0";
                                          _resetWdmInTree(root!);
                                        }
                                        _recalculateAll(root!);
                                      });
                                    },
                                    checkColor: Colors.white,
                                    fillColor: MaterialStateProperty
                                        .resolveWith<Color>((states) {
                                      if (states
                                          .contains(MaterialState.selected))
                                        return Colors.amber;
                                      return Colors.transparent;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'WDM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (_useWdm) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _wdmPowerCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (value) {
                                    setState(() {
                                      _recalculateAll(root!);
                                    });
                                  },
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Power',
                                    hintStyle: const TextStyle(
                                        color: Colors.white60, fontSize: 11),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: Colors.amber),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: Colors.amber),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Colors.amber, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    suffixText: 'dBm',
                                    suffixStyle: const TextStyle(
                                        color: Colors.white70, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Update button
                    ElevatedButton.icon(
                      onPressed: _updateHeadend,
                      icon: const Icon(Icons.update, size: 18),
                      label: const Text('Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),

                // Search bar moved here - BELOW configuration
                const SizedBox(height: 12),
                if (root != null)
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search endpoint by name...',
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_highlightedNodes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_highlightedNodes.length} found',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white70),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _highlightedNodes = [];
                                    });
                                  },
                                ),
                              ],
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        if (value.isNotEmpty && root != null) {
                          _highlightedNodes =
                              _findAllMatchingNodes(root!, value);
                        } else {
                          _highlightedNodes = [];
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          // In the build method, update the Diagram Canvas section:
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
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.05, // ✅ Allow more zoom out
                  maxScale: 8.0,
                  constrained: false,
                  child: RepaintBoundary(
                    key: repaintKey,
                    child: SizedBox(
                      width: 20000, // ✅ Increased width
                      height: 12000, // ✅ Increased height
                      child: root != null
                          ? DiagramWidget(
                              root: root!,
                              onTapNode: _showNodeOptions,
                              highlightedNodes: _highlightedNodes,
                            )
                          : const Center(child: Text('No diagram')),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Replace the existing download button section with:
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDiagram,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSaving ? Colors.grey : const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.download_for_offline),
                label: Text(
                  _isSaving ? 'Saving...' : 'Download Diagram',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
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
// ============================================================
// REPLACE the DiagramWidget class with this fixed version:
// ============================================================

class DiagramWidget extends StatelessWidget {
  final DiagramNode root;
  final void Function(DiagramNode) onTapNode;
  final List<DiagramNode> highlightedNodes; // CHANGED to list

  DiagramWidget({
    super.key,
    required this.root,
    required this.onTapNode,
    required this.highlightedNodes, // CHANGED
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiagramPainter(
        root: root,
        highlightedNodes: highlightedNodes, // CHANGED
      ),
      child: Stack(children: _overlay(root, 3000, 100)),
    );
  }

  List<Widget> _overlay(DiagramNode node, double x, double y, {int level = 0}) {
    final widgets = <Widget>[];

    // CRITICAL FIX: Reset envelope manager at root level to sync with painter
    if (node.isHeadend && level == 0) {
      EnvelopeLayoutManager.reset();
    }

    // Clickable area for node block itself
    widgets.add(Positioned(
      left: x - 70, // Increased from 100 to make it easier to click
      top: y - 60, // Increased area
      width: 140, // Wider clickable area
      height: 120, // Taller clickable area
      child: GestureDetector(
        onTap: () => onTapNode(node),
        behavior: HitTestBehavior.translucent,
        child: Container(
            // Uncomment for debugging - shows clickable areas
            // decoration: BoxDecoration(
            //   border: Border.all(color: Colors.red.withOpacity(0.3)),
            // ),
            ),
      ),
    ));

    // Add clickable area for leaf nodes (house icon)
    if (node.isLeaf && !node.isHeadend) {
      widgets.add(Positioned(
        left: x - 30, // Wider area around house
        top: y + 60, // Positioned at house location
        width: 60,
        height: 80, // Cover house and text
        child: GestureDetector(
          onTap: () => onTapNode(node),
          behavior: HitTestBehavior.translucent,
          child: Container(
              // Uncomment for debugging
              // decoration: BoxDecoration(
              //   border: Border.all(color: Colors.green.withOpacity(0.3)),
              // ),
              ),
        ),
      ));
    }

    // Process children with SAME logic as painter
    if (node.children.isNotEmpty) {
      final count = node.children.length;

      // Get initial X positions using the same method as painter
      List<double> xPositions = EnvelopeLayoutManager.calculateInitialPositions(
        count: count,
        parentX: x,
      );

      final childBaseY = y + EnvelopeLayoutManager.verticalSpacing;

      // Adjust for horizontal collisions (same as painter)
      xPositions = EnvelopeLayoutManager.adjustForHorizontalCollisions(
        positions: xPositions,
        y: childBaseY,
      );

      // CRITICAL: Process children in SAME ORDER as painter
      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = xPositions[i];

        // Find free Y position using SAME logic as painter
        final childY = EnvelopeLayoutManager.findFreeY(
          xCenter: childX,
          preferredY: childBaseY,
          nodeId: child.id,
        );

        // CRITICAL: Reserve space in SAME ORDER as painter
        EnvelopeLayoutManager.reserveSpace(
          xCenter: childX,
          yTop: childY,
          nodeId: child.id,
        );

        // Recursively add overlay widgets for child
        widgets.addAll(_overlay(child, childX, childY, level: level + 1));
      }
    }

    // CRITICAL: Reserve space for current node (same as painter)
    EnvelopeLayoutManager.reserveSpace(
      xCenter: x,
      yTop: y - EnvelopeLayoutManager.blockHeight / 2,
      nodeId: node.id,
    );

    return widgets;
  }
}

class _DiagramPainter extends CustomPainter {
  final DiagramNode root;
  final List<DiagramNode> highlightedNodes; // CHANGED to list

  _DiagramPainter({
    required this.root,
    required this.highlightedNodes, // CHANGED
  });

  bool _isPathClear(
    double startX,
    double endX,
    double y,
    List<OccupiedEnvelope> zones,
  ) {
    final minX = startX < endX ? startX : endX;
    final maxX = startX > endX ? startX : endX;

    for (final zone in zones) {
      // Check if line intersects with any block
      final lineIntersectsX = !(maxX < zone.xStart || minX > zone.xEnd);
      final lineIntersectsY = y >= zone.yTop && y <= zone.yBottom;

      if (lineIntersectsX && lineIntersectsY) {
        return false;
      }
    }
    return true;
  }

  void _drawRoutedPath(
    Canvas canvas,
    Paint paint,
    double startX,
    double startY,
    double endX,
    double endY,
    List<OccupiedEnvelope> zones,
    int childId,
  ) {
    // Find safe routing levels
    double routeAboveY = startY - 60;
    double routeBelowY = startY + 60;

    bool canRouteAbove =
        _isHorizontalPathClear(startX, endX, routeAboveY, zones, childId);
    bool canRouteBelow =
        _isHorizontalPathClear(startX, endX, routeBelowY, zones, childId);

    if (canRouteAbove) {
      // Route above obstacles
      canvas.drawLine(
          Offset(startX, startY), Offset(startX, routeAboveY), paint);
      canvas.drawLine(
          Offset(startX, routeAboveY), Offset(endX, routeAboveY), paint);
      canvas.drawLine(Offset(endX, routeAboveY), Offset(endX, endY), paint);
    } else if (canRouteBelow) {
      // Route below obstacles
      canvas.drawLine(
          Offset(startX, startY), Offset(startX, routeBelowY), paint);
      canvas.drawLine(
          Offset(startX, routeBelowY), Offset(endX, routeBelowY), paint);
      canvas.drawLine(Offset(endX, routeBelowY), Offset(endX, endY), paint);
    } else {
      // Complex routing - find gaps
      _drawComplexRoute(
          canvas, paint, startX, startY, endX, endY, zones, childId);
    }
  }

// Add this helper method:

  bool _isHorizontalPathClear(
    double x1,
    double x2,
    double y,
    List<OccupiedEnvelope> zones,
    int childId,
  ) {
    final minX = math.min(x1, x2);
    final maxX = math.max(x1, x2);

    for (final zone in zones) {
      if (zone.nodeId == childId) continue;

      final xOverlap = !(maxX < zone.xStart || minX > zone.xEnd);
      final yOverlap = y >= zone.yTop - 10 && y <= zone.yBottom + 10;

      if (xOverlap && yOverlap) {
        return false;
      }
    }
    return true;
  }

// Add this for complex multi-segment routing:

  void _drawComplexRoute(
    Canvas canvas,
    Paint paint,
    double startX,
    double startY,
    double endX,
    double endY,
    List<OccupiedEnvelope> zones,
    int childId,
  ) {
    // Staircase routing - go around obstacles in steps
    List<Offset> waypoints = [Offset(startX, startY)];

    double currentX = startX;
    double currentY = startY;
    final targetX = endX;
    final targetY = endY;

    // Move in steps: vertical -> horizontal -> vertical
    final stepCount = 5;
    final xStep = (targetX - currentX) / stepCount;
    final yStep = 40.0;

    for (int i = 0; i < stepCount; i++) {
      // Try moving down first
      double nextY = currentY + yStep;

      // Check if this Y level is clear for horizontal movement
      double nextX = currentX + xStep;

      if (_isHorizontalPathClear(currentX, nextX, nextY, zones, childId)) {
        waypoints.add(Offset(currentX, nextY));
        waypoints.add(Offset(nextX, nextY));
        currentX = nextX;
        currentY = nextY;
      } else {
        // Try going up instead
        nextY = currentY - yStep;
        if (_isHorizontalPathClear(currentX, nextX, nextY, zones, childId)) {
          waypoints.add(Offset(currentX, nextY));
          waypoints.add(Offset(nextX, nextY));
          currentX = nextX;
          currentY = nextY;
        }
      }
    }

    // Final segment to target
    waypoints.add(Offset(targetX, currentY));
    waypoints.add(Offset(targetX, targetY));

    // Draw all segments
    for (int i = 0; i < waypoints.length - 1; i++) {
      canvas.drawLine(waypoints[i], waypoints[i + 1], paint);
    }
  }

  void _drawRoutedConnection(
    Canvas canvas,
    Paint paint,
    double startX,
    double startY,
    double endX,
    double endY,
    List<OccupiedEnvelope> zones,
  ) {
    // Find routing points that avoid obstacles
    final midY = (startY + endY) / 2;
    final routeAbove = startY - 40; // Route above obstacles
    final routeBelow = endY + 40; // Route below obstacles

    // Try routing above first
    if (_isPathClear(startX, endX, routeAbove, zones)) {
      // Route above obstacles
      canvas.drawLine(
          Offset(startX, startY), Offset(startX, routeAbove), paint);
      canvas.drawLine(
          Offset(startX, routeAbove), Offset(endX, routeAbove), paint);
      canvas.drawLine(Offset(endX, routeAbove), Offset(endX, endY), paint);
    } else if (_isPathClear(startX, endX, routeBelow, zones)) {
      // Route below obstacles
      canvas.drawLine(
          Offset(startX, startY), Offset(startX, routeBelow), paint);
      canvas.drawLine(
          Offset(startX, routeBelow), Offset(endX, routeBelow), paint);
      canvas.drawLine(Offset(endX, routeBelow), Offset(endX, endY), paint);
    } else {
      // Multi-segment routing (zigzag around obstacles)
      _drawZigzagRoute(canvas, paint, startX, startY, endX, endY, zones);
    }
  }

  void _drawZigzagRoute(
    Canvas canvas,
    Paint paint,
    double startX,
    double startY,
    double endX,
    double endY,
    List<OccupiedEnvelope> zones,
  ) {
    // Find clear vertical channels
    final segments = <Offset>[];
    segments.add(Offset(startX, startY));

    // Move vertically to intermediate level
    final midY = (startY + endY) / 2;
    segments.add(Offset(startX, midY));

    // Move horizontally, avoiding obstacles
    double currentX = startX;
    final targetX = endX;
    final step = (targetX - currentX) / 4;

    for (int i = 0; i < 3; i++) {
      currentX += step;

      // Check if this X position is clear
      bool isClear = true;
      for (final zone in zones) {
        if (currentX >= zone.xStart &&
            currentX <= zone.xEnd &&
            midY >= zone.yTop &&
            midY <= zone.yBottom) {
          isClear = false;
          break;
        }
      }

      if (isClear) {
        segments.add(Offset(currentX, midY));
      }
    }

    segments.add(Offset(endX, midY));
    segments.add(Offset(endX, endY));

    // Draw the segments
    for (int i = 0; i < segments.length - 1; i++) {
      canvas.drawLine(segments[i], segments[i + 1], paint);
    }
  }

  // Add this helper method to get unique colors for each path
  Color _getPathColor(DiagramNode node, int depth) {
    final colors = [
      Color(0xFF1976D2), // Blue
      Color(0xFFE91E63), // Pink
      Color(0xFF4CAF50), // Green
      Color(0xFFFF9800), // Orange
      Color(0xFF9C27B0), // Purple
      Color(0xFF00BCD4), // Cyan
      Color(0xFFFFEB3B), // Yellow
      Color(0xFF795548), // Brown
    ];

    return colors[(node.id + depth) % colors.length];
  }

  void _drawSmartConnection(
    Canvas canvas,
    double parentX,
    double parentY,
    double childX,
    double childY,
    DiagramNode child,
  ) {
    // ❌ REMOVED: Use neutral gray for ALL connection lines
    final paintLine = Paint()
      ..color = Color(0xFF757575) // Neutral gray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final trunkY = parentY + 60;
    final blockTop = childY - 70;
    final zones = EnvelopeLayoutManager.getOccupiedZones();

    // 1. Vertical drop from parent
    canvas.drawLine(
      Offset(parentX, trunkY),
      Offset(parentX, trunkY + 60),
      paintLine,
    );

    // 2. Find safe horizontal routing level
    double routeY = trunkY + 120;
    bool foundSafe = false;

    for (int attempt = 0; attempt < 30; attempt++) {
      bool clear = true;

      for (final zone in zones) {
        if (zone.nodeId == child.id || zone.nodeId == child.parentId) continue;

        final minX = math.min(parentX, childX);
        final maxX = math.max(parentX, childX);

        if (zone.overlapsWith(minX - 50, maxX + 50, routeY - 20, routeY + 20)) {
          clear = false;
          break;
        }
      }

      if (clear) {
        foundSafe = true;
        break;
      }
      routeY += 40;
    }

    // 3. Route to horizontal level
    canvas.drawLine(
      Offset(parentX, trunkY + 60),
      Offset(parentX, routeY),
      paintLine,
    );

    // 4. Horizontal routing
    canvas.drawLine(
      Offset(parentX, routeY),
      Offset(childX, routeY),
      paintLine,
    );

    // 5. Drop to child
    canvas.drawLine(
      Offset(childX, routeY),
      Offset(childX, blockTop),
      paintLine,
    );

    // 6. Arrow at child - use neutral color
    final arrowPath = Path();
    arrowPath.moveTo(childX, blockTop);
    arrowPath.lineTo(childX - 6, blockTop - 10);
    arrowPath.lineTo(childX + 6, blockTop - 10);
    arrowPath.close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Color(0xFF757575) // Neutral gray arrow
        ..style = PaintingStyle.fill,
    );

    // 7. Distance label with neutral background
    if (child.distance > 0) {
      String distanceText = child.distance < 1.0
          ? '${(child.distance * 1000).toStringAsFixed(0)}m'
          : '${child.distance.toStringAsFixed(2)}km';

      final distanceTp = _text(
        distanceText,
        11,
        Colors.white,
        fontWeight: FontWeight.bold,
      );

      final labelX = (parentX + childX) / 2;
      final labelY = routeY - 15;

      final bgRect = Rect.fromCenter(
        center: Offset(labelX, labelY),
        width: distanceTp.width + 20,
        height: 22,
      );

      // Neutral gray background
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, Radius.circular(11)),
        Paint()..color = Color(0xFF616161),
      );

      distanceTp.paint(
        canvas,
        Offset(labelX - distanceTp.width / 2, labelY - distanceTp.height / 2),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) => _draw(canvas, root, 3000, 100);
// Replace the _draw method in _DiagramPainter class:

  void _draw(Canvas canvas, DiagramNode node, double x, double y,
      {int level = 0}) {
    if (node.isHeadend && level == 0) {
      EnvelopeLayoutManager.reset();
    }

    if (node.children.isNotEmpty) {
      final count = node.children.length;
      List<double> xPositions = EnvelopeLayoutManager.calculateInitialPositions(
        count: count,
        parentX: x,
      );

      final childBaseY = y + EnvelopeLayoutManager.verticalSpacing;
      xPositions = EnvelopeLayoutManager.adjustForHorizontalCollisions(
        positions: xPositions,
        y: childBaseY,
      );

      for (int i = 0; i < count; i++) {
        final child = node.children[i];
        final childX = xPositions[i];
        final childY = EnvelopeLayoutManager.findFreeY(
          xCenter: childX,
          preferredY: childBaseY,
          nodeId: child.id,
        );

        EnvelopeLayoutManager.reserveSpace(
          xCenter: childX,
          yTop: childY,
          nodeId: child.id,
        );

        // SMART LINE DRAWING - Avoid blocks
        _drawSmartConnection(canvas, x, y, childX, childY, child);

        _draw(canvas, child, childX, childY, level: level + 1);
      }
    }

    // Draw current node
    if (node.isHeadend) {
      _drawHeadendBlock(canvas, x, y, node);
    } else if (node.isCouplerOutput) {
      _drawCouplerBlock(canvas, x, y, node);
    } else if (node.isSplitterOutput) {
      _drawSplitterBlock(canvas, x, y, node);
    } else {
      _drawStandardBlock(canvas, x, y, node);
    }

    EnvelopeLayoutManager.reserveSpace(
      xCenter: x,
      yTop: y - EnvelopeLayoutManager.blockHeight / 2,
      nodeId: node.id,
    );

    if (node.isLeaf && !node.isHeadend) {
      _drawHouseIcon(canvas, Offset(x, y + 100), node);
    }
  }

  void _drawConnectionLines(Canvas canvas, double parentX, double parentY,
      double childX, double childY, DiagramNode child) {
    final paintLine = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Calculate key points
    final trunkY = parentY + 45;
    final splitY = parentY + 165;
    final childTop = childY - 55; // Top of child block

    // Determine if we need to route around other blocks
    double safeSplitY = splitY;

    // Check if direct horizontal line would intersect any occupied space
    final occupiedZones = EnvelopeLayoutManager.getOccupiedZones();
    final lineMinY = splitY - 10;
    final lineMaxY = splitY + 10;

    bool hasCollision = false;
    for (final zone in occupiedZones) {
      if (zone.nodeId == child.id) continue; // Skip the child's own zone

      // Check if horizontal line would intersect this zone
      final lineLeft = math.min(parentX, childX);
      final lineRight = math.max(parentX, childX);

      if (zone.overlapsWith(lineLeft, lineRight, lineMinY, lineMaxY)) {
        hasCollision = true;
        break;
      }
    }

    // If collision, adjust splitY to go above/below the blocking zone
    if (hasCollision) {
      safeSplitY = splitY - 40; // Move horizontal line higher
    }

    // Draw vertical line from parent to split point
    canvas.drawLine(
        Offset(parentX, trunkY), Offset(parentX, safeSplitY), paintLine);

    // Draw horizontal line from parent to child
    canvas.drawLine(
        Offset(parentX, safeSplitY), Offset(childX, safeSplitY), paintLine);

    // Draw vertical line from horizontal line to child
    canvas.drawLine(
        Offset(childX, safeSplitY), Offset(childX, childTop), paintLine);

    // Add small arrow or circle at connection point to child
    canvas.drawCircle(
        Offset(childX, childTop), 4, Paint()..color = const Color(0xFF1976D2));
  }

// Replace the _findFreeY method in _DiagramPainter:
  double _findFreeY({
    required double xStart,
    required double xEnd,
    required double preferredY,
    required double height,
  }) {
    const double step = 20.0;
    double y = preferredY;

    // Use EnvelopeLayoutManager instead of _occupied
    final occupiedZones = EnvelopeLayoutManager.getOccupiedZones();

    while (true) {
      final collision = occupiedZones.any((e) {
        final xOverlap = !(xEnd < e.xStart || xStart > e.xEnd);
        final yOverlap = !(y + height < e.yTop || y > e.yBottom);
        return xOverlap && yOverlap;
      });

      if (!collision) {
        return y;
      }
      y += step;
    }
  }

  void _collectPositionsAtLevel(
      DiagramNode node, double targetY, Map<int, List<double>> levelPositions,
      {double currentY = 100, int level = 0}) {
    if (node.children.isNotEmpty) {
      for (var child in node.children) {
        double childY = currentY + EnvelopeLayoutManager.verticalSpacing;

        // Store this child's future position
        if (levelPositions[level + 1] == null) {
          levelPositions[level + 1] = [];
        }

        // Get the actual X position by simulating the layout
        final count = node.children.length;
        List<double> xPositions =
            EnvelopeLayoutManager.calculateInitialPositions(
          count: count,
          parentX: 0, // We'll calculate relative positions
        );

        // Adjust indices to match actual positions
        int childIndex = node.children.indexOf(child);
        if (childIndex < xPositions.length) {
          levelPositions[level + 1]!.add(xPositions[childIndex]);
        }

        _collectPositionsAtLevel(child, targetY, levelPositions,
            currentY: childY, level: level + 1);
      }
    }
  }

  bool _lineWouldIntersectBlock(
      double x1, double x2, double y, double thickness) {
    final occupiedZones = EnvelopeLayoutManager.getOccupiedZones();
    final lineY1 = y - thickness / 2;
    final lineY2 = y + thickness / 2;
    final lineLeft = math.min(x1, x2);
    final lineRight = math.max(x1, x2);

    for (final zone in occupiedZones) {
      // Check if line overlaps with zone
      if (zone.overlapsWith(lineLeft, lineRight, lineY1, lineY2)) {
        return true;
      }
    }
    return false;
  }

  void _drawHeadendBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 140.0;
    final blockHeight = 72.0;
    final headerHeight = 22.0;

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(shadowRect, Paint()..color = const Color(0x33000000));

    final mainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );

    // ✅ FULL GREEN GRADIENT for entire block
    final blockGradient = LinearGradient(
      colors: [Color(0xFF43A047), Color(0xFF2E7D32)], // Green gradient
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    canvas.drawRRect(
      mainRect,
      Paint()
        ..shader = blockGradient.createShader(
          Rect.fromCenter(
            center: Offset(x, y),
            width: blockWidth,
            height: blockHeight,
          ),
        ),
    );

    // Green border
    canvas.drawRRect(
      mainRect,
      Paint()
        ..color = Color(0xFF1B5E20) // Darker green border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Header section (darker green strip at top)
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
        width: blockWidth,
        height: headerHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      headerRect,
      Paint()..color = Color(0xFF2E7D32).withOpacity(0.5), // Darker overlay
    );

    // Header text (WHITE)
    final headerTp =
        _text('Headend', 11, Colors.white, fontWeight: FontWeight.bold);
    headerTp.paint(
      canvas,
      Offset(x - headerTp.width / 2,
          y - blockHeight / 2 + headerHeight / 2 - headerTp.height / 2),
    );

    // Body - Name (WHITE)
    String displayName = node.label.isEmpty ? 'EDFA' : node.label;
    final nameTp =
        _text(displayName, 12, Colors.white, fontWeight: FontWeight.w600);
    nameTp.paint(canvas, Offset(x - nameTp.width / 2, y - 10));

    // Power (WHITE with slight glow effect)
    final powerTp = _text(
        '${node.signal.toStringAsFixed(1)} dBm', 13, Colors.white,
        fontWeight: FontWeight.bold);

    // Optional: Add background for power text for better visibility
    final powerBgRect = Rect.fromCenter(
      center: Offset(x, y + 10),
      width: powerTp.width + 16,
      height: 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(powerBgRect, Radius.circular(10)),
      Paint()..color = Color(0xFF1B5E20).withOpacity(0.4),
    );

    powerTp.paint(
        canvas, Offset(x - powerTp.width / 2, y + 10 - powerTp.height / 2));
  }

  void _drawCouplerBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 120.0;
    final blockHeight =
        node.useWdm && node.wdmOutputPower != 0.0 ? 105.0 : 90.0;
    final headerHeight = 22.0;

    final flowColor = node.flowColor ?? Color(0xFFFF8F00);

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(shadowRect, Paint()..color = const Color(0x33000000));

    final mainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );

    // 🎨 FULL BACKGROUND COLOR (30% opacity)
    canvas.drawRRect(
      mainRect,
      Paint()..color = flowColor.withOpacity(0.3),
    );

    // Header with darker flow color
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
        width: blockWidth,
        height: headerHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(headerRect, Paint()..color = flowColor);

    // Border with flow color
    canvas.drawRRect(
      mainRect,
      Paint()
        ..color = flowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Header text
    final label = node.label.isEmpty ? 'Coupler' : node.label;
    final nameTp = _text(label, 10, Colors.white, fontWeight: FontWeight.bold);

    nameTp.paint(
      canvas,
      Offset(x - nameTp.width / 2,
          y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2),
    );

    // Content
    double contentY = y - 22;
    final sideRatio = node.couplerRatio ?? 50;
    final ratioTp =
        _text('$sideRatio', 13, flowColor, fontWeight: FontWeight.bold);
    ratioTp.paint(canvas, Offset(x - ratioTp.width / 2, contentY));

    contentY += 16;
    final inputPowerText =
        'In: ${_getParentPower(node).toStringAsFixed(1)} dBm';
    final inputTp =
        _text(inputPowerText, 8, Colors.black87, fontWeight: FontWeight.w500);
    inputTp.paint(canvas, Offset(x - inputTp.width / 2, contentY));

    contentY += 14;
    if (node.useWdm && node.wdmOutputPower != 0.0) {
      final wdmText = 'WDM: ${node.wdmOutputPower.toStringAsFixed(1)} dBm';
      final wdmTp = _text(wdmText, 8, Colors.orange.shade700,
          fontWeight: FontWeight.w600);
      wdmTp.paint(canvas, Offset(x - wdmTp.width / 2, contentY));
      contentY += 14;
    }

    final powerTp = _text(
      '${node.signal.toStringAsFixed(1)} dBm',
      11,
      Colors.black87,
      fontWeight: FontWeight.bold,
    );
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

  // Add this method to _DiagramPainter class:
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
    final blockHeight =
        node.useWdm && node.wdmOutputPower != 0.0 ? 105.0 : 90.0;
    final headerHeight = 22.0;

    final flowColor = node.flowColor ?? Color(0xFF7B1FA2);

    // Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + 2, y + 4), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(shadowRect, Paint()..color = const Color(0x33000000));

    final mainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );

    // 🎨 FULL BACKGROUND COLOR (30% opacity)
    canvas.drawRRect(
      mainRect,
      Paint()..color = flowColor.withOpacity(0.3),
    );

    // Header with darker flow color
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
        width: blockWidth,
        height: headerHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(headerRect, Paint()..color = flowColor);

    // Border with flow color
    canvas.drawRRect(
      mainRect,
      Paint()
        ..color = flowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Header text
    final displayName = node.label.isEmpty ? 'Splitter' : node.label;
    final nameTp =
        _text(displayName, 10, Colors.white, fontWeight: FontWeight.bold);

    nameTp.paint(
      canvas,
      Offset(x - nameTp.width / 2,
          y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2),
    );

    // Content
    double contentY = y - 22;
    String splitInfo = '1x?';
    if (node.deviceConfig != null) {
      final parts = node.deviceConfig!.split('::');
      if (parts.isNotEmpty) {
        final split = int.tryParse(parts[0]) ?? 2;
        splitInfo = '1x$split';
      }
    }

    final splitTp =
        _text(splitInfo, 13, flowColor, fontWeight: FontWeight.bold);
    splitTp.paint(canvas, Offset(x - splitTp.width / 2, contentY));

    contentY += 16;
    final inputPowerText =
        'In: ${_getParentPower(node).toStringAsFixed(1)} dBm';
    final inputTp =
        _text(inputPowerText, 8, Colors.black87, fontWeight: FontWeight.w500);
    inputTp.paint(canvas, Offset(x - inputTp.width / 2, contentY));

    contentY += 14;
    if (node.useWdm && node.wdmOutputPower != 0.0) {
      final wdmText = 'WDM: ${node.wdmOutputPower.toStringAsFixed(1)} dBm';
      final wdmTp = _text(wdmText, 8, Colors.purple.shade700,
          fontWeight: FontWeight.w600);
      wdmTp.paint(canvas, Offset(x - wdmTp.width / 2, contentY));
      contentY += 14;
    }

    final powerTp = _text(
      '${node.signal.toStringAsFixed(1)} dBm',
      11,
      Colors.black87,
      fontWeight: FontWeight.bold,
    );
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, contentY));
  }

  void _drawStandardBlock(Canvas canvas, double x, double y, DiagramNode node) {
    final blockWidth = 120.0;
    final blockHeight = 72.0;
    final headerHeight = 22.0;

    final flowColor = node.flowColor ?? Color(0xFF1A237E);

    final mainRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x, y), width: blockWidth, height: blockHeight),
      const Radius.circular(6),
    );

    // 🎨 FULL BACKGROUND COLOR (30% opacity)
    canvas.drawRRect(
      mainRect,
      Paint()..color = flowColor.withOpacity(0.3),
    );

    // Header with darker flow color
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y - blockHeight / 2 + headerHeight / 2),
        width: blockWidth,
        height: headerHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(headerRect, Paint()..color = flowColor);

    // Border with flow color
    canvas.drawRRect(
      mainRect,
      Paint()
        ..color = flowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Header text
    final displayName = node.label.isEmpty ? 'Node' : node.label;
    final nameTp =
        _text(displayName, 10, Colors.white, fontWeight: FontWeight.bold);

    nameTp.paint(
      canvas,
      Offset(x - nameTp.width / 2,
          y - blockHeight / 2 + headerHeight / 2 - nameTp.height / 2),
    );

    // Power value
    final powerTp = _text(
      '${node.signal.toStringAsFixed(1)} dBm',
      12,
      Colors.black87,
      fontWeight: FontWeight.bold,
    );
    powerTp.paint(canvas, Offset(x - powerTp.width / 2, y + 5));
  }

  // Update _drawHouseIcon to check if node is in highlighted list
  void _drawHouseIcon(Canvas canvas, Offset center, DiagramNode node) {
    final c = center;

    // ✅ HIGHLIGHT ALL MATCHING NODES
    if (highlightedNodes.any((n) => n.id == node.id)) {
      // Draw pulsing highlight circle
      final highlightPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(c.dx, c.dy), 35, highlightPaint);

      // Draw highlight border
      final borderPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(c.dx, c.dy), 35, borderPaint);
    }
    /* ---------- Soft Shadow ---------- */
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + 22),
        width: 42,
        height: 8,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    /* ---------- House Body ---------- */
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 44, height: 30),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      bodyRect,
      Paint()..color = const Color(0xFFF7F6F2), // soft ivory
    );

    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    /* ---------- Roof (Modern) ---------- */
    final roofPath = Path()
      ..moveTo(c.dx, c.dy - 28)
      ..lineTo(c.dx - 26, c.dy - 6)
      ..lineTo(c.dx + 26, c.dy - 6)
      ..close();

    canvas.drawPath(
      roofPath,
      Paint()..color = const Color(0xFF607D8B), // slate blue
    );

    /* ---------- Door ---------- */
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + 8),
        width: 10,
        height: 16,
      ),
      const Radius.circular(3),
    );

    canvas.drawRRect(
      doorRect,
      Paint()..color = const Color(0xFFB08968), // warm wood
    );

    canvas.drawCircle(
      Offset(c.dx + 3, c.dy + 8),
      1.2,
      Paint()..color = Colors.white70,
    );

    /* ---------- Windows (Glass look) ---------- */
    Paint windowPaint = Paint()
      ..color = const Color(0xFFB3E5FC); // soft glass blue

    void window(Offset pos) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: pos, width: 8, height: 8),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, windowPaint);
    }

    window(Offset(c.dx - 12, c.dy - 2));
    window(Offset(c.dx + 12, c.dy - 2));

    /* ---------- Minimal Attic Dot ---------- */
    canvas.drawCircle(
      Offset(c.dx, c.dy - 14),
      2.5,
      Paint()..color = Colors.grey.shade400,
    );
/* ---------- Text with Power Display ---------- */
    double textY = c.dy + 34;

// Display endpoint name
    if (node.endpointName != null && node.endpointName!.isNotEmpty) {
      final nameTp = _text(
        node.endpointName!,
        11,
        const Color(0xFF263238),
        fontWeight: FontWeight.w600,
      );

      nameTp.paint(
        canvas,
        Offset(c.dx - nameTp.width / 2, textY),
      );

      textY += 18;
    }

// Display power value (ALWAYS show for endpoints)
    final powerText = '${node.signal.toStringAsFixed(1)} dBm';
    final powerTp = _text(
      powerText,
      10,
      const Color(0xFF1976D2), // Blue color for power
      fontWeight: FontWeight.bold,
    );

// Background for power
    final powerBgRect = Rect.fromCenter(
      center: Offset(c.dx, textY + 9),
      width: powerTp.width + 16,
      height: 18,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(powerBgRect, const Radius.circular(9)),
      Paint()..color = Colors.blue.shade50,
    );

    powerTp.paint(
      canvas,
      Offset(c.dx - powerTp.width / 2, textY),
    );

    textY += 20;

// Display description
    if (node.endpointDescription != null &&
        node.endpointDescription!.isNotEmpty) {
      final descTp = _text(
        node.endpointDescription!,
        9,
        Colors.grey.shade700,
      );

      descTp.paint(
        canvas,
        Offset(c.dx - descTp.width / 2, textY),
      );
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
