import 'package:flutter/material.dart';

// -------------------- CouplerCalculator (inlined) --------------------
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

// -------------------- SplitterCalculator (with both loss tables) --------------------
class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};

    final loss1550 = [-3.6, -6.8, -10.0, -13.0, -16.0, -19.5];
    final loss1310 = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];

    final adjust = splitterValue;

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

// -------------------- WDM Calculator --------------------
class WDMCalculator {
  final double wdmInputPower;
  final int ratio;

  WDMCalculator(this.wdmInputPower, this.ratio);

  Map<String, dynamic> calculateWDMLoss() {
    // FIXED: Use wdmInputPower (the WDM Loss value from input)
    final calculator = CouplerCalculator(wdmInputPower);
    final calculatedData = calculator.calculateLoss();

    // Get 1550nm section (WDM is 1550nm only)
    final section = 'LOSS-15 50';
    final sectionData = calculatedData.firstWhere(
      (s) => s['section'] == section,
      orElse: () => calculatedData[0],
    );

    final dataList = (sectionData['data'] as List).cast<Map<String, dynamic>>();
    final entry = dataList.firstWhere(
      (e) => e['ratio'] == ratio,
      orElse: () => dataList.first,
    );

    // These are OUTPUT POWERS from the reference table
    final wdmOutput1 = (entry['val1'] as num).toDouble();
    final wdmOutput2 = (entry['val2'] as num).toDouble();

    // Calculate losses as input - output
    final wdmLoss1 = wdmInputPower - wdmOutput1;
    final wdmLoss2 = wdmInputPower - wdmOutput2;

    return {
      'ratio': ratio,
      'wdmOutput1': wdmOutput1,
      'wdmOutput2': wdmOutput2,
      'wdmLoss1': wdmLoss1,
      'wdmLoss2': wdmLoss2,
      'inputPower': wdmInputPower,
    };
  }
}

// -------------------- Main Widget: CouplerSplitterOnePage --------------------
class CouplerSplitterOnePage extends StatefulWidget {
  const CouplerSplitterOnePage({Key? key}) : super(key: key);

  @override
  State<CouplerSplitterOnePage> createState() => _CouplerSplitterOnePageState();
}

class _CouplerSplitterOnePageState extends State<CouplerSplitterOnePage> {
  final TextEditingController _inputCtrl = TextEditingController(text: "1.0");
  final TextEditingController _wdmInputCtrl =
      TextEditingController(text: "3.0");
  int _selectedRatio = 50;

  List<Map<String, dynamic>> _couplerResults = [];
  Map<String, List<Map<String, dynamic>>> _splitterResults = {};
  Map<String, dynamic>? _wdmResult;

