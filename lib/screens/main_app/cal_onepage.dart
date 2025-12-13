import 'package:flutter/material.dart';

// -------------------- WDM Calculator --------------------
class WDMCalculator {
  final double wdmValue; // This is the same as the WDM Loss (dB) input

  WDMCalculator({
    required this.wdmValue,
  });

  // WDM Coupler data - SAME as LOSS-13 10
  List<Map<String, double>> calculateWDMCoupler() {
    // Reference data - EXACTLY same structure as LOSS-13 10
    final Map<double, List<Map<String, double>>> wdmCouplerData = {
      1.0: [
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
      2.0: [
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
      10.0: [
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
    };

    // Get interpolation keys
    final keys = wdmCouplerData.keys.toList()..sort();
    double lower = keys.first;
    double upper = keys.last;

    for (int i = 0; i < keys.length - 1; i++) {
      if (wdmValue >= keys[i] && wdmValue <= keys[i + 1]) {
        lower = keys[i];
        upper = keys[i + 1];
        break;
      }
    }

    // Linear interpolation - SAME LOGIC as LOSS-13 10
    double ratio = (wdmValue - lower) / (upper - lower);
    final lowerData = wdmCouplerData[lower]!;
    final upperData = wdmCouplerData[upper]!;

    List<Map<String, double>> results = [];
    for (int i = 0; i < lowerData.length; i++) {
      double val1 = lowerData[i]["val1"]! +
          (upperData[i]["val1"]! - lowerData[i]["val1"]!) * ratio;
      double val2 = lowerData[i]["val2"]! +
          (upperData[i]["val2"]! - lowerData[i]["val2"]!) * ratio;
      results.add({
        "ratio": lowerData[i]["ratio"]!,
        "val1": double.parse(val1.toStringAsFixed(1)),
        "val2": double.parse(val2.toStringAsFixed(1)),
      });
    }

    return results;
  }

  // WDM Splitter data - SAME as LOSS-13 10 splitter
  List<Map<String, dynamic>> calculateWDMSplitter() {
    final List<int> splits = [2, 4, 8, 16, 32, 64];
    
    // Base values for splitter - SAME as LOSS-13 10 splitter base values
    final baseValues = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];
    
    // Adjust based on input value (same logic as splitter calculator)
    final adjust = wdmValue - 1.0;
    
    List<Map<String, dynamic>> results = [];
    for (int i = 0; i < splits.length; i++) {
      final value = baseValues[i] + adjust;
      results.add({
        'split': splits[i],
        'value': double.parse(value.toStringAsFixed(1))
      });
    }
    
    return results;
  }
}

// -------------------- CouplerCalculator --------------------
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
          "val1": double.parse(val1.toStringAsFixed(1)),
          "val2": double.parse(val2.toStringAsFixed(1)),
        });
      }
      result.add({"section": section, "data": interpolated});
    }

    return result;
  }
}

// -------------------- SplitterCalculator --------------------
class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};

    final loss1550 = [-3.6, -6.8, -10.0, -13.0, -16.0, -19.5];
    final loss1310 = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];

    final adjust = splitterValue - 1.0;

    result["LOSS-15 50"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value': double.parse((loss1550[i] + adjust).toStringAsFixed(1))
            });

    result["LOSS-13 10"] = List.generate(
        splits.length,
        (i) => {
              'split': splits[i],
              'value': double.parse((loss1310[i] + adjust).toStringAsFixed(1))
            });

    return result;
  }
}

class CouplerSplitterOnePage extends StatefulWidget {
  const CouplerSplitterOnePage({Key? key}) : super(key: key);

  @override
  State<CouplerSplitterOnePage> createState() => _CouplerSplitterOnePageState();
}

class _CouplerSplitterOnePageState extends State<CouplerSplitterOnePage> {
  final TextEditingController _couplerCtrl = TextEditingController(text: "1.0");
  final TextEditingController _wdmCtrl = TextEditingController(text: "3.0");
  
  List<Map<String, dynamic>> _couplerResults = [];
  Map<String, List<Map<String, dynamic>>> _splitterResults = {};
  List<Map<String, double>> _wdmCouplerResults = [];
  List<Map<String, dynamic>> _wdmSplitterResults = [];

