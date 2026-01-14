import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../diagram/diagram_page.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({Key? key}) : super(key: key);

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<Box> _boxFuture;

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
    if (Hive.isBoxOpen('diagram_downloads')) {
      return Hive.box('diagram_downloads');
    } else {
      return await Hive.openBox('diagram_downloads');
    }
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
    String? localPath,
    String? cloudUrl,
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
                  child: Builder(
                    builder: (context) {
                      // ✅ WEB: Use network image
                      if (kIsWeb) {
                        if (cloudUrl != null) {
                          return Image.network(
                            cloudUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) {
                              print('❌ Web full image error: $error');
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

                      // ✅ MOBILE/DESKTOP: Use local file
                      if (localPath != null) {
                        final fullFile = File(localPath);
                        if (fullFile.existsSync()) {
                          return Image.file(
                            fullFile,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) {
                              print('❌ Full image error: $error');
                              print('File path: $localPath');
                              print('File exists: ${fullFile.existsSync()}');
                              print(
                                  'File size: ${fullFile.lengthSync()} bytes');

                              // Try cloud URL as fallback
                              if (cloudUrl != null) {
                                return Image.network(
                                  cloudUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return const _DialogPlaceholder(
                                      icon: Icons.broken_image,
                                      text: 'Failed to load image',
                                    );
                                  },
                                );
                              }

                              return const _DialogPlaceholder(
                                icon: Icons.broken_image,
                                text: 'Image not found',
                              );
                            },
                          );
                        } else {
                          print('❌ File does not exist: $localPath');
                        }
                      }

                      // ✅ Fallback to cloud URL
                      if (cloudUrl != null) {
                        return Image.network(
                          cloudUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) {
                            print('❌ Cloud fallback error: $error');
                            return const _DialogPlaceholder(
                              icon: Icons.cloud_off,
                              text: 'Failed to load',
                            );
                          },
                        );
                      }

                      return const Center(
                        child: Text(
                          'Preview not available',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    },
                  ),
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
                  print('  Name: $name');
                  print('  Local: $localPath');
                  print('  Thumb: $thumbnailPath');
                  print('  Cloud: $cloudUrl');

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
                    onTapPreview: () =>
                        _showFullImage(context, localPath, cloudUrl),
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
                child: _buildThumbnail(context),
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

  Widget _buildThumbnail(BuildContext context) {
    final placeholder = Container(
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: isDark ? Colors.grey[400] : Colors.grey[500],
      ),
    );

    // ✅ WEB: Use memory image from bytes if available
    if (kIsWeb) {
      // For web, images should be stored as base64 or available via URL
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    isDark ? Colors.white : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, error, stack) {
            print('❌ Web image load error: $error');
            return placeholder;
          },
        );
      }
      return placeholder;
    }

    // ✅ MOBILE/DESKTOP: Try thumbnail first
    if (thumbnailPath != null) {
      final thumbFile = File(thumbnailPath!);
      if (thumbFile.existsSync()) {
        return Image.file(
          thumbFile,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) {
            print('❌ Thumbnail load error: $error');
            // Fallback to full image
            if (localPath != null) {
              final fullFile = File(localPath!);
              if (fullFile.existsSync()) {
                return Image.file(
                  fullFile,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    print('❌ Full image also failed');
                    return placeholder;
                  },
                );
              }
            }
            return placeholder;
          },
        );
      } else {
        print('⚠️ Thumbnail file does not exist: $thumbnailPath');
      }
    }

    // ✅ Try full image path
    if (localPath != null) {
      final fullFile = File(localPath!);
      if (fullFile.existsSync()) {
        return Image.file(
          fullFile,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) {
            print('❌ Full image load error: $error');
            return placeholder;
          },
        );
      } else {
        print('⚠️ Full image file does not exist: $localPath');
      }
    }

    // ✅ Final fallback to cloud URL
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
        errorBuilder: (_, error, stack) {
          print('❌ Cloud URL load error: $error');
          return placeholder;
        },
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
