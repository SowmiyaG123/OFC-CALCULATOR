// lib/screens/diagram/diagram_page.dart
// Final professional OFC Diagram Generator — Unlimited Dynamic Nodes (Option C)
// Integrates provided CouplerCalculator & SplitterCalculator logic.

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

// ---------------- Constants ----------------
final double defaultHeadendDbm = 19.0;
final double fiberAttenuationDbPerKm =
    0.35; // dB per km attenuation (adjustable)

// ---------------- Diagram Node ----------------
class DiagramNode {
  int id;
  String label;
  double signal; // dBm at node
  double distance; // km to this node from parent
  List<DiagramNode> children;
  int? parentId;
  String deviceType; // 'headend','coupler','splitter','leaf','pass'
  String?
      deviceConfig; // encoded metadata (section::ratio::value or section::split::value)
  int outputPort;
  double deviceLoss; // The actual loss value for this port

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
  }) : children = children ?? [];

  bool get isLeaf => children.isEmpty;
  bool get isCoupler => deviceType == 'coupler';
  bool get isSplitter => deviceType == 'splitter';
  bool get isHeadend => deviceType == 'headend';
}

// ---------------- CouplerCalculator (inlined from your file) ----------------
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

// ---------------- SplitterCalculator (inlined) ----------------
class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};
    final loss1550 = [-3.6, -6.8, -10.0, -13.0, -16.0, -19.5];
    final loss1310 = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];

    double adjust = splitterValue - 1.0;

    result["LOSS-15 50"] = List.generate(splits.length,
        (i) => {'split': splits[i], 'value': loss1550[i] + adjust});
    result["LOSS-13 10"] = List.generate(splits.length,
        (i) => {'split': splits[i], 'value': loss1310[i] + adjust});

    return result;
  }
}

// ---------------- OFC Diagram Page ----------------
class OFCDiagramPage extends StatefulWidget {
  const OFCDiagramPage({Key? key}) : super(key: key);
  @override
  State<OFCDiagramPage> createState() => _OFCDiagramPageState();
}

class _OFCDiagramPageState extends State<OFCDiagramPage> {
  final GlobalKey repaintKey = GlobalKey();
  final TextEditingController _headendNameCtrl =
      TextEditingController(text: "EDFA/PON/TR");
  final TextEditingController _headendDbmCtrl =
      TextEditingController(text: defaultHeadendDbm.toString());

