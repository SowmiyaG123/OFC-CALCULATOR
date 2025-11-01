// lib/screens/diagram/diagram_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/rendering.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:supabase_flutter/supabase_flutter.dart';

final List<Map<String, dynamic>> couplerOptions = [
  {"type": "99/01", "dbmA": 18.35, "dbmB": 3.70},
  {"type": "98/02", "dbmA": 18.30, "dbmB": 5.50},
  {"type": "95/05", "dbmA": 18.23, "dbmB": 4.84},
  {"type": "90/10", "dbmA": 17.92, "dbmB": 7.69},
  {"type": "85/15", "dbmA": 17.77, "dbmB": 10.15},
  {"type": "80/20", "dbmA": 17.58, "dbmB": 11.17},
  {"type": "75/25", "dbmA": 17.11, "dbmB": 12.32},
  {"type": "70/30", "dbmA": 16.91, "dbmB": 13.54},
  {"type": "65/35", "dbmA": 16.67, "dbmB": 13.54},
  {"type": "60/40", "dbmA": 16.24, "dbmB": 15.28},
  {"type": "55/45", "dbmA": 15.77, "dbmB": 15.28},
  {"type": "50/50", "dbmA": 15.51, "dbmB": 15.32},
];

class DiagramNode {
  int id;
  String label;
  double signal;
  double distance;
  DiagramNode? left;
  DiagramNode? right;
  int? parentId;
  bool isCoupler;
  String? couplerType;
  String? branchLabel;
  double? dbm;

  DiagramNode({
    required this.id,
    required this.label,
    required this.signal,
    required this.distance,
    this.left,
    this.right,
    this.parentId,
    this.isCoupler = false,
    this.couplerType,
    this.branchLabel,
    this.dbm,
  });

  bool get isLeaf => left == null && right == null;
}

class OFCDiagramPage extends StatefulWidget {
  const OFCDiagramPage({super.key});
  @override
  State<OFCDiagramPage> createState() => _OFCDiagramPageState();
}

class _OFCDiagramPageState extends State<OFCDiagramPage> {
  // Repaint boundary key (used to capture the diagram)
  final GlobalKey repaintKey = GlobalKey();

  final TextEditingController headendCtrl =
      TextEditingController(text: "EDFA/PON/TR");
  final TextEditingController headendDbmCtrl =
      TextEditingController(text: "19.0");

  DiagramNode? rootNode;
  int nodeId = 0;

  String headendName = "EDFA/PON/TR";
  double headendDbm = 19.0;

