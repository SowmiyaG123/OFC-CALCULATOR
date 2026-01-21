import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../auth/login_page.dart';
import '../diagram/diagram_page.dart';
import '../downloads/download_page.dart';
import '../main_app/wdm_calculator_page.dart';
import '../../pages/networks/networks_page.dart';
import '../../models/network_project.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;
  String _userName = "Welcome back"; // Simplified greeting

  // App color palette
  final Color _primaryColor = const Color(0xFF0A2647);
  final Color _secondaryColor = const Color(0xFF144272);
  final Color _accentColor = const Color(0xFF2C74B3);
  final Color _dashboardBg = const Color(0xFFF8FAFC);
  final Color _textPrimary = const Color(0xFF1E293B);
  final Color _textSecondary = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Fetch user name from auth service
    _fetchUserName();
  }

  void _fetchUserName() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && user.email != null) {
        setState(() {
          _userName = "Welcome back"; // Just show "Welcome back" without name
        });
      }
    } catch (e) {
      // Keep default greeting if error occurs
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isLargeScreen = size.width > 1024;
    final bool isMediumScreen = size.width > 768;

    return Scaffold(
      backgroundColor: _dashboardBg,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        toolbarHeight: 80,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo_pic.png',
              height: 36,
              width: 36,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NioRix FiberCalc',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Professional Fiber Optics Suite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: _buildSidebar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section - Simplified
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMediumScreen ? 40 : 24,
                vertical: 32,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor.withOpacity(0.95),
                    _secondaryColor.withOpacity(0.95),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName, // Just shows "Welcome back"
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Professional fiber optics calculations',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Main tools section
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMediumScreen ? 40 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Professional Tools',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Advanced fiber optics calculation suite for professional engineers',
                    style: TextStyle(
                      fontSize: 15,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Main tools grid - Full width cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isLargeScreen
                        ? 3
                        : isMediumScreen
                            ? 2
                            : 1,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: isLargeScreen ? 1.2 : 1.4,
                    children: [
                      _buildProfessionalToolCard(
                        context,
                        'FTTH Calculator',
                        Icons.calculate_rounded,
                        'Combined Coupler + Splitter + Integrated WDM calculator and planner',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CouplerSplitterOnePage(), // ✅ FIXED - Opens calculator
                            ),
                          );
                        },
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1),
                            const Color(0xFF8B5CF6),
                          ],
                        ),
                      ),
                      _buildProfessionalToolCard(
                        context,
                        'Network Diagram',
                        Icons.account_tree_rounded,
                        'Generate professional network topology diagrams',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NetworksPage(), // ✅ FIXED - Opens networks page
                            ),
                          );
                        },
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0EA5E9),
                            const Color(0xFF3B82F6),
                          ],
                        ),
                      ),
                      _buildProfessionalToolCard(
                        context,
                        'Downloads',
                        Icons.cloud_download_rounded,
                        'Access your saved calculations and diagrams',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DownloadsPage(),
                            ),
                          );
                        },
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF059669),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isLargeScreen
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() => _selectedIndex = index);
                  switch (index) {
                    case 0:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CouplerSplitterOnePage(),
                        ),
                      );
                      break;
                    // FIXED CODE:
                    case 1:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OFCDiagramPage(), // ✅ REMOVED const
                        ),
                      );
                      break;
                    case 2:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadsPage(),
                        ),
                      );
                      break;
                  }
                },
                backgroundColor: Colors.white,
                selectedItemColor: _accentColor,
                unselectedItemColor: Colors.grey.shade600,
                selectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: [
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedIndex == 0
                            ? _accentColor.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.calculate_rounded, size: 24),
                    ),
                    label: 'Calculator',
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedIndex == 1
                            ? _accentColor.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.account_tree_rounded, size: 24),
                    ),
                    label: 'Diagram',
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _selectedIndex == 2
                            ? _accentColor.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: const Icon(Icons.download_rounded, size: 24),
                    ),
                    label: 'Downloads',
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildProfessionalToolCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap, {
    required Gradient gradient,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Drawer _buildSidebar(BuildContext context) {
    return Drawer(
      width: 280,
      elevation: 16,
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebarContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _secondaryColor],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo_pic.png',
                      height: 32,
                      width: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NioRix FiberCalc',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Professional Edition',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Navigation items - REMOVED Settings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSidebarItem(
                  Icons.dashboard_rounded,
                  'Dashboard',
                  true,
                  () {
                    Navigator.pop(context); // Close drawer
                  },
                ),
                _buildSidebarItem(
                  Icons.calculate_rounded,
                  'FTTH Calculator',
                  false,
                  () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CouplerSplitterOnePage(),
                      ),
                    );
                  },
                ),
                _buildSidebarItem(
                  Icons.account_tree_rounded,
                  'Network Diagram',
                  false,
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NetworksPage(),
                      ),
                    );
                  },
                ),
                _buildSidebarItem(
                  Icons.download_rounded,
                  'Downloads',
                  false,
                  () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DownloadsPage(),
                      ),
                    );
                  },
                ),
                // REMOVED Settings item
              ],
            ),
          ),

          const Spacer(),

          // Logout section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showLogoutDialog(context);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? _accentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive ? _accentColor.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? _accentColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? _accentColor : Colors.grey.shade700,
              ),
            ),
            const Spacer(),
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        AuthService().logout();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
    );
  }
}
