// ============================================================
// lib/pages/networks/networks_page.dart
// ENHANCED UI with modern color scheme - DUPLICATE BUTTONS REMOVED
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Correct import
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/network_project.dart';
import '../../screens/diagram/diagram_page.dart';

class NetworksPage extends StatefulWidget {
  const NetworksPage({Key? key}) : super(key: key);

  @override
  State<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends State<NetworksPage> {
  // MODERN COLOR PALETTE
  static const Color _primary = Color(0xFF4361EE); // Vibrant blue
  static const Color _secondary = Color(0xFF7209B7); // Purple
  static const Color _accent = Color(0xFF4CC9F0); // Cyan
  static const Color _bg = Color(0xFFF8FAFD); // Light background
  static const Color _surface = Color(0xFFFFFFFF); // Card background
  static const Color _textPrimary = Color(0xFF1A1A2E); // Dark text
  static const Color _textSecondary = Color(0xFF6B7280); // Gray text

  late Box<dynamic> _projectsBox;
  List<NetworkProject> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    _projectsBox = await Hive.openBox('network_projects');
    setState(() {
      _projects = _projectsBox.values
          .where((e) => e != null)
          .map((e) => NetworkProject.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> _createNewProject() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_surface, Color(0xFFF8FAFF)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient text
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [_primary, _secondary],
                  ).createShader(bounds),
                  child: Text(
                    'Create New Network',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Text field with modern styling
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.1),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      hintText: 'Enter network name',
                      hintStyle: TextStyle(color: _textSecondary),
                      border: InputBorder.none,
                      prefixIcon: Container(
                        margin: EdgeInsets.only(left: 12, right: 8),
                        child: Icon(
                          Icons.lan,
                          color: _primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: Color(0xFFF3F4F6),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              _accent,
                              _primary
                            ], // CHANGED: Using accent to primary gradient
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(
                                  0.3), // CHANGED: Using accent color
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isNotEmpty) {
                              Navigator.pop(ctx, nameController.text.trim());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Create',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final now = DateTime.now();
      final project = NetworkProject(
        id: now.millisecondsSinceEpoch.toString(),
        name: result,
        createdAt: now,
        updatedAt: now,
        transmitterPower: 19.0,
      );

      await _projectsBox.put(project.id, project.toJson());
      await _loadProjects();

      if (mounted) {
        final diagramResult = await Navigator.push<Map<String, dynamic>?>(
          context,
          MaterialPageRoute(
            builder: (_) => OFCDiagramPage(
              savedData: {
                'projectId': project.id,
                'projectName': project.name,
              },
            ),
          ),
        );

        if (diagramResult != null && mounted) {
          await _updateProject(project.id, diagramResult);
        }
      }
    }
  }

  Future<void> _updateProject(String id, Map<String, dynamic> data) async {
    try {
      final existingData = _projectsBox.get(id);
      if (existingData != null) {
        final Map<String, dynamic> existingMap =
            Map<String, dynamic>.from(existingData);

        final updated = {
          ...existingMap,
          'updatedAt': DateTime.now().toIso8601String(),
          'headendName': data['headendName'],
          'headendPower': data['headendPower'],
          'wavelength': data['wavelength'],
          'useWdm': data['useWdm'],
          'wdmLoss': data['wdmLoss'],
          'diagramTree': data['diagramTree'],
        };

        await _projectsBox.put(id, updated);
        await _loadProjects();
      }
    } catch (e) {
      print('❌ Error updating project: $e');
    }
  }

  Future<void> _deleteProject(String id) async {
    await _projectsBox.delete(id);
    await _loadProjects();
  }

  Future<void> _renameProject(NetworkProject project) async {
    final nameController = TextEditingController(text: project.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rename Network',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintText: 'Network name',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.edit, color: _primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Color(0xFFF3F4F6),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              _accent,
                              _primary
                            ], // CHANGED: Using accent to primary gradient
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(
                                  0.3), // CHANGED: Using accent color
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.trim().isNotEmpty) {
                              Navigator.pop(ctx, nameController.text.trim());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Rename',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final existingData = _projectsBox.get(project.id);
      if (existingData != null) {
        final Map<String, dynamic> existingMap =
            Map<String, dynamic>.from(existingData);

        final updated = {
          ...existingMap,
          'name': result,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await _projectsBox.put(project.id, updated);
        await _loadProjects();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 1,
          leading: Container(
            margin: EdgeInsets.only(left: 8),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primary,
                size: 24,
              ),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          title: Text(
            'Fiber Networks',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
          // REMOVED: Profile icon from top right
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats header with gradient
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [_primary, _secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lan,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Projects',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage your fiber optic networks',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_projects.length} Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Projects list
            Expanded(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadProjects,
                child: _projects.isEmpty
                    ? _buildEmptyState()
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.separated(
                          padding: EdgeInsets.only(bottom: 100),
                          itemCount: _projects.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            return _buildProjectCard(project);
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),

        // Single Floating Action Button (New Network) - NO duplicate
        floatingActionButton: Container(
          margin: EdgeInsets.only(bottom: 16),
          child: FloatingActionButton.extended(
            onPressed: _createNewProject,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Icon(Icons.add, size: 24),
            label: Text(
              'New Network',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: EdgeInsets.only(top: 60),
      children: [
        Column(
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _primary.withOpacity(0.1),
                    _secondary.withOpacity(0.1)
                  ],
                ),
              ),
              child: Icon(
                Icons.lan_outlined,
                size: 80,
                color: _primary.withOpacity(0.5),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Networks Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the "New Network" button below to get started',
              style: TextStyle(
                fontSize: 16,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            // REMOVED the duplicate button and link here
            // Only the floating action button remains
          ],
        ),
      ],
    );
  }

  Widget _buildProjectCard(NetworkProject project) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () async {
            final savedProjectData = _projectsBox.get(project.id);
            if (savedProjectData == null) return;

            final data = Map<String, dynamic>.from(savedProjectData);

            // ✅ Ensure WDM data is properly passed (exact logic from Downloads re-edit)
            final enhancedData = {
              ...data,
              'projectId': project.id,
              'projectName': project.name,
              // Ensure these fields exist
              'useWdm': data['useWdm'] ?? false,
              'wdmPower': data['wdmPower'] ?? 0.0,
              'wdmLoss': data['wdmLoss'] ?? 0.0,
            };

            print(
                '📋 Re-editing project with WDM: ${enhancedData['useWdm']}, Power: ${enhancedData['wdmPower']}');

            final result = await Navigator.push<Map<String, dynamic>?>(
              context,
              MaterialPageRoute(
                builder: (_) => OFCDiagramPage(savedData: enhancedData),
              ),
            );

            if (result != null && mounted) {
              await _updateProject(project.id, result);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon with gradient
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [_primary, _secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.power_settings_new,
                                  size: 12,
                                  color: _primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${project.transmitterPower.toStringAsFixed(1)} dBm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Created ${_formatDate(project.createdAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(
                            Icons.update_rounded,
                            size: 14,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Updated ${_formatDate(project.updatedAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 4,
                        width: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [_accent, _primary],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                // Options menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: _textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: _primary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Rename',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') {
                      _renameProject(project);
                    } else if (value == 'delete') {
                      _showDeleteDialog(project);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(NetworkProject project) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_rounded,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Delete Network?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${project.name}"?\nThis action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Color(0xFFF3F4F6),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              _accent,
                              _primary
                            ], // CHANGED: Using accent to primary gradient
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(
                                  0.3), // CHANGED: Using accent color
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _deleteProject(project.id);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks} ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$month/$day';
    }
  }
}