  // base canvas sizes (expand as tree grows)
  double baseDiagramWidth = 1200;
  double baseDiagramHeight = 900;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    headendName = headendCtrl.text;
    headendDbm = double.tryParse(headendDbmCtrl.text) ?? 19.0;
    rootNode = DiagramNode(
      id: nodeId++,
      label: headendName,
      signal: headendDbm,
      distance: 0,
      isCoupler: false,
    );
    // Ensure our history box exists
    Hive.openBox('diagram_history');
  }

  void updateHeadend() {
    setState(() {
      headendName = headendCtrl.text.isEmpty ? "EDFA/PON/TR" : headendCtrl.text;
      headendDbm = double.tryParse(headendDbmCtrl.text) ?? 19.0;
      if (rootNode != null) {
        rootNode!.label = headendName;
        rootNode!.signal = headendDbm;
      }
    });
  }

  // show dialog to add or extend coupler on a parent node
  void _addOrExtendCoupler(DiagramNode parent) async {
    String selectedType = couplerOptions[0]["type"] as String;
    double dbmA = couplerOptions[0]["dbmA"] as double;
    double dbmB = couplerOptions[0]["dbmB"] as double;
    final TextEditingController signalCtrl =
        TextEditingController(text: parent.signal.toString());
    final TextEditingController distanceCtrl =
        TextEditingController(text: parent.distance.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${parent.isCoupler ? "Extend" : "Add Coupler"} at ${parent.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              onChanged: (val) {
                if (val == null) return;
                final sel =
                    couplerOptions.firstWhere((opt) => opt["type"] == val);
                setState(() {
                  selectedType = sel["type"] as String;
                  dbmA = sel["dbmA"] as double;
                  dbmB = sel["dbmB"] as double;
                });
              },
              items: couplerOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt["type"] as String,
                  child:
                      Text('${opt["type"]} (${opt["dbmA"]}, ${opt["dbmB"]})'),
                );
              }).toList(),
            ),
            TextField(
              controller: signalCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Input Signal (dBm)'),
            ),
            TextField(
              controller: distanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Distance (km)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final double distance = double.tryParse(distanceCtrl.text) ?? 0.0;
              setState(() {
                final double dbmLeft = dbmA;
                final double dbmRight = dbmB;

                // Always create left and right children for the selected sequence
                parent.left = DiagramNode(
                  id: nodeId++,
                  label: '${selectedType.split('/')[0]}',
                  signal: dbmLeft,
                  distance: distance,
                  parentId: parent.id,
                  isCoupler: true,
                  couplerType: selectedType,
                  branchLabel: 'A',
                  dbm: dbmLeft,
                );
                parent.right = DiagramNode(
                  id: nodeId++,
                  label: '${selectedType.split('/')[1]}',
                  signal: dbmRight,
                  distance: distance,
                  parentId: parent.id,
                  isCoupler: true,
                  couplerType: selectedType,
                  branchLabel: 'B',
                  dbm: dbmRight,
                );

                // If user set a custom input signal, update parent's signal if they changed
                final inputSignal = double.tryParse(signalCtrl.text);
                if (inputSignal != null) {
                  parent.signal = inputSignal;
                }
                parent.distance = distance;
              });
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // find node by id
  DiagramNode? _findNodeById(DiagramNode? node, int id) {
    if (node == null) return null;
    if (node.id == id) return node;
    return _findNodeById(node.left, id) ?? _findNodeById(node.right, id);
  }

  // remove a subtree by id (search parent and null the proper child)
  bool _removeNodeById(DiagramNode? current, int targetId) {
    if (current == null) return false;
    if (current.left != null && current.left!.id == targetId) {
      setState(() {
        current.left = null;
      });
      return true;
    }
    if (current.right != null && current.right!.id == targetId) {
      setState(() {
        current.right = null;
      });
      return true;
    }
    if (_removeNodeById(current.left, targetId)) return true;
    if (_removeNodeById(current.right, targetId)) return true;
    return false;
  }

  // edit coupler node data
  Future<void> _editNode(DiagramNode node) async {
    String selectedType =
        node.couplerType ?? couplerOptions[0]["type"] as String;
    double dbmA = node.dbm ?? (couplerOptions[0]["dbmA"] as double);
    double dbmB = dbmA; // will update when selection changes
    final TextEditingController distanceCtrl =
        TextEditingController(text: node.distance.toString());
    final TextEditingController signalCtrl =
        TextEditingController(text: node.signal.toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Coupler"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              onChanged: (val) {
                if (val == null) return;
                final sel =
                    couplerOptions.firstWhere((opt) => opt["type"] == val);
                setState(() {
                  selectedType = sel["type"] as String;
                  dbmA = sel["dbmA"] as double;
                  dbmB = sel["dbmB"] as double;
                });
              },
              items: couplerOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt["type"] as String,
                  child:
                      Text('${opt["type"]} (${opt["dbmA"]}, ${opt["dbmB"]})'),
                );
              }).toList(),
            ),
            TextField(
              controller: signalCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Displayed signal (dBm)'),
            ),
            TextField(
              controller: distanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Distance (km)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                node.couplerType = selectedType;
                node.dbm = double.tryParse(signalCtrl.text) ?? node.dbm;
                node.signal = node.dbm ?? node.signal;
                node.distance =
                    double.tryParse(distanceCtrl.text) ?? node.distance;
                // update children dBm if present
                if (node.left != null || node.right != null) {
                  final sel = couplerOptions
                      .firstWhere((opt) => opt["type"] == selectedType);
                  final leftDbm = sel["dbmA"] as double;
                  final rightDbm = sel["dbmB"] as double;
                  if (node.left != null) {
                    node.left!.label = selectedType.split('/')[0];
                    node.left!.dbm = leftDbm;
                    node.left!.signal = leftDbm;
                  }
                  if (node.right != null) {
                    node.right!.label = selectedType.split('/')[1];
                    node.right!.dbm = rightDbm;
                    node.right!.signal = rightDbm;
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // bottom sheet / options when tapping a block
  void _onBlockTap(int nodeId) {
    final tapped = _findNodeById(rootNode, nodeId);
    if (tapped == null) return;

    if (tapped.isLeaf) {
      _addOrExtendCoupler(tapped);
      return;
    }

    // non-leaf show options
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add/Extend at a leaf under this node'),
              onTap: () {
                Navigator.pop(context);
                DiagramNode? leaf = tapped;
                while (leaf != null && !leaf.isLeaf) {
                  leaf = leaf.left ?? leaf.right;
                }
                if (leaf != null) _addOrExtendCoupler(leaf);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit this coupler'),
              onTap: () {
                Navigator.pop(context);
                _editNode(tapped);
              },
            ),
            if (tapped.parentId != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Remove this coupler subtree',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  final removed = _removeNodeById(rootNode, tapped.id);
                  if (!removed) {
                    // was root
                    if (rootNode != null && rootNode!.id == tapped.id) {
                      setState(() {
                        rootNode = DiagramNode(
                          id: nodeId++,
                          label: headendName,
                          signal: headendDbm,
                          distance: 0,
                          isCoupler: false,
                        );
                      });
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _onHeaderTap() {
    if (rootNode != null && rootNode!.isLeaf) {
      _addOrExtendCoupler(rootNode!);
    } else {
      _onBlockTap(rootNode!.id);
    }
  }

  /// collects positions for overlay transparent hitboxes and action buttons
  List<_BlockOverlayInfo> _collectBlockPositions(DiagramNode node, double x,
      double y, double dx, double dy, double blockWidth, double blockHeight) {
    List<_BlockOverlayInfo> overlays = [];
    overlays.add(_BlockOverlayInfo(
        id: node.id,
        x: x,
        y: y,
        width: blockWidth,
        height: blockHeight,
        parentId: node.parentId,
        nodeRef: node));
    if (node.left != null) {
      overlays.addAll(_collectBlockPositions(
          node.left!, x - dx, y + dy, dx / 1.5, dy, blockWidth, blockHeight));
    }
    if (node.right != null) {
      overlays.addAll(_collectBlockPositions(
          node.right!, x + dx, y + dy, dx / 1.5, dy, blockWidth, blockHeight));
    }
    return overlays;
  }

  Future<void> saveDiagram() async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Diagram boundary not available');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image to bytes');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      String? localPath;
      Uint8List? storeBytes;

      if (kIsWeb) {
        // Web: download and store bytes in Hive so history can preview
        final blob = html.Blob([pngBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "diagram_${DateTime.now().millisecondsSinceEpoch}.png")
          ..click();
        html.Url.revokeObjectUrl(url);
        storeBytes = pngBytes;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagram downloaded (Web)')),
        );
      } else {
        // Mobile/desktop: save to Downloads or documents
        Directory targetDir;
        final possible = Directory('/storage/emulated/0/Download');
        if (await possible.exists()) {
          targetDir = possible;
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }
        final filePath =
            '${targetDir.path}/diagram_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);
        localPath = file.path;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagram saved locally')),
        );
      }

      // Attempt Supabase upload and get a public URL
      String? publicUrl;
      try {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final storagePath =
              '${user.id}/${DateTime.now().millisecondsSinceEpoch}.png';
          // try modern binary upload first
          try {
            await _supabase.storage.from('diagrams').uploadBinary(
                  storagePath,
                  pngBytes,
                  fileOptions:
                      const FileOptions(cacheControl: '3600', upsert: false),
                );
          } catch (e) {
            // fallback to writing a temp file and uploading
            final tmp =
                File('${(await getTemporaryDirectory()).path}/tmp_upload.png');
            await tmp.writeAsBytes(pngBytes);
            try {
              await _supabase.storage.from('diagrams').upload(storagePath, tmp);
            } catch (_) {
              // ignore
            }
          }

          try {
            final pubRes =
                _supabase.storage.from('diagrams').getPublicUrl(storagePath);
            if (pubRes is String) {
              publicUrl = pubRes;
            } else {
              publicUrl =
                  (pubRes as dynamic).url ?? (pubRes as dynamic).publicUrl;
            }
          } catch (_) {
            // ignore
          }
        }
      } catch (e) {
        // ignore non-fatal upload errors
      }

      // Save history to Hive
      final box = await Hive.openBox('diagram_history');
      await box.add({
        'path': localPath,
        'bytes': (kIsWeb ? storeBytes : null),
        'cloud_url': publicUrl,
        'date': DateTime.now().toIso8601String(),
      });

      final msg = publicUrl != null
          ? 'Saved locally and uploaded to cloud'
          : 'Saved locally (cloud upload not available)';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // Count nodes to estimate canvas size
  int _countNodes(DiagramNode? node) {
    if (node == null) return 0;
    return 1 + _countNodes(node.left) + _countNodes(node.right);
  }

  double maxDouble(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final double blockWidth = 140;
    final double blockHeight = 70;
    final double dx = maxDouble(160, screen.width / 8);
    final double dy = 120;
    final int nodeCount = _countNodes(rootNode);
    final int rows = (nodeCount / 4).ceil();
    final double dynamicWidth =
        maxDouble(baseDiagramWidth, screen.width * 1.4 + rows * 20);
    final double dynamicHeight = maxDouble(baseDiagramHeight, 300 + rows * dy);

    final double startX = dynamicWidth / 2 - blockWidth / 2;
    // raise header down a bit to make it visible by default
    final double startY = 80.0;
    final overlays = _collectBlockPositions(
        rootNode!, startX, startY, dx, dy, blockWidth, blockHeight);

    return Scaffold(
      appBar: AppBar(
        title: const Text("OFC Diagram Generator"),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // headend inputs
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: headendCtrl,
                        decoration:
                            const InputDecoration(labelText: "Headend Name"),
                        onChanged: (_) => updateHeadend(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: headendDbmCtrl,
                        decoration:
                            const InputDecoration(labelText: "Headend dBm"),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => updateHeadend(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // allow regenerating diagram root label update
                        setState(() {});
                      },
                      child: const Text("Update"),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                // Top-level control to add first coupler quickly
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: couplerOptions[0]["type"] as String,
                        items: couplerOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt["type"] as String,
                            child: Text('${opt["type"]}'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          // no-op here; full add flow happens via button
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Add default coupler at root if root is leaf
                        if (rootNode != null) {
                          if (rootNode!.isLeaf) {
                            _addOrExtendCoupler(rootNode!);
                          } else {
                            // add to a leaf descendant
                            DiagramNode? leaf = rootNode;
                            while (leaf != null && !leaf.isLeaf) {
                              leaf = leaf.left ?? leaf.right;
                            }
                            if (leaf != null) _addOrExtendCoupler(leaf);
                          }
                        }
                      },
                      child: const Text("Generate Diagram"),
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.3,
                maxScale: 6.0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: Container(
                        width: dynamicWidth,
                        height: dynamicHeight,
                        color: Colors.white,
                        child: Stack(
                          children: [
                            // The custom paint that draws blocks and lines
                            DiagramTreeCustomPainterWidget(
                              rootNode: rootNode!,
                              blockWidth: blockWidth,
                              blockHeight: blockHeight,
                              dx: dx,
                              dy: dy,
                              startX: startX,
                              startY: startY,
                            ),
                            // Positioned overlay buttons (these are inside the scrollable area
                            // so they move/scale with the drawing)
                            ...overlays.map((blk) {
                              return Positioned(
                                left: blk.x,
                                top: blk.y,
                                width: blk.width,
                                height: blk.height,
                                child: Stack(
                                  children: [
                                    // transparent hit area
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (blk.parentId == null) {
                                            _onHeaderTap();
                                          } else {
                                            _onBlockTap(blk.id);
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    // edit button (top-left) if not root
                                    if (blk.parentId != null)
                                      Positioned(
                                        left: -10,
                                        top: -10,
                                        child: GestureDetector(
                                          onTap: () {
                                            final node =
                                                _findNodeById(rootNode, blk.id);
                                            if (node != null) _editNode(node);
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              boxShadow: const [
                                                BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4)
                                              ],
                                            ),
                                            child: const Icon(Icons.edit,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    // delete button (top-right)
                                    if (blk.parentId != null)
                                      Positioned(
                                        right: -10,
                                        top: -10,
                                        child: GestureDetector(
                                          onTap: () {
                                            final removed = _removeNodeById(
                                                rootNode, blk.id);
                                            if (!removed) {
                                              if (rootNode != null &&
                                                  rootNode!.id == blk.id) {
                                                setState(() {
                                                  rootNode = DiagramNode(
                                                    id: nodeId++,
                                                    label: headendName,
                                                    signal: headendDbm,
                                                    distance: 0,
                                                    isCoupler: false,
                                                  );
                                                });
                                              }
                                            }
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              boxShadow: const [
                                                BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4)
                                              ],
                                            ),
                                            child: const Icon(Icons.delete,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Download Diagram"),
              onPressed: saveDiagram,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

// overlay info
class _BlockOverlayInfo {
  final int id;
  final double x, y, width, height;
  final int? parentId;
  final DiagramNode? nodeRef;
  _BlockOverlayInfo({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.parentId,
    required this.nodeRef,
  });
}

// Painter widget that starts drawing from provided startX/startY
class DiagramTreeCustomPainterWidget extends StatelessWidget {
  final DiagramNode rootNode;
  final double blockWidth, blockHeight, dx, dy;
  final double startX, startY;

  const DiagramTreeCustomPainterWidget({
    super.key,
    required this.rootNode,
    required this.blockWidth,
    required this.blockHeight,
    required this.dx,
    required this.dy,
    required this.startX,
    required this.startY,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DiagramTreePainter(
        rootNode: rootNode,
        x: startX,
        y: startY,
        dx: dx,
        dy: dy,
        blockWidth: blockWidth,
        blockHeight: blockHeight,
      ),
      child: Container(),
    );
  }
}

class DiagramTreePainter extends CustomPainter {
  final DiagramNode rootNode;
  final double x, y, dx, dy, blockWidth, blockHeight;

  DiagramTreePainter({
    required this.rootNode,
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.blockWidth,
    required this.blockHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBlockWithLines(canvas, rootNode, x, y, dx, dy);
  }

  /// Draws the node, returns the top-center offset of the block (used by parent)
  Offset _drawBlockWithLines(Canvas canvas, DiagramNode node, double x,
      double y, double dx, double dy) {
    // draw children first to compute their centers
    Offset? leftCenter;
    Offset? rightCenter;
    if (node.left != null) {
      leftCenter =
          _drawBlockWithLines(canvas, node.left!, x - dx, y + dy, dx / 1.5, dy);
    }
    if (node.right != null) {
      rightCenter = _drawBlockWithLines(
          canvas, node.right!, x + dx, y + dy, dx / 1.5, dy);
    }

    // draw connections in a non-inverted-V style:
    // - from bottom-center of current node draw a vertical line down to junction
    // - from junction draw horizontal lines to each child's top-center
    Rect rect = Rect.fromLTWH(x, y, blockWidth, blockHeight);
    final Offset myCenterTop = Offset(x + blockWidth / 2, y);
    final Offset myCenterBottom = Offset(x + blockWidth / 2, y + blockHeight);

    if (leftCenter != null || rightCenter != null) {
      final double junctionY = y + blockHeight + 20;
      final Offset junction = Offset(myCenterBottom.dx, junctionY);

      // vertical line
      canvas.drawLine(
        myCenterBottom,
        junction,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 2,
      );

      // horizontal to left
      if (leftCenter != null) {
        final Offset leftTop = Offset(leftCenter.dx, leftCenter.dy);
        final Offset leftMid = Offset(leftTop.dx, junctionY);
        canvas.drawLine(
            junction,
            leftMid,
            Paint()
              ..color = Colors.black
              ..strokeWidth = 2);
        canvas.drawLine(
            leftMid,
            leftTop,
            Paint()
              ..color = Colors.black
              ..strokeWidth = 2);

        // draw distance / dbm near horizontal line (midpoint)
        final Offset labelPos =
            Offset((junction.dx + leftMid.dx) / 2, junctionY - 10);
        _drawSmallLabel(canvas, '${node.left!.distance} km', labelPos);
        // dbm on the other side
        final Offset dbmPos =
            Offset((junction.dx + leftMid.dx) / 2, junctionY + 2);
        _drawSmallLabel(
            canvas, '${node.left!.signal.toStringAsFixed(2)} dBm', dbmPos);
      }

      // horizontal to right
      if (rightCenter != null) {
        final Offset rightTop = Offset(rightCenter.dx, rightCenter.dy);
        final Offset rightMid = Offset(rightTop.dx, junctionY);
        canvas.drawLine(
            junction,
            rightMid,
            Paint()
              ..color = Colors.black
              ..strokeWidth = 2);
        canvas.drawLine(
            rightMid,
            rightTop,
            Paint()
              ..color = Colors.black
              ..strokeWidth = 2);

        final Offset labelPos =
            Offset((junction.dx + rightMid.dx) / 2, junctionY - 10);
        _drawSmallLabel(canvas, '${node.right!.distance} km', labelPos);
        final Offset dbmPos =
            Offset((junction.dx + rightMid.dx) / 2, junctionY + 2);
        _drawSmallLabel(
            canvas, '${node.right!.signal.toStringAsFixed(2)} dBm', dbmPos);
      }
    }

    // draw block rectangle
    Paint blockPaint = Paint()
      ..color = (node.parentId == null)
          ? Colors.green
          : (node.branchLabel == 'A'
              ? const Color(0xFF0B6EFD) // impressive blue for A
              : const Color(0xFF00BFA6)); // awesome teal for B
    RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rrect, blockPaint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // label inside block
    final textPainter = _textPainter(
        "${node.label}${node.signal != 0 ? "\n${node.signal.toStringAsFixed(2)} dBm" : ""}",
        node.parentId == null ? 16 : 14,
        Colors.white,
        maxWidth: blockWidth - 8);
    textPainter.paint(
        canvas,
        Offset(x + (blockWidth - textPainter.width) / 2,
            y + (blockHeight - textPainter.height) / 2));

    // return top-center of this block (so parent can connect to it)
    return Offset(x + blockWidth / 2, y);
  }

  void _drawSmallLabel(Canvas canvas, String label, Offset pos) {
    final span = TextSpan(
      text: label,
      style: const TextStyle(fontSize: 11, color: Colors.black),
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  TextPainter _textPainter(String text, double fontSize, Color color,
      {double maxWidth = 200}) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
          fontSize: fontSize, color: color, fontWeight: FontWeight.bold),
    );
    final painter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    return painter;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
