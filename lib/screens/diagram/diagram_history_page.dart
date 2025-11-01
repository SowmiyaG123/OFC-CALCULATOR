import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DiagramHistoryPage extends StatefulWidget {
  const DiagramHistoryPage({Key? key}) : super(key: key);

  @override
  State<DiagramHistoryPage> createState() => _DiagramHistoryPageState();
}

class _DiagramHistoryPageState extends State<DiagramHistoryPage> {
  late Future<Box> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = Hive.openBox('diagram_history');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Downloaded Diagrams"),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Box>(
        future: _boxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final box = snapshot.data!;

          if (box.isEmpty) {
            return const Center(
              child: Text(
                'No diagrams saved yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: box.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final data = box.getAt(index);
              final String? localPath = data['path'];
              final String? cloudUrl = data['cloud_url'];
              final String date = data['date'];

              return GestureDetector(
                onTap: () {
                  if (!kIsWeb && localPath != null) {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          color: Colors.black,
                          child: Image.file(
                            File(localPath),
                            errorBuilder: (context, error, stack) {
                              return const Center(
                                  child: Icon(Icons.broken_image, size: 40));
                            },
                          ),
                        ),
                      ),
                    );
                  } else if (cloudUrl != null) {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          color: Colors.black,
                          child: Image.network(
                            cloudUrl,
                            errorBuilder: (context, error, stack) {
                              return const Center(
                                  child: Icon(Icons.broken_image, size: 40));
                            },
                          ),
                        ),
                      ),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text("Preview not available"),
                        content: Text(
                            "File previews work only on mobile or desktop."),
                      ),
                    );
                  }
                },
                child: Card(
                  elevation: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: (localPath != null && !kIsWeb)
                            ? Image.file(
                                File(localPath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stack) {
                                  return const Center(
                                      child:
                                          Icon(Icons.broken_image, size: 40));
                                },
                              )
                            : (cloudUrl != null)
                                ? Image.network(
                                    cloudUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stack) {
                                      return const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 40));
                                    },
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Text(
                                        "Preview not available\non Web",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                    ),
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          DateTime.parse(date).toLocal().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