  final List<int> _ratios = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50];

  void _onCalculate() {
    final v = double.tryParse(_inputCtrl.text.trim());
    final wdmValue = double.tryParse(_wdmInputCtrl.text.trim());

    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a numeric value for Coupler/Splitter')));
      return;
    }

    final couplerCalc = CouplerCalculator(v);
    final splitterCalc = SplitterCalculator(v);

    // Calculate WDM if value is provided - NOW USING CORRECT LOGIC
    if (wdmValue != null && wdmValue > 0) {
      final wdmCalc = WDMCalculator(wdmValue, _selectedRatio);
      _wdmResult = wdmCalc.calculateWDMLoss();
    } else {
      _wdmResult = null;
    }

    setState(() {
      _couplerResults = couplerCalc.calculateLoss();
      _splitterResults = splitterCalc.calculateLoss();
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
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(sectionName),
          const SizedBox(height: 12),
          ...data.map((r) {
            final leftRatio = r['ratio'].toInt();
            final rightRatio = 100 - leftRatio;
            final val1 = (r['val1'] as double);
            final val2 = (r['val2'] as double);

            // Format values with proper padding
            final val1Str = val1.toStringAsFixed(1).padLeft(6);
            final val2Str = val2.toStringAsFixed(1).padLeft(6);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${leftRatio.toString().padLeft(2, '0')}:${rightRatio.toString().padLeft(2, '0')} = $val1Str : $val2Str',
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Courier',
                  height: 1.6,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
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
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWDMSection() {
    if (_wdmResult == null) return const SizedBox();

    final ratio = _wdmResult!['ratio'];
    final wdmOut1 = _wdmResult!['wdmOutput1'];
    final wdmOut2 = _wdmResult!['wdmOutput2'];
    final wdmLoss1 = _wdmResult!['wdmLoss1'];
    final wdmLoss2 = _wdmResult!['wdmLoss2'];
    final inputPower = _wdmResult!['inputPower'];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('WDM (14-90) Loss Calculation'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Input WDM Power: ${inputPower.toStringAsFixed(1)} dBm',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'For Ratio ${ratio.toString().padLeft(2)}:${(100 - ratio).toString().padLeft(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Output 1 Power: ${wdmOut1.toStringAsFixed(2)} dBm',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Output 1 Loss: ${wdmLoss1.toStringAsFixed(2)} dB',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Output 2 Power: ${wdmOut2.toStringAsFixed(2)} dBm',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Output 2 Loss: ${wdmLoss2.toStringAsFixed(2)} dB',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Note: WDM outputs calculated using coupler reference table (1550nm only)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontStyle: FontStyle.italic,
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
        backgroundColor: const Color.fromARGB(255, 177, 242, 93),
      ),
      body: Column(
        children: [
          // Input section with WDM
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
                          controller: _inputCtrl,
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
                          controller: _wdmInputCtrl,
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
                  Row(
                    children: [
                      const Text(
                        'Select Ratio:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedRatio,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: _ratios.map((ratio) {
                            return DropdownMenuItem<int>(
                              value: ratio,
                              child: Text('$ratio:${100 - ratio}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRatio = value!;
                            });
                          },
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
                        'Calculate All',
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
          // Results section - 5 boxes (2 coupler, 2 splitter, 1 WDM)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  if (_couplerResults.isNotEmpty ||
                      _splitterResults.isNotEmpty ||
                      _wdmResult != null) ...[
                    // Row 1: Coupler LOSS-15 50 and LOSS-13 10
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(right: 6, bottom: 12),
                            child: _couplerResults.isNotEmpty
                                ? _buildCouplerSection(
                                    _couplerResults.firstWhere(
                                        (s) => s['section'] == 'LOSS-15 50'))
                                : const SizedBox(),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(left: 6, bottom: 12),
                            child: _couplerResults.isNotEmpty
                                ? _buildCouplerSection(
                                    _couplerResults.firstWhere(
                                        (s) => s['section'] == 'LOSS-13 10'))
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                    // Row 2: Splitter LOSS-15 50 and LOSS-13 10
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(right: 6, bottom: 12),
                            child: _splitterResults['LOSS-15 50'] != null
                                ? _buildSplitterSection('LOSS-15 50',
                                    _splitterResults['LOSS-15 50']!)
                                : const SizedBox(),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(left: 6, bottom: 12),
                            child: _splitterResults['LOSS-13 10'] != null
                                ? _buildSplitterSection('LOSS-13 10',
                                    _splitterResults['LOSS-13 10']!)
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                    // Row 3: WDM Calculation
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildWDMSection(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- WDM Calculator Page (Wrapper Widget) --------------------
// This is the widget that should be called from your dashboard
class WDMCalculatorPage extends StatefulWidget {
  const WDMCalculatorPage({Key? key}) : super(key: key);

  @override
  State<WDMCalculatorPage> createState() => _WDMCalculatorPageState();
}

class _WDMCalculatorPageState extends State<WDMCalculatorPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WDM Calculator'),
        backgroundColor: const Color(0xFF7B2CBF), // Purple color for WDM
      ),
      body: const CouplerSplitterOnePage(), // Uses the same calculator
    );
  }
}
