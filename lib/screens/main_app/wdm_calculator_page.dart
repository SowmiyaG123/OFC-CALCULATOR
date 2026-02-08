import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------- WDM Calculator ----------------
class WDMCalculator {
  final double wdmValue;

  WDMCalculator({required this.wdmValue});

  List<Map<String, double>> calculateWDMCoupler() {
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

  List<Map<String, dynamic>> calculateWDMSplitter() {
    final List<int> splits = [2, 4, 8, 16, 32, 64];
    final baseValues = [-3.0, -6.4, -9.9, -13.2, -16.4, -19.4];
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
  final TextEditingController _couplerCtrl = TextEditingController(text: "0.0");
  final TextEditingController _wdmCtrl = TextEditingController(text: "0.0");

  List<Map<String, dynamic>> _couplerResults = [];
  Map<String, List<Map<String, dynamic>>> _splitterResults = {};
  List<Map<String, double>> _wdmCouplerResults = [];
  List<Map<String, dynamic>> _wdmSplitterResults = [];

  // Color palette
  final Color _primaryColor = const Color(0xFF047857); // teal green
  final Color _secondaryColor = const Color(0xFF22A6F2); // blue
  final Color _accentColor = const Color(0xFF2C74B3);
  final Color _successColor = const Color(0xFF10B981);
  final Color _cardBg = const Color(0xFFF8FAFC);
  final Color _textPrimary = const Color(0xFF1E293B);
  final Color _textSecondary = const Color(0xFF64748B);

  // In CouplerSplitterOnePage (_CouplerSplitterOnePageState class)
// Replace _onCalculate method:

  void _onCalculate() {
    final couplerValue = double.tryParse(_couplerCtrl.text.trim());
    final wdmValue = double.tryParse(_wdmCtrl.text.trim()) ?? 0.0;

    if (couplerValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid coupler value'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final couplerCalc = CouplerCalculator(couplerValue);
    final splitterCalc = SplitterCalculator(couplerValue);

    setState(() {
      _couplerResults = couplerCalc.calculateLoss();
      _splitterResults = splitterCalc.calculateLoss();

      // ✅ ALWAYS calculate WDM - even for 0.0
      final wdmCalc = WDMCalculator(wdmValue: wdmValue);
      _wdmCouplerResults = wdmCalc.calculateWDMCoupler();
      _wdmSplitterResults = wdmCalc.calculateWDMSplitter();
    });
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.95),
            color.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.table_chart_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, bool isHeader) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey.shade50 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isHeader ? 14 : 13,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                color: isHeader ? _textPrimary : _textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isHeader
                  ? _accentColor.withOpacity(0.1)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHeader
                    ? _accentColor.withOpacity(0.3)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isHeader ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: isHeader ? _accentColor : _textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional Calculator',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FTTH Coupler, Splitter & WDM Calculations',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coupler/Splitter Value',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _couplerCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'Enter value (e.g., 1.0, 2.0, 10.0)',
                          hintStyle: GoogleFonts.poppins(
                            color: _textSecondary,
                          ),
                          prefixIcon: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF2C74B3),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _accentColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WDM Loss (dB)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _wdmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: _textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          hintText: 'Enter WDM loss value',
                          hintStyle: GoogleFonts.poppins(
                            color: _textSecondary,
                          ),
                          prefixIcon: const Icon(
                            Icons.settings_input_component,
                            color: Color(0xFF2C74B3),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _accentColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onCalculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _successColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calculate_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Calculate Results',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_couplerResults.isEmpty && _wdmCouplerResults.isEmpty) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Calculation Results',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Professional fiber optics loss calculations',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Results Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: LOSS-15 50
                if (_couplerResults.isNotEmpty)
                  Container(
                    width: 320,
                    margin: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          'LOSS-15 50 (1550nm)',
                          const Color(0xFF6366F1),
                        ),
                        _buildDataRow('Split Ratio', 'Loss (dB)', true),
                        ..._buildCouplerRows(_couplerResults
                            .firstWhere((s) => s['section'] == 'LOSS-15 50')),
                        const SizedBox(height: 16),
                        _buildDataRow('Split Configuration', 'Loss (dB)', true),
                        ..._buildSplitterRows(
                            _splitterResults['LOSS-15 50'] ?? []),
                      ],
                    ),
                  ),

                // Column 2: LOSS-13 10
                if (_couplerResults.isNotEmpty)
                  Container(
                    width: 320,
                    margin: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          'LOSS-13 10 (1310nm)',
                          const Color(0xFF0EA5E9),
                        ),
                        _buildDataRow('Split Ratio', 'Loss (dB)', true),
                        ..._buildCouplerRows(_couplerResults
                            .firstWhere((s) => s['section'] == 'LOSS-13 10')),
                        const SizedBox(height: 16),
                        _buildDataRow('Split Configuration', 'Loss (dB)', true),
                        ..._buildSplitterRows(
                            _splitterResults['LOSS-13 10'] ?? []),
                      ],
                    ),
                  ),

                // Column 3: WDM Results
                if (_wdmCouplerResults.isNotEmpty)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 233, 121, 241)
                              .withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          'WDM (14-90) Results',
                          const Color(0xFF8B5CF6),
                        ),
                        _buildDataRow('WDM Split Ratio', 'Loss (dB)', true),
                        ..._buildWDMCouplerRows(),
                        if (_wdmSplitterResults.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDataRow('WDM Splitter', 'Loss (dB)', true),
                          ..._buildWDMSplitterRows(),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildCouplerRows(Map<String, dynamic> section) {
    final data = (section['data'] as List).cast<Map<String, dynamic>>();
    return data.map((r) {
      final leftRatio = r['ratio'].toInt();
      final rightRatio = 100 - leftRatio;
      final val1 = (r['val1'] as double).toStringAsFixed(1);
      final val2 = (r['val2'] as double).toStringAsFixed(1);

      return _buildDataRow(
        '${leftRatio.toString().padLeft(2, '0')}:${rightRatio.toString().padLeft(2, '0')}',
        '$val1 : $val2',
        false,
      );
    }).toList();
  }

  List<Widget> _buildSplitterRows(List<Map<String, dynamic>> rows) {
    return rows.map((r) {
      final split = r['split'];
      final value = (r['value'] as double).toStringAsFixed(1);
      return _buildDataRow('1x$split', '$value dB', false);
    }).toList();
  }

  List<Widget> _buildWDMCouplerRows() {
    if (_wdmCouplerResults.isEmpty) {
      return [
        _buildDataRow('No data', '-', false),
      ];
    }

    return _wdmCouplerResults.map((r) {
      final leftRatio = r['ratio']!.toInt();
      final rightRatio = 100 - leftRatio;
      final val1 = r['val1']!.toStringAsFixed(1);
      final val2 = r['val2']!.toStringAsFixed(1);

      return _buildDataRow(
        '${leftRatio.toString().padLeft(2, '0')}:${rightRatio.toString().padLeft(2, '0')}',
        '$val1 : $val2',
        false,
      );
    }).toList();
  }

  List<Widget> _buildWDMSplitterRows() {
    if (_wdmSplitterResults.isEmpty) {
      return [
        _buildDataRow('No data', '-', false),
      ];
    }

    return _wdmSplitterResults.map((r) {
      final split = r['split'];
      final value = (r['value'] as double).toStringAsFixed(1);
      return _buildDataRow('1x$split', '$value dB', false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        // new gradient colour and white back icon
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.calculate_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'FTTH Professional Calculator',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildCalculatorCard(),
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }
}