  DiagramNode? root;
  int _nodeCounter = 0;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initRoot();
    Hive.openBox('diagram_history');
    Hive.openBox('diagram_downloads');
  }

  void _initRoot() {
    root = DiagramNode(
      id: _nodeCounter++,
      label: _headendNameCtrl.text,
      signal: double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm,
      distance: 0,
      deviceType: 'headend',
    );
  }

  // ---------- recalc function using deviceConfig + calculators ----------
  void _recalculate(DiagramNode node) {
    if (node.children.isEmpty) return;

    if (node.isCoupler && node.deviceConfig != null) {
      // format: "SECTION::RATIO::COUPLERVALUE"
      final parts = node.deviceConfig!.split('::');
      final section = parts.isNotEmpty ? parts[0] : 'LOSS-15 50';
      final ratio = parts.length > 1 ? int.tryParse(parts[1]) ?? 50 : 50;
      final couplerVal =
          parts.length > 2 ? double.tryParse(parts[2]) ?? 1.0 : 1.0;

      final calc = CouplerCalculator(couplerVal);
      final all = calc.calculateLoss();
      final sec =
          all.firstWhere((s) => s['section'] == section, orElse: () => all[0]);
      final data = (sec['data'] as List).cast<Map<String, dynamic>>();
      final entry =
          data.firstWhere((e) => e['ratio'] == ratio, orElse: () => data.last);
      final p1 = (entry['val1'] as num).toDouble();
      final p2 = (entry['val2'] as num).toDouble();

      final losses = [p1, p2];
      for (int i = 0; i < node.children.length && i < 2; i++) {
        final child = node.children[i];
        final dLoss = child.distance * fiberAttenuationDbPerKm;
        child.deviceLoss = losses[i].abs();
        child.signal = node.signal + losses[i] - dLoss;
        child.outputPort = i;
        _recalculate(child);
      }
    } else if (node.isSplitter && node.deviceConfig != null) {
      // format: "SECTION::SPLIT::SPLITTERVALUE"
      final parts = node.deviceConfig!.split('::');
      final section = parts.isNotEmpty ? parts[0] : 'LOSS-15 50';
      final split = parts.length > 1 ? int.tryParse(parts[1]) ?? 2 : 2;
      final splitterVal =
          parts.length > 2 ? double.tryParse(parts[2]) ?? 1.0 : 1.0;

      final calc = SplitterCalculator(splitterVal);
      final all = calc.calculateLoss();
      final sec = all[section]!;
      final entry =
          sec.firstWhere((e) => e['split'] == split, orElse: () => sec.first);
      final perLoss = (entry['value'] as num).toDouble();

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final dLoss = child.distance * fiberAttenuationDbPerKm;
        child.deviceLoss = perLoss.abs();
        child.signal = node.signal + perLoss - dLoss;
        child.outputPort = i;
        _recalculate(child);
      }
    } else {
      // pass-through (only distance loss)
      for (final child in node.children) {
        final dLoss = child.distance * fiberAttenuationDbPerKm;
        child.signal = node.signal - dLoss;
        _recalculate(child);
      }
    }
  }

  void _updateHeadend() {
    setState(() {
      root!.label =
          _headendNameCtrl.text.isEmpty ? 'EDFA/PON/TR' : _headendNameCtrl.text;
      root!.signal = double.tryParse(_headendDbmCtrl.text) ?? defaultHeadendDbm;
      _recalculate(root!);
    });
  }

  // ---------- Add N-ary generic children ----------
  Future<void> _addNChildren(DiagramNode parent) async {
    final countCtrl = TextEditingController(text: '2');
    final distanceCtrl = TextEditingController(text: '0.5');
    final labelCtrl = TextEditingController(text: 'Node');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add children (N-ary)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count')),
            const SizedBox(height: 8),
            TextField(
                controller: distanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Distance (km)')),
            const SizedBox(height: 8),
            TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Base label')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final cnt = (int.tryParse(countCtrl.text) ?? 2).clamp(1, 256);
                final dist = double.tryParse(distanceCtrl.text) ?? 0.5;
                final base = labelCtrl.text.isEmpty ? 'Node' : labelCtrl.text;
                final List<DiagramNode> ch = [];
                for (int i = 0; i < cnt; i++) {
                  ch.add(DiagramNode(
                    id: _nodeCounter++,
                    label: '$base ${i + 1}',
                    signal: parent.signal - (dist * fiberAttenuationDbPerKm),
                    distance: dist,
                    parentId: parent.id,
                    deviceType: 'leaf',
                    outputPort: i,
                  ));
                }
                parent.children = ch;
                parent.deviceType =
                    parent.isHeadend ? parent.deviceType : 'pass';
                parent.deviceConfig = null;
                _recalculate(root!);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  // ---------- Add Coupler (N-port, generalized) ----------
  Future<void> _addCoupler(DiagramNode parent) async {
    if (parent.children.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Remove existing branch before adding device')));
      return;
    }
    final couplerValCtrl = TextEditingController(text: '1.0');
    final portCountCtrl = TextEditingController(text: '2');
    final distanceCtrl = TextEditingController(text: '0.5');
    String section = 'LOSS-15 50';
    int ratio = 50;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        return AlertDialog(
          title: const Text('Add Coupler'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: couplerValCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Coupler value')),
              const SizedBox(height: 8),
              TextField(
                  controller: portCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Number of ports (2/4/6/8/16)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: section,
                items: const [
                  DropdownMenuItem(
                      value: 'LOSS-15 50', child: Text('LOSS-15 50')),
                  DropdownMenuItem(
                      value: 'LOSS-13 10', child: Text('LOSS-13 10'))
                ],
                onChanged: (v) => setInner(() => section = v ?? section),
                decoration: const InputDecoration(labelText: 'Section'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: ratio,
                items: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
                    .map((r) => DropdownMenuItem(value: r, child: Text('$r')))
                    .toList(),
                onChanged: (v) => setInner(() => ratio = v ?? ratio),
                decoration: const InputDecoration(labelText: 'Ratio'),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Distance (km)')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final couplerVal =
                      double.tryParse(couplerValCtrl.text) ?? 1.0;
                  final dist = double.tryParse(distanceCtrl.text) ?? 0.5;
                  final portCount = [2, 4, 6, 8, 16]
                          .contains(int.tryParse(portCountCtrl.text ?? '2'))
                      ? int.parse(portCountCtrl.text)
                      : 2;

                  final calc = CouplerCalculator(couplerVal);
                  final list = calc.calculateLoss();
                  final sec = list.firstWhere((s) => s['section'] == section,
                      orElse: () => list[0]);
                  final data =
                      (sec['data'] as List).cast<Map<String, dynamic>>();
                  final entry = data.firstWhere((e) => e['ratio'] == ratio,
                      orElse: () => data.last);
                  final v1 = (entry['val1'] as num).toDouble();
                  final v2 = (entry['val2'] as num).toDouble();

                  // Calculate losses for N ports: distribute v1 and v2 across all
                  List<double> losses = [];
                  if (portCount == 2) {
                    losses = [v1, v2];
                  } else {
                    final average = ((v1 + v2) / 2);
                    for (int i = 0; i < portCount; i++) {
                      losses.add(average);
                    }
                  }

                  parent.children = List.generate(
                      portCount,
                      (i) => DiagramNode(
                            id: _nodeCounter++,
                            label: 'Port ${i + 1}',
                            signal: parent.signal +
                                losses[i] -
                                (dist * fiberAttenuationDbPerKm),
                            distance: dist,
                            parentId: parent.id,
                            deviceType: 'leaf',
                            outputPort: i,
                            deviceLoss: losses[i].abs(),
                          ));
                  parent.deviceType = 'coupler';
                  parent.deviceConfig =
                      '$section::${ratio.toString()}::${couplerVal.toStringAsFixed(3)}::N$portCount';
                  _recalculate(root!);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Coupler'),
            )
          ],
        );
      }),
    );
  }

  // ---------- Add Splitter (dropdown) ----------
  Future<void> _addSplitter(DiagramNode parent) async {
    if (parent.children.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Remove existing branch before adding device')));
      return;
    }
    final splitterValCtrl = TextEditingController(text: '1.0');
    final distanceCtrl = TextEditingController(text: '0.5');
    String section = 'LOSS-15 50';
    int split = 2;
    final splits = [2, 4, 8, 16, 32, 64];

    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
              return AlertDialog(
                title: const Text('Add Splitter'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: splitterValCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Splitter value')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: section,
                      items: const [
                        DropdownMenuItem(
                            value: 'LOSS-15 50', child: Text('LOSS-15 50')),
                        DropdownMenuItem(
                            value: 'LOSS-13 10', child: Text('LOSS-13 10'))
                      ],
                      onChanged: (v) => setInner(() => section = v ?? section),
                      decoration: const InputDecoration(labelText: 'Section'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: split,
                      items: splits
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text('1x$s')))
                          .toList(),
                      onChanged: (v) => setInner(() => split = v ?? split),
                      decoration: const InputDecoration(labelText: 'Split'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: distanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Distance (km)')),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final splitterVal =
                            double.tryParse(splitterValCtrl.text) ?? 1.0;
                        final dist = double.tryParse(distanceCtrl.text) ?? 0.5;
                        final calc = SplitterCalculator(splitterVal);
                        final map = calc.calculateLoss();
                        final sec = map[section]!;
                        final entry = sec.firstWhere((e) => e['split'] == split,
                            orElse: () => sec.first);
                        final perLoss = (entry['value'] as num).toDouble();

                        parent.children = List.generate(
                            split,
                            (i) => DiagramNode(
                                  id: _nodeCounter++,
                                  label: 'Port ${i + 1}',
                                  signal: parent.signal +
                                      perLoss -
                                      (dist * fiberAttenuationDbPerKm),
                                  distance: dist,
                                  parentId: parent.id,
                                  deviceType: 'leaf',
                                  outputPort: i,
                                  deviceLoss: perLoss.abs(),
                                ));

                        parent.deviceType = 'splitter';
                        parent.deviceConfig =
                            '$section::${split.toString()}::${splitterVal.toStringAsFixed(3)}';
                        _recalculate(root!);
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Splitter'),
                  )
                ],
              );
            }));
  }

  // ---------- Edit Node / Device ----------
  Future<void> _editNode(DiagramNode node) async {
    if (node.isCoupler) {
      // parse config
      String section = 'LOSS-15 50';
      int ratio = 50;
      double couplerVal = 1.0;
      double childDist =
          node.children.isNotEmpty ? node.children[0].distance : 0.5;

      if (node.deviceConfig != null) {
        final p = node.deviceConfig!.split('::');
        if (p.isNotEmpty) section = p[0];
        if (p.length > 1) ratio = int.tryParse(p[1]) ?? ratio;
        if (p.length > 2) couplerVal = double.tryParse(p[2]) ?? couplerVal;
      }

      final couplerCtrl = TextEditingController(text: couplerVal.toString());
      final distanceCtrl = TextEditingController(text: childDist.toString());
      String sSection = section;
      int sRatio = ratio;

      await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
                return AlertDialog(
                  title: const Text('Edit Coupler'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: couplerCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Coupler value')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        value: sSection,
                        items: const [
                          DropdownMenuItem(
                              value: 'LOSS-15 50', child: Text('LOSS-15 50')),
                          DropdownMenuItem(
                              value: 'LOSS-13 10', child: Text('LOSS-13 10'))
                        ],
                        onChanged: (v) =>
                            setInner(() => sSection = v ?? sSection),
                        decoration:
                            const InputDecoration(labelText: 'Section')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                        value: sRatio,
                        items: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
                            .map((r) =>
                                DropdownMenuItem(value: r, child: Text('$r')))
                            .toList(),
                        onChanged: (v) => setInner(() => sRatio = v ?? sRatio),
                        decoration: const InputDecoration(labelText: 'Ratio')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: distanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Distance (km) for outputs')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            final newVal =
                                double.tryParse(couplerCtrl.text) ?? couplerVal;
                            final newDist =
                                double.tryParse(distanceCtrl.text) ?? childDist;
                            final calc = CouplerCalculator(newVal);
                            final list = calc.calculateLoss();
                            final sec = list.firstWhere(
                                (s) => s['section'] == sSection,
                                orElse: () => list[0]);
                            final data = (sec['data'] as List)
                                .cast<Map<String, dynamic>>();
                            final entry = data.firstWhere(
                                (e) => e['ratio'] == sRatio,
                                orElse: () => data.last);
                            final v1 = (entry['val1'] as num).toDouble();
                            final v2 = (entry['val2'] as num).toDouble();

                            // update children count to 2 if necessary
                            if (node.children.length < 2) {
                              node.children = [
                                DiagramNode(
                                    id: _nodeCounter++,
                                    label: 'Port 1',
                                    signal: node.signal +
                                        v1 -
                                        (newDist * fiberAttenuationDbPerKm),
                                    distance: newDist,
                                    parentId: node.id,
                                    deviceType: 'leaf',
                                    outputPort: 0,
                                    deviceLoss: v1.abs()),
                                DiagramNode(
                                    id: _nodeCounter++,
                                    label: 'Port 2',
                                    signal: node.signal +
                                        v2 -
                                        (newDist * fiberAttenuationDbPerKm),
                                    distance: newDist,
                                    parentId: node.id,
                                    deviceType: 'leaf',
                                    outputPort: 1,
                                    deviceLoss: v2.abs()),
                              ];
                            } else {
                              node.children[0].distance = newDist;
                              node.children[0].deviceLoss = v1.abs();
                              node.children[0].signal = node.signal +
                                  v1 -
                                  (newDist * fiberAttenuationDbPerKm);
                              node.children[1].distance = newDist;
                              node.children[1].deviceLoss = v2.abs();
                              node.children[1].signal = node.signal +
                                  v2 -
                                  (newDist * fiberAttenuationDbPerKm);
                            }
                            node.deviceConfig =
                                '$sSection::${sRatio.toString()}::${newVal.toStringAsFixed(3)}';
                            _recalculate(root!);
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'))
                  ],
                );
              }));
    } else if (node.isSplitter) {
      String section = 'LOSS-15 50';
      int split = 2;
      double splitterVal = 1.0;
      double childDist =
          node.children.isNotEmpty ? node.children[0].distance : 0.5;

      if (node.deviceConfig != null) {
        final p = node.deviceConfig!.split('::');
        if (p.isNotEmpty) section = p[0];
        if (p.length > 1) split = int.tryParse(p[1]) ?? split;
        if (p.length > 2) splitterVal = double.tryParse(p[2]) ?? splitterVal;
      }

      final splitterCtrl = TextEditingController(text: splitterVal.toString());
      final distanceCtrl = TextEditingController(text: childDist.toString());
      int sSplit = split;
      String sSection = section;
      final splits = [2, 4, 8, 16, 32, 64];

      await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
                return AlertDialog(
                  title: const Text('Edit Splitter'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: splitterCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Splitter value')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        value: sSection,
                        items: const [
                          DropdownMenuItem(
                              value: 'LOSS-15 50', child: Text('LOSS-15 50')),
                          DropdownMenuItem(
                              value: 'LOSS-13 10', child: Text('LOSS-13 10'))
                        ],
                        onChanged: (v) =>
                            setInner(() => sSection = v ?? sSection),
                        decoration:
                            const InputDecoration(labelText: 'Section')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                        value: sSplit,
                        items: splits
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text('1x$s')))
                            .toList(),
                        onChanged: (v) => setInner(() => sSplit = v ?? sSplit),
                        decoration: const InputDecoration(labelText: 'Split')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: distanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Distance (km) for outputs')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () {
                          setState(() {
                            final newVal = double.tryParse(splitterCtrl.text) ??
                                splitterVal;
                            final newDist =
                                double.tryParse(distanceCtrl.text) ?? childDist;
                            final calc = SplitterCalculator(newVal);
                            final all = calc.calculateLoss();
                            final sec = all[sSection]!;
                            final entry = sec.firstWhere(
                                (e) => e['split'] == sSplit,
                                orElse: () => sec.first);
                            final per = (entry['value'] as num).toDouble();

                            // recreate children if count differs
                            if (node.children.length != sSplit) {
                              node.children = List.generate(
                                  sSplit,
                                  (i) => DiagramNode(
                                        id: _nodeCounter++,
                                        label: 'Port ${i + 1}',
                                        signal: node.signal +
                                            per -
                                            (newDist * fiberAttenuationDbPerKm),
                                        distance: newDist,
                                        parentId: node.id,
                                        deviceType: 'leaf',
                                        outputPort: i,
                                        deviceLoss: per.abs(),
                                      ));
                            } else {
                              for (int i = 0; i < node.children.length; i++) {
                                node.children[i].distance = newDist;
                                node.children[i].deviceLoss = per.abs();
                                node.children[i].signal = node.signal +
                                    per -
                                    (newDist * fiberAttenuationDbPerKm);
                              }
                            }

                            node.deviceConfig =
                                '$sSection::${sSplit.toString()}::${newVal.toStringAsFixed(3)}';
                            _recalculate(root!);
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'))
                  ],
                );
              }));
    } else {
      // generic node editing
      final labelCtrl = TextEditingController(text: node.label);
      final distCtrl = TextEditingController(text: node.distance.toString());
      await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Edit Node'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'Label')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: distCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Distance (km)')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          node.label = labelCtrl.text;
                          node.distance =
                              double.tryParse(distCtrl.text) ?? node.distance;
                          _recalculate(root!);
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'))
                ],
              ));
    }
  }

  // ---------- Delete Entire Branch (only allowed) ----------
  void _deleteBranch(DiagramNode node) {
    if (node.parentId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cannot delete headend')));
      return;
    }
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete Branch?'),
              content: Text(
                  'Delete "${node.label}" and ${_countDescendants(node)} descendant(s)? Note: single-leaf deletion not allowed.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final parent = _findNode(root, node.parentId!);
                        if (parent != null) {
                          parent.children = parent.children
                              .where((c) => c.id != node.id)
                              .toList();
                          if (parent.children.isEmpty && !parent.isHeadend) {
                            parent.deviceType = 'leaf';
                            parent.deviceConfig = null;
                          }
                          _recalculate(root!);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete'))
              ],
            ));
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

  // ---------- Node option sheet ----------
  void _showNodeOptions(DiagramNode node) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.layers),
                  title: const Text('Add Children (N-ary)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addNChildren(node);
                  }),
              ListTile(
                  leading: const Icon(Icons.call_split),
                  title: const Text('Add Coupler'),
                  subtitle: const Text('2-port unequal split'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addCoupler(node);
                  }),
              ListTile(
                  leading: const Icon(Icons.account_tree),
                  title: const Text('Add Splitter'),
                  subtitle: const Text('1xN equal split'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addSplitter(node);
                  }),
              ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Node / Device'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _editNode(node);
                  }),
              if (node.parentId != null)
                ListTile(
                    leading: const Icon(Icons.delete_sweep, color: Colors.red),
                    title: const Text('Delete Entire Branch'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteBranch(node);
                    }),
              ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Close'),
                  onTap: () => Navigator.pop(ctx)),
            ])));
  }

  // ---------- Save as image ----------
  Future<void> _saveDiagram() async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Boundary not found');
      final ui.Image img = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final bytes = byteData.buffer.asUint8List();

      String? localPath;
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
              'download', 'ofc_${DateTime.now().millisecondsSinceEpoch}.png')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        Directory dir;
        final possible = Directory('/storage/emulated/0/Download');
        if (await possible.exists())
          dir = possible;
        else
          dir = await getApplicationDocumentsDirectory();
        final file = File(
            '${dir.path}/ofc_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        localPath = file.path;
      }

      // optional supabase upload
      String? publicUrl;
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final storagePath =
              '${user.id}/${DateTime.now().millisecondsSinceEpoch}.png';
          await _supabase.storage
              .from('diagrams')
              .uploadBinary(storagePath, bytes);
          publicUrl =
              _supabase.storage.from('diagrams').getPublicUrl(storagePath);
        }
      } catch (e) {
        print('Supabase upload error: $e');
      }

      final box = await Hive.openBox('diagram_downloads');
      await box.add({
        'local': localPath,
        'cloud': publicUrl,
        'date': DateTime.now().toIso8601String()
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(publicUrl != null ? 'Saved & uploaded' : 'Saved locally')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ---------- Build UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('OFC Diagram Generator',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF163A8A),
        actions: [
          IconButton(
              onPressed: () {
                setState(() {
                  _nodeCounter = 0;
                  _initRoot();
                });
              },
              icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _saveDiagram, icon: const Icon(Icons.download)),
        ],
      ),
      body: Column(children: [
        // Premium headend header (pills)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF163A8A), Color(0xFF2E6DF6)]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(children: [
            Expanded(
              flex: 6,
              child: TextField(
                controller: _headendNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Headend Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _headendDbmCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'dBm',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _updateHeadend,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF163A8A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Update',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Canvas
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
                boundaryMargin: const EdgeInsets.all(200),
                minScale: 0.3,
                maxScale: 5.0,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: 2400,
                    height: 1600,
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
      ]),
    );
  }
}

