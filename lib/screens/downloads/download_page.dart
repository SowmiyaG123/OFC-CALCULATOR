import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../diagram/diagram_page.dart';
import 'dart:typed_data';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({Key? key}) : super(key: key);

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<Box> _boxFuture;
  Future<void> _clearLegacyDiagrams() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.cleaning_services, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Clear Legacy Diagrams?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'This will remove all diagrams saved with older versions. '
          'You can re-save them to enable preview.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear Legacy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final box = await _ensureBoxOpen();
      final keysToDelete = <int>[];

      for (var i = 0; i < box.length; i++) {
        final data = box.getAt(i);
        if (data is Map && data['isLegacy'] == true) {
          keysToDelete.add(i);
        }
      }

      // Delete in reverse order to maintain indices
      for (var i in keysToDelete.reversed) {
        await box.deleteAt(i);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Removed ${keysToDelete.length} legacy diagrams'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initBox();
  }

  void _initBox() {
    _boxFuture = _ensureBoxOpen();
  }

  void _reEditDiagram(Map data) {
    // ✅ Ensure WDM data is properly passed
    final enhancedData = {
      ...data,
      // Ensure these fields exist
      'useWdm': data['useWdm'] ?? false,
      'wdmPower': data['wdmPower'] ?? 0.0,
      'wdmLoss': data['wdmLoss'] ?? 0.0,
    };

    print(
        '📋 Re-editing with WDM: ${enhancedData['useWdm']}, Power: ${enhancedData['wdmPower']}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OFCDiagramPage(savedData: enhancedData),
      ),
    );
  }

  Future<Box> _ensureBoxOpen() async {
    Box box;
    if (Hive.isBoxOpen('diagram_downloads')) {
      box = Hive.box('diagram_downloads');
    } else {
      box = await Hive.openBox('diagram_downloads');
    }

    // ✅ MIGRATION: Mark old records as legacy
    for (var i = 0; i < box.length; i++) {
      final data = box.getAt(i);
      if (data is Map && !data.containsKey('imageBytes')) {
        // Mark as legacy for UI handling
        final updatedData = Map.from(data);
        updatedData['isLegacy'] = true;
        await box.putAt(i, updatedData);
      }
    }

    return box;
  }

  Future<void> _deleteItem(Box box, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Delete diagram?', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('This action cannot be undone.'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await box.deleteAt(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Diagram deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _shareImage(String? localPath, String? cloudUrl) async {
    try {
      if (!kIsWeb && localPath != null && await File(localPath).exists()) {
        await Share.shareXFiles([XFile(localPath)], text: 'OFC Diagram');
      } else if (cloudUrl != null) {
        await Share.share(cloudUrl, subject: 'OFC Diagram');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to share: File not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _showFullImage(
    BuildContext context,
    Map data, // ✅ CHANGED: Pass entire data map
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildFullPreview(data), // ✅ Use new method
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPreview(Map data) {
    // ✅ Check for legacy data first
    if (data['isLegacy'] == true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.update,
                size: 80,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 24),
              const Text(
                'Legacy Diagram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This diagram was saved with an older version.\nRe-edit and save again to enable preview.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ✅ 1. MEMORY IMAGE (BEST – works everywhere)
    if (data['imageBytes'] != null) {
      try {
        return Image.memory(
          Uint8List.fromList(List<int>.from(data['imageBytes'])),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            print('❌ Memory image error: $error');
            return const _DialogPlaceholder(
              icon: Icons.broken_image,
              text: 'Failed to load image',
            );
          },
        );
      } catch (e) {
        print('❌ Memory conversion error: $e');
      }
    }

    // ✅ 2. MOBILE / DESKTOP FILE (fallback)
    if (!kIsWeb && data['path'] != null) {
      final file = File(data['path']);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            print('❌ File image error: $error');
            return const _DialogPlaceholder(
              icon: Icons.broken_image,
              text: 'Failed to load file',
            );
          },
        );
      }
    }

    // ✅ 3. Cloud URL (final fallback)
    if (data['cloudUrl'] != null) {
      return Image.network(
        data['cloudUrl'],
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stack) {
          print('❌ Network image error: $error');
          return const _DialogPlaceholder(
            icon: Icons.cloud_off,
            text: 'Failed to load from cloud',
          );
        },
      );
    }

    // ❌ No image data available
    return const _DialogPlaceholder(
      icon: Icons.image_not_supported,
      text: 'Image data missing - Re-save diagram',
    );
  }

  Widget _buildFallbackPreview(String? cloudUrl) {
    if (cloudUrl != null) {
      return Image.network(
        cloudUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stack) {
          return const _DialogPlaceholder(
            icon: Icons.cloud_off,
            text: 'Failed to load image',
          );
        },
      );
    }

    return const _DialogPlaceholder(
      icon: Icons.image_not_supported,
      text: 'Preview not available',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Downloads',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              'Saved OFC diagrams',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Box>(
        future: _boxFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorSection(
              error: snapshot.error.toString(),
              onRetry: () => setState(_initBox),
            );
          }

          final box = snapshot.data!;

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box box, _) {
              if (box.isEmpty) {
                return _EmptyDownloads(isDark: isDark);
              }

              final items = box.values.toList().reversed.toList();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final data = items[index] as Map;
                  final String? localPath = data['path'];
                  final String? thumbnailPath = data['thumbnailPath'];
                  final String? cloudUrl = data['cloudUrl'];
                  final String dateStr = data['date'] ?? '';
                  final String name = data['name'] ?? 'Diagram';

                  // ✅ DEBUG: Log available paths
                  print('📦 Item $index:');
                  print('  Name: ${data['name']}');
                  print('  IsLegacy: ${data['isLegacy']}');
                  print('  HasImageBytes: ${data.containsKey('imageBytes')}');
                  print(
                      '  HasThumbnailBytes: ${data.containsKey('thumbnailBytes')}');
                  print('  Local: ${data['path']}');
                  print('  Cloud: ${data['cloudUrl']}');
                  DateTime date;
                  try {
                    date = DateTime.parse(dateStr);
                  } catch (_) {
                    date = DateTime.now();
                  }

                  final actualIndex = box.length - 1 - index;

                  return _DiagramCard(
                    name: name,
                    date: date,
                    localPath: localPath,
                    thumbnailPath: thumbnailPath,
                    cloudUrl: cloudUrl,
                    isDark: isDark,
                    data: data, // ✅ ADD THIS LINE
                    onTapPreview: () =>
                        _showFullImage(context, data), // ✅ Pass data
                    onShare: () => _shareImage(localPath, cloudUrl),
                    onReEdit: () => _reEditDiagram(data),
                    onDelete: () => _deleteItem(box, actualIndex),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DiagramCard extends StatelessWidget {
  final String name;
  final DateTime date;
  final String? localPath;
  final String? thumbnailPath; // ✅ ADD THIS
  final String? cloudUrl;
  final bool isDark;
  final VoidCallback onTapPreview;
  final VoidCallback onShare;
  final VoidCallback onReEdit;
  final VoidCallback onDelete;
  final Map? data;

  const _DiagramCard({
    Key? key,
    required this.name,
    required this.date,
    required this.localPath,
    this.thumbnailPath, // ✅ ADD THIS
    required this.cloudUrl,
    required this.isDark,
    required this.onTapPreview,
    required this.onShare,
    required this.onReEdit,
    required this.onDelete,
    this.data, // ✅ ADD THIS
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseCardColor = isDark ? const Color(0xFF020617) : Colors.white;

    return Material(
      color: baseCardColor,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildThumbnail(context, data),
              ),
            ),
            // details
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.length > 22 ? '${name.substring(0, 22)}…' : name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (cloudUrl != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.green.withOpacity(0.15)
                                : Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_done,
                                  size: 12, color: Colors.green[700]),
                              const SizedBox(width: 3),
                              Text(
                                'Synced',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      // share icon removed, inline actions instead
                      TextButton.icon(
                        onPressed: onReEdit,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.edit,
                            size: 16,
                            color:
                                isDark ? Colors.blue[300] : Colors.blue[700]),
                        label: Text(
                          'Re-edit',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.delete,
                            size: 16,
                            color: isDark ? Colors.red[300] : Colors.red),
                        label: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.red[300] : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, Map? data) {
    final placeholder = Container(
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: isDark ? Colors.grey[400] : Colors.grey[500],
      ),
    );

    // ✅ Show legacy indicator
    if (data != null && data['isLegacy'] == true) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
            child: Icon(
              Icons.update,
              size: 40,
              color: Colors.orange.shade400,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Legacy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    // ✅ 1. THUMBNAIL BYTES (BEST for grid)
    if (data != null && data['thumbnailBytes'] != null) {
      try {
        return Image.memory(
          Uint8List.fromList(List<int>.from(data['thumbnailBytes'])),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            print('❌ Thumbnail bytes error: $error');
            // Try full image bytes as fallback
            if (data['imageBytes'] != null) {
              try {
                return Image.memory(
                  Uint8List.fromList(List<int>.from(data['imageBytes'])),
                  fit: BoxFit.cover,
                );
              } catch (e) {
                print('❌ Full image bytes fallback error: $e');
              }
            }
            return placeholder;
          },
        );
      } catch (e) {
        print('❌ Thumbnail conversion error: $e');
      }
    }

    // ✅ 2. FULL IMAGE BYTES (fallback)
    if (data != null && data['imageBytes'] != null) {
      try {
        return Image.memory(
          Uint8List.fromList(List<int>.from(data['imageBytes'])),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      } catch (e) {
        print('❌ Image bytes conversion error: $e');
      }
    }

    // ✅ 3. MOBILE/DESKTOP FILE (old method)
    if (!kIsWeb && thumbnailPath != null) {
      final thumbFile = File(thumbnailPath!);
      if (thumbFile.existsSync()) {
        return Image.file(
          thumbFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      }
    }

    if (!kIsWeb && localPath != null) {
      final fullFile = File(localPath!);
      if (fullFile.existsSync()) {
        return Image.file(
          fullFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        );
      }
    }

    // ✅ 4. Cloud URL (final fallback)
    if (cloudUrl != null) {
      return Image.network(
        cloudUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    print('⚠️ No valid image source found');
    return placeholder;
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color? textColor;

  const _MenuItemRow({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultColor =
        textColor ?? Theme.of(context).textTheme.bodyMedium?.color;
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(color: defaultColor, fontSize: 14),
        ),
      ],
    );
  }
}

class _DialogPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DialogPlaceholder({
    Key? key,
    required this.icon,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  final bool isDark;

  const _EmptyDownloads({Key? key, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorMuted = isDark ? Colors.grey[400] : Colors.grey[600];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 90,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 18),
            Text(
              'No diagrams yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create and save OFC diagrams to see them listed here.',
              style: TextStyle(
                fontSize: 14,
                color: colorMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorSection({
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 60, color: isDark ? Colors.red[300] : Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
