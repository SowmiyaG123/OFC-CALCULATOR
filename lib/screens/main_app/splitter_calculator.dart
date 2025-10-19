import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/calculator_button.dart';

class SplitterCalculatorPage extends StatefulWidget {
  const SplitterCalculatorPage({Key? key}) : super(key: key);

  @override
  State<SplitterCalculatorPage> createState() => _SplitterCalculatorPageState();
}

class _SplitterCalculatorPageState extends State<SplitterCalculatorPage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _result = {};

  // Fixed ratio pairs for display
  final List<Map<String, int>> ratioPairs = [
    {'first': 5, 'second': 95},
    {'first': 10, 'second': 90},
    {'first': 15, 'second': 85},
    {'first': 20, 'second': 80},
    {'first': 25, 'second': 75},
    {'first': 30, 'second': 70},
    {'first': 35, 'second': 65},
    {'first': 40, 'second': 60},
    {'first': 45, 'second': 55},
    {'first': 50, 'second': 50},
  ];

  void _calculate() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null) return;
    final calc = SplitterCalculator(value);
    setState(() {
      _result = calc.calculateLoss();
    });
  }

  // Helper method to style text based on value
  Widget _buildValueText(double value) {
    return Text(
      value.toStringAsFixed(1),
      style: TextStyle(
        color: value < 0 ? Colors.red : Colors.black,
        fontWeight: value < 0 ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Splitter Loss Calculator"),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter Splitter Value",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: const Icon(Icons.calculate),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Calculate",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _result.isEmpty
                  ? const Center(
                      child: Text(
                        "Enter a value and press Calculate",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: _result.entries.map((entry) {
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const Divider(),
                                ...entry.value.asMap().entries.map((entryMap) {
                                  int i = entryMap.key;
                                  var data = entryMap.value;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${ratioPairs[i]['first'].toString().padLeft(2, '0')}:${ratioPairs[i]['second'].toString().padLeft(2, '0')}",
                                        ),
                                        _buildValueText(data['value']),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplitterCalculator {
  final double splitterValue;
  SplitterCalculator(this.splitterValue);

  final List<int> splits = [2, 4, 8, 16, 32, 64];

  Map<String, List<Map<String, dynamic>>> calculateLoss() {
    Map<String, List<Map<String, dynamic>>> result = {};

    final base15 = [-2.6, -5.8, -9, -12, -15, -18.5];
    final base13 = [-2.0, -5.4, -8.9, -12.2, -15.4, -18.4];

    double adjust = splitterValue - 1.0;

    result["LOSS-15 50"] = List.generate(splits.length,
        (i) => {'split': splits[i], 'value': base15[i] + adjust});

    result["LOSS-13 10"] = List.generate(splits.length,
        (i) => {'split': splits[i], 'value': base13[i] + adjust});

    return result;
  }
}