// ---------------- Diagram render widget ----------------
class DiagramWidget extends StatelessWidget {
  final DiagramNode root;
  final void Function(DiagramNode) onTapNode;
  const DiagramWidget({super.key, required this.root, required this.onTapNode});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _DiagramPainter(root: root),
        child: Stack(children: _overlay(root, 1200, 80)));
  }

  List<Widget> _overlay(DiagramNode node, double x, double y) {
    final widgets = <Widget>[];
    widgets.add(Positioned(
        left: x - 100,
        top: y - 40,
        width: 200,
        height: 80,
        child: GestureDetector(
            onTap: () => onTapNode(node),
            child: Container(color: Colors.transparent))));
    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final spacing = 200.0;
      final total = (count - 1) * spacing;
      final startX = x - total / 2;
      for (int i = 0; i < count; i++) {
        final childX = startX + i * spacing;
        widgets.addAll(_overlay(node.children[i], childX, y + 180));
      }
    }
    return widgets;
  }
}

class _DiagramPainter extends CustomPainter {
  final DiagramNode root;
  _DiagramPainter({required this.root});

  @override
  void paint(Canvas canvas, Size size) => _draw(canvas, root, 1200, 80);

  void _draw(Canvas canvas, DiagramNode node, double x, double y) {
    // children
    if (node.children.isNotEmpty) {
      final count = node.children.length;
      final spacing = 200.0;
      final total = (count - 1) * spacing;
      final startX = x - total / 2;
      final paintLine = Paint()
        ..color = Colors.grey.shade500
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < count; i++) {
        final childX = startX + i * spacing;
        final childY = y + 180;
        final path = Path();
        path.moveTo(x, y + 40);
        path.quadraticBezierTo(x, y + 110, childX, childY - 40);
        canvas.drawPath(path, paintLine);

        _draw(canvas, node.children[i], childX, childY);

        // Display loss value and signal on the line
        if (node.children[i].deviceLoss > 0) {
          final lossTp = _text(
              'Loss: ${node.children[i].deviceLoss.toStringAsFixed(2)} dB',
              10,
              Colors.red.shade700,
              fontWeight: FontWeight.bold);
          lossTp.paint(canvas, Offset(childX - lossTp.width / 2, childY - 75));
        }

        final tp = _text('${node.children[i].signal.toStringAsFixed(2)} dBm',
            11, Colors.grey.shade700);
        tp.paint(canvas, Offset(childX - tp.width / 2, childY - 60));
      }
    }