  void _onCalculate() {
    final couplerValue = double.tryParse(_couplerCtrl.text.trim());
    final wdmValue = double.tryParse(_wdmCtrl.text.trim()) ?? 3.0;

    if (couplerValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a numeric coupler value')));
      return;
    }

    final couplerCalc = CouplerCalculator(couplerValue);
    final splitterCalc = SplitterCalculator(couplerValue); // Use same value for splitter
    final wdmCalc = WDMCalculator(wdmValue: wdmValue);

    setState(() {
      _couplerResults = couplerCalc.calculateLoss();
      _splitterResults = splitterCalc.calculateLoss();
      _wdmCouplerResults = wdmCalc.calculateWDMCoupler();
      _wdmSplitterResults = wdmCalc.calculateWDMSplitter();
    });
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }

  Widget _buildCouplerSection(Map<String, dynamic> section) {
    final data = (section['data'] as List).cast<Map<String, dynamic>>();
    final sectionName = section['section'] as String;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(sectionName),
          const SizedBox(height: 12),
          ...data.map((r) {
            final leftRatio = r['ratio'].toInt();
            final rightRatio = 100 - leftRatio;
            final val1 = (r['val1'] as double).toStringAsFixed(1);
            final val2 = (r['val2'] as double).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${leftRatio.toString().padLeft(2, '0')}:${rightRatio.toString().padLeft(2, '0')} = $val1 : $val2',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: Colors.black,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSplitterSection(
      String sectionName, List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(sectionName),
          const SizedBox(height: 12),
          ...rows.map((r) {
            final split = r['split'];
            final value = (r['value'] as double).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '1x$split = $value',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: Colors.black,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWDMSection() {
    if (_wdmCouplerResults.isEmpty && _wdmSplitterResults.isEmpty) {
      return Container();
    }
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WDM Coupler section
          _buildSectionTitle('WDM (14-90)'),
          const SizedBox(height: 12),
          ..._wdmCouplerResults.map((r) {
            final leftRatio = r['ratio']!.toInt();
            final rightRatio = 100 - leftRatio;
            final val1 = r['val1']!.toStringAsFixed(1);
            final val2 = r['val2']!.toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${leftRatio.toString().padLeft(2, '0')}:${rightRatio.toString().padLeft(2, '0')} = $val1 : $val2',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: Colors.black,
                ),
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // WDM Splitter section
          ..._wdmSplitterResults.map((r) {
            final split = r['split'];
            final value = (r['value'] as double).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '1x$split = $value',
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: Colors.black,
                ),
              ),
            );
          }),
          
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Note: WDM outputs calculated using coupler reference table (1550nm only)',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coupler & Splitter Calculator'),
        backgroundColor: const Color(0xFF3B2E7D),
      ),
      body: Column(
        children: [
          // Input section
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couplerCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Coupler/Splitter Value',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _wdmCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'WDM Loss (dB)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onCalculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Calculate',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Results section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  if (_couplerResults.isNotEmpty || 
                      _splitterResults.isNotEmpty || 
                      _wdmCouplerResults.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column - LOSS-15 50
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(right: 6, bottom: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                if (_couplerResults.isNotEmpty)
                                  _buildCouplerSection(
                                      _couplerResults.firstWhere(
                                          (s) => s['section'] == 'LOSS-15 50')),
                                if (_splitterResults['LOSS-15 50'] != null)
                                  _buildSplitterSection('',
                                      _splitterResults['LOSS-15 50']!),
                              ],
                            ),
                          ),
                        ),
                        
                        // Middle column - LOSS-13 10
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                if (_couplerResults.isNotEmpty)
                                  _buildCouplerSection(
                                      _couplerResults.firstWhere(
                                          (s) => s['section'] == 'LOSS-13 10')),
                                if (_splitterResults['LOSS-13 10'] != null)
                                  _buildSplitterSection('',
                                      _splitterResults['LOSS-13 10']!),
                              ],
                            ),
                          ),
                        ),
                        
                        // Right column - WDM Calculator
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(left: 6, bottom: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: _buildWDMSection(),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