    // node box
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 180, height: 90),
        const Radius.circular(14));
    Color fill;
    if (node.isHeadend)
      fill = const Color(0xFF10B981);
    else if (node.isCoupler)
      fill = const Color(0xFF3B82F6);
    else if (node.isSplitter)
      fill = const Color(0xFF8B5CF6);
    else
      fill = const Color(0xFF6B7280);

    // shadow
    canvas.drawRRect(
        rect.shift(const Offset(0, 4)),
        Paint()
          ..color = Colors.black.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);

    final labelTp =
        _text(node.label, 14, Colors.white, fontWeight: FontWeight.bold);
    labelTp.paint(canvas, Offset(x - labelTp.width / 2, y - 22));

    final sigTp = _text('${node.signal.toStringAsFixed(2)} dBm', 12,
        Colors.white.withOpacity(0.95));
    sigTp.paint(canvas, Offset(x - sigTp.width / 2, y + 4));

    if (node.isLeaf && !node.isHeadend) _drawHouse(canvas, Offset(x, y + 60));
  }

  void _drawHouse(Canvas canvas, Offset c) {
    final paint = Paint()..color = const Color(0xFF8B4513);
    final size = 24.0;

    // Roof
    final roof = Path();
    roof.moveTo(c.dx, c.dy - size * 0.5);
    roof.lineTo(c.dx - size * 0.7, c.dy);
    roof.lineTo(c.dx + size * 0.7, c.dy);
    roof.close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFD32F2F));

    // House body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + size * 0.4),
                width: size * 1.2,
                height: size * 0.8),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFFFE082));

    // Door
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy + size * 0.6),
                width: size * 0.35,
                height: size * 0.5),
            const Radius.circular(2)),
        Paint()..color = paint.color);

    // Window
    canvas.drawCircle(Offset(c.dx + size * 0.3, c.dy + size * 0.3), size * 0.15,
        Paint()..color = const Color(0xFF64B5F6));

    // Chimney
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
