import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:poultry_pal_plus_app/models/coop.dart';
import 'package:poultry_pal_plus_app/screens/coop_list_item.dart';
import 'package:poultry_pal_plus_app/screens/profile_page.dart';
import 'package:poultry_pal_plus_app/screens/reminders_screen.dart';
import 'package:poultry_pal_plus_app/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/growing_phase.dart';
import '../models/farm.dart';
import '../models/message_response.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';
import 'common.dart';
import 'farm_dashboard.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});

    @override
    State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

    static const List<String> _pageTitles = [
        'Reminders', 'Dashboard', 'My Coops', 'Profile', 'Settings',
    ];

    int _selectedIndex = 2;
    Farm? farm;
    User? user;
    String _appBarTitle = 'My Coops';
    List<Coop> coops = [];
    List<Widget> _widgetOptions = [];
    PoultryPalService service = PoultryPalService();

    // ── Time-based greeting ───────────────────────────────────────────────────
    String get _greeting {
        final hour = DateTime.now().hour;
        final name = user?.name ?? '';
        if (hour >= 5 && hour < 12) return 'Good morning, $name 🌅';
        if (hour >= 12 && hour < 17) return 'Good afternoon, $name ☀️';
        if (hour >= 17 && hour < 21) return 'Good evening, $name 🌇';
        return 'Good night, $name 🌙';
    }

    // ── Quick-stats computed from live farm data ───────────────────────────────
    int get _totalActiveCoops => coops.where((c) => c.active).length;
    int get _totalChickens => coops.fold(0, (sum, c) => sum + c.numberOfChickens);
    int get _todayEggCount {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        return coops.fold(0, (sum, coop) =>
            sum + coop.eggPackagingRecords
                .where((r) => r.createdDate.startsWith(today))
                .fold(0, (s, r) => s + r.totalEggs));
    }
    int get _pendingRemindersCount => coops.fold(0, (sum, coop) =>
        sum + coop.reminder.upcomingReminders.length + coop.reminder.overdueTasks.length);

    @override
    void initState() {
        super.initState();
        _initializeData();
    }

    void _onCoopUpdated() {
        _initializeData();
    }

    Future<void> _initializeData() async {
        try {
            final farmData = await SessionManager().get("farmData");
            final userData = await SessionManager().get("userData");

            if (farmData != null && userData != null) {
                final farmMap = Map<String, dynamic>.from(farmData);
                final userMap = Map<String, dynamic>.from(userData);

                farm = Farm.fromJson(farmMap);
                user = User.fromJson(userMap);
                coops = farm!.coops;

                _updateWidgetOptions(farm!, user!);
            }

            setState(() {});
        } catch (e) {
            debugPrint('Error initializing data: $e');
            _showErrorSnackBar('Something went wrong');
        }
    }

    void _updateWidgetOptions(Farm farm, User user) {
        _widgetOptions = [
            RemindersScreen(farm: farm, user: user, onCoopUpdated: _onCoopUpdated),
            FarmDashboard(
                farm: farm,
                user: user,
                onRefresh: _initializeData,
                onNavigateToTab: (index) => setState(() {
                    _selectedIndex = index;
                    _appBarTitle = _pageTitles[index];
                }),
            ),
            buildMyCoopsPage(),
            ProfilePage(farm: farm, user: user, onCoopUpdated: _onCoopUpdated),
            SettingsScreen(farm: farm, user: user),
        ];
    }

    void _showErrorSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.error),
        );
    }

    void _showSuccessSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.success),
        );
    }

    Builder buildMyCoopsPage() {
        final sortedCoops = [...coops]..sort((a, b) {
                if (a.active == b.active) return 0;
                return a.active ? -1 : 1;
            });
        return Builder(
            builder: (BuildContext context) {
                return Column(
                    children: [
                        Expanded(
                            child: coops.isEmpty
                                ? Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                            'Let\'s add your coop details to get started.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: AppColors.textTertiary(context),
                                                fontWeight: FontWeight.w500,
                                            ),
                                        ),
                                    ),
                                )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 96),
                                    itemCount: sortedCoops.length,
                                    itemBuilder: (context, index) {
                                        return CoopListItem(
                                            coop: sortedCoops[index],
                                            farm: farm!,
                                            user: user!,
                                            onCoopUpdated: _onCoopUpdated,
                                        );
                                    },
                                ),
                        ),
                    ],
                );
            },
        );
    }

    Future<void> _logout() async {
        await SessionManager().destroy();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
        );
    }

    // ── BUILD ─────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
        if (farm == null || user == null || _widgetOptions.isEmpty) {
            return Scaffold(
                appBar: AppBar(title: const Text('Loading...'), elevation: 0),
                body: const Center(child: CircularProgressIndicator()),
            );
        }

        return Scaffold(
            // FAB: only shown on My Coops tab for farm owners
            floatingActionButton: (_selectedIndex == 2 && user!.farmOwner)
                ? FloatingActionButton(
                    heroTag: 'add_coop_fab',
                    onPressed: () => _showAddCoopBottomSheet(context),
                    backgroundColor: AppColors.success,
                    shape: const CircleBorder(),
                    tooltip: 'Add New Coop',
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

            body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    _buildSliverAppBar(context, innerBoxIsScrolled),
                    SliverToBoxAdapter(child: _buildQuickStatsRow()),
                    const SliverToBoxAdapter(
                        child: Divider(height: 1, thickness: 1),
                    ),
                ],
                body: _widgetOptions[_selectedIndex],
            ),

            bottomNavigationBar: _buildNavigationBar(),
        );
    }

    // ── SLIVER APP BAR ────────────────────────────────────────────────────────

    SliverAppBar _buildSliverAppBar(BuildContext context, bool innerBoxIsScrolled) {
        return SliverAppBar(
            expandedHeight: 170.0,
            pinned: true,
            floating: false,
            snap: false,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: AppColors.surface(context),
            foregroundColor: AppColors.adaptivePrimary(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 2,
            shadowColor: AppColors.shadowLight.withValues(alpha: 0.15),
            // Animated title — fades between tab names
            title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                    _appBarTitle,
                    key: ValueKey(_appBarTitle),
                    style: TextStyle(
                        color: AppColors.adaptivePrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                    ),
                ),
            ),
            actions: [
                // Context-sensitive action (download report on Dashboard)
                AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _buildAppBarAction(context),
                ),
                // Logout
                IconButton(
                    icon: Icon(Icons.logout_sharp, color: AppColors.adaptivePrimary(context)),
                    onPressed: _logout,
                    tooltip: 'Logout',
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _buildExpandedHeader(context),
            ),
        );
    }

    /// Contextual action button in the app bar (download report on Dashboard tab).
    Widget _buildAppBarAction(BuildContext context) {
        if (_appBarTitle == 'Dashboard' &&
            user!.farmOwner &&
            farm!.farmReport.coopReports.isNotEmpty) {
            return IconButton(
                key: const ValueKey('download_action'),
                icon: Icon(Icons.download_outlined, color: AppColors.adaptivePrimary(context)),
                tooltip: 'Email Farm Report',
                onPressed: () async {
                    final MessageResponse response = await service.sendReportViaEmail(
                        farmId: farm!.id,
                        userId: user!.id,
                    );
                    if (response.success) {
                        _showSuccessSnackBar(response.message);
                    } else {
                        _showErrorSnackBar(response.message);
                    }
                },
            );
        }
        return const SizedBox.shrink(key: ValueKey('no_action'));
    }

    /// Expanded flexible-space background: greeting + farm/user info.
    Widget _buildExpandedHeader(BuildContext context) {
        final topOffset = MediaQuery.of(context).padding.top + 56 + 6;
        return Container(
            color: AppColors.surface(context),
            padding: EdgeInsets.fromLTRB(16, topOffset, 100, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                    // Farm avatar + greeting + farm name
                    Row(
                        children: [
                            Hero(
                                tag: 'farm-avatar',
                                child: Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.border(context),
                                            width: 1.5,
                                        ),
                                    ),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.asset(
                                            'assets/icon.png',
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                        ),
                                    ),
                                ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Text(
                                            _greeting,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.adaptivePrimary(context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                        )
                                        .animate()
                                        .fadeIn(duration: 500.ms)
                                        .moveY(begin: 10),
                                        const SizedBox(height: 2),
                                        Text(
                                            farm!.farmName,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary(context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                        )
                                        .animate()
                                        .fadeIn(duration: 500.ms, delay: 80.ms)
                                        .moveY(begin: 10),
                                    ],
                                ),
                            ),
                        ],
                    ),
                ],
            ),
        );
    }

    // ── QUICK-STATS ROW ───────────────────────────────────────────────────────

    Widget _buildQuickStatsRow() {
        return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
                children: [
                    _buildStatCard('Coops', '$_totalActiveCoops',
                        Icons.home_work_outlined, AppColors.primary),
                    const SizedBox(width: 8),
                    _buildStatCard('Chickens', '$_totalChickens',
                        Icons.egg_alt_outlined, AppColors.secondaryDark),
                    const SizedBox(width: 8),
                    _buildStatCard("Eggs Today", '$_todayEggCount',
                        Icons.egg_outlined, AppColors.success),
                    const SizedBox(width: 8),
                    _buildStatCard('Reminders', '$_pendingRemindersCount',
                        Icons.notifications_outlined, AppColors.warning),
                ],
            ),
        );
    }

    Widget _buildStatCard(String label, String value, IconData icon, Color color) {
        return Expanded(
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: color.withValues(alpha: 0.28),
                        width: 1,
                    ),
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(height: 3),
                        Text(
                            value,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: color,
                            ),
                        ),
                        Text(
                            label,
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ],
                ),
            ),
        );
    }

    // ── MATERIAL 3 NAVIGATION BAR ─────────────────────────────────────────────

    NavigationBar _buildNavigationBar() {
        return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
                setState(() {
                    _selectedIndex = index;
                    _appBarTitle = _pageTitles[index];
                });
            },
            backgroundColor: AppColors.surface(context),
            indicatorColor: AppColors.primary.withValues(alpha: 0.15),
            surfaceTintColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            elevation: 3,
            destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications, color: AppColors.primary),
                    label: 'Reminders',
                ),
                NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart, color: AppColors.primary),
                    label: 'Dashboard',
                ),
                NavigationDestination(
                    icon: Icon(Icons.home_work_outlined),
                    selectedIcon: Icon(Icons.home_work, color: AppColors.primary),
                    label: 'My Coops',
                ),
                NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: AppColors.primary),
                    label: 'Profile',
                ),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings, color: AppColors.primary),
                    label: 'Settings',
                ),
            ],
        );
    }

    // ── ADD COOP BOTTOM SHEET ─────────────────────────────────────────────────

    void _showAddCoopBottomSheet(BuildContext context) {
        final formKey = GlobalKey<FormState>();
        String coopName = '';
        String? coopType;
        GrowingPhase? growthPhase;
        int numberOfChickens = 0;
        DateTime? chickenArrivalDate;
        bool showCoopTypeError = false;
        bool showGrowthPhaseError = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Add New Coop',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Coop Name',
                                                                    icon: Icons.home_outlined,
                                                                    onChanged: (value) => coopName = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter a coop name'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 10),
                                                                Padding(
                                                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                                    child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Text(
                                                                                'Select Coop Type',
                                                                                style: TextStyle(
                                                                                    fontSize: 14,
                                                                                    fontWeight: FontWeight.w500,
                                                                                    color: showCoopTypeError ? AppColors.error : AppColors.adaptivePrimary(context),
                                                                                ),
                                                                            ),
                                                                            const SizedBox(height: 3),
                                                                            Container(
                                                                                width: double.infinity, // Expand horizontally
                                                                                decoration: BoxDecoration(
                                                                                    border: Border.all(
                                                                                        color: showCoopTypeError ? AppColors.error : AppColors.adaptivePrimary(context).withAlpha(128),
                                                                                        width: 1,
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(8),
                                                                                ),
                                                                                padding: const EdgeInsets.all(4),
                                                                                child: CupertinoSegmentedControl<String>(
                                                                                    padding: const EdgeInsets.all(4),
                                                                                    groupValue: coopType,
                                                                                    onValueChanged: (val) => setModalState(() {
                                                                                            coopType = val;
                                                                                            showCoopTypeError = false; // Hide error once selected
                                                                                        }),
                                                                                    children: {
                                                                                        'Broiler': Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Broiler',
                                                                                                style: TextStyle(
                                                                                                    color: coopType == 'Broiler' ? Colors.white : AppColors.textPrimary(context),
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                        'Layers': Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Layers',
                                                                                                style: TextStyle(
                                                                                                    color: coopType == 'Layers' ? Colors.white : AppColors.textPrimary(context),
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                    },
                                                                                    borderColor: AppColors.border(context),
                                                                                    selectedColor: AppColors.primary,
                                                                                    unselectedColor: AppColors.surface(context),
                                                                                    pressedColor: AppColors.surfaceVariant(context),
                                                                                ),
                                                                            ),
                                                                            if (showCoopTypeError)
                                                                            const Padding(
                                                                                padding: EdgeInsets.only(top: 6),
                                                                                child: Text(
                                                                                    'Please select a coop type',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.error,
                                                                                        fontSize: 12,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 0),
                                                                Padding(
                                                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                                    child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Text(
                                                                                'Select Growing Phase',
                                                                                style: TextStyle(
                                                                                    fontSize: 14,
                                                                                    fontWeight: FontWeight.w500,
                                                                                    color: showGrowthPhaseError ? AppColors.error : AppColors.adaptivePrimary(context),
                                                                                ),
                                                                            ),
                                                                            const SizedBox(height: 3),
                                                                            Container(
                                                                                width: double.infinity,
                                                                                decoration: BoxDecoration(
                                                                                    border: Border.all(
                                                                                        color: showGrowthPhaseError
                                                                                            ? AppColors.error
                                                                                            : AppColors.adaptivePrimary(context).withAlpha(128),
                                                                                        width: 1,
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(8),
                                                                                ),
                                                                                padding: const EdgeInsets.all(4),
                                                                                child: CupertinoSegmentedControl<GrowingPhase>(
                                                                                    padding: const EdgeInsets.all(4),
                                                                                    groupValue: growthPhase,
                                                                                    onValueChanged: (val) => setModalState(() {
                                                                                            growthPhase = val;
                                                                                            showGrowthPhaseError = false;
                                                                                        }),
                                                                                    children: {
                                                                                        GrowingPhase.BROODING_PHASE: Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Brooding',
                                                                                                style: TextStyle(
                                                                                                    color: growthPhase == GrowingPhase.BROODING_PHASE
                                                                                                        ? Colors.white
                                                                                                        : AppColors.textPrimary(context),
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                        GrowingPhase.GROWING_REARING_PHASE: Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Growing',
                                                                                                style: TextStyle(
                                                                                                    color: growthPhase == GrowingPhase.GROWING_REARING_PHASE
                                                                                                        ? Colors.white
                                                                                                        : AppColors.textPrimary(context),
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                        GrowingPhase.PRODUCTION_FINISHING_PHASE: Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Production',
                                                                                                style: TextStyle(
                                                                                                    color: growthPhase == GrowingPhase.PRODUCTION_FINISHING_PHASE
                                                                                                        ? Colors.white
                                                                                                        : AppColors.textPrimary(context),
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                    },
                                                                                    borderColor: AppColors.border(context),
                                                                                    selectedColor: AppColors.primary,
                                                                                    unselectedColor: AppColors.surface(context),
                                                                                    pressedColor: AppColors.surfaceVariant(context),
                                                                                ),
                                                                            ),
                                                                            if (showGrowthPhaseError)
                                                                            const Padding(
                                                                                padding: EdgeInsets.only(top: 6),
                                                                                child: Text(
                                                                                    'Please select a growth phase',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.error,
                                                                                        fontSize: 12,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 18),
                                                                Common.buildTextField(
                                                                    label: 'Number of Chickens (Optional)',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfChickens = int.tryParse(value) ?? 0,
                                                                    validator: null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 36),
                                                                Common.buildDateField(
                                                                    context: context,
                                                                    label: 'Chicken Arrival Date (Optional)',
                                                                    date: chickenArrivalDate,
                                                                    onDateSelected: (picked) {
                                                                        setModalState(() {
                                                                                chickenArrivalDate = picked;
                                                                            });
                                                                    },
                                                                ),

                                                                const SizedBox(height: 36),
                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {
                                                                                    final isFormValid = formKey.currentState!.validate();
                                                                                    final isCoopTypeValid = coopType != null && coopType!.trim().isNotEmpty;
                                                                                    final isGrowthPhaseValid = growthPhase != null && growthPhase!.toString().trim().isNotEmpty;

                                                                                    setModalState(() {
                                                                                            showCoopTypeError = !isCoopTypeValid;
                                                                                            showGrowthPhaseError = !isGrowthPhaseValid;
                                                                                        });

                                                                                    if (!isFormValid || !isCoopTypeValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.updateFarmCoop(
                                                                                        farmId: farm!.id,
                                                                                        coopId: null,
                                                                                        coopName: coopName,
                                                                                        coopType: coopType ?? '',
                                                                                        growthPhase: growthPhase ?? GrowingPhase.NONE,
                                                                                        numberOfChickens: numberOfChickens,
                                                                                        chickenArrivalDate: chickenArrivalDate?.toIso8601String(),
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (!context.mounted) return;

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        _initializeData();
                                                                                    } else {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/error.json',
                                                                                            message: response.message,
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),

                                                                const SizedBox(height: 16),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    // ignore: unused_element — kept for reference only; remove in next cleanup
    PreferredSizeWidget _legacyCustomAppBar(
        BuildContext context,
        Farm farm,
        User user,
        String? appBarTitle,
        VoidCallback logout,
    ) {
        return PreferredSize(
            preferredSize: const Size.fromHeight(190),
            child: Stack(
                clipBehavior: Clip.none,
                children: [
                    // Background AppBar
                    Container(
                        height: 190,
                        decoration: const BoxDecoration(
                            color: AppColors.surfaceLight,
                        ),
                        padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                // Top row (Title + Logout)
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        // AnimatedSwitcher detects changes and animates
                                        AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 0),
                                            transitionBuilder: (child, animation) {
                                                return child
                                                    .animate()
                                                    .fadeIn(duration: 600.ms)
                                                    .moveX(begin: -30);
                                            },
                                            child: Text(
                                                appBarTitle ?? 'Dashboard',
                                                key: ValueKey(appBarTitle ?? 'Dashboard'),
                                                style: TextStyle(
                                                    color: AppColors.adaptivePrimary(context),
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                ),
                                            ),
                                        ),
                                        IconButton(
                                            icon: Icon(Icons.logout_sharp, color: AppColors.adaptivePrimary(context)),
                                            onPressed: logout,
                                        ),
                                    ],
                                ),
                                const SizedBox(height: 10),

                                // Farm info + conditional buttons
                                Row(
                                    children: [
                                        // Avatar
                                        Hero(
                                            tag: 'farm-avatar',
                                            child: Container(  // Wrap with a Container
                                                decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                        color: AppColors.textTertiaryLight,
                                                        width: 1.5,
                                                    ),
                                                ),

                                                child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(50),
                                                    child: Image.asset(
                                                        'assets/icon.png',
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                    ),
                                                ),
                                            ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Farm & User names
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(
                                                        farm.farmName,
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.adaptivePrimary(context),
                                                        ),
                                                    ).animate().fadeIn(duration: 600.ms).moveY(begin: 30),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                        "${user.surname} ${user.name}",
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: AppColors.adaptivePrimary(context),
                                                        ),
                                                    ).animate().fadeIn(duration: 600.ms).moveY(begin: 30),
                                                ],
                                            ),
                                        ),

                                        // Conditional buttons with fade in/out
                                        AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 500),
                                            transitionBuilder: (child, animation) {
                                                return FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                );
                                            },
                                            child: (appBarTitle == 'My Coops' && user.farmOwner)
                                                ? Container(
                                                    key: const ValueKey('add_coop_button'),
                                                    margin: const EdgeInsets.only(left: 8),
                                                    decoration: BoxDecoration(
                                                        color: AppColors.surfaceLight,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: AppColors.success, width: 2),
                                                    ),
                                                    child: Material(
                                                        color: Colors.transparent,
                                                        shape: const CircleBorder(),
                                                        child: InkWell(
                                                            customBorder: const CircleBorder(),
                                                            onTap: () {
                                                                _showAddCoopBottomSheet(context);
                                                            },
                                                            child: const Padding(
                                                                padding: EdgeInsets.all(8.0),
                                                                child: Icon(Icons.add, color: AppColors.success),
                                                            ),
                                                        ),
                                                    ),
                                                )
                                                : (appBarTitle == 'Dashboard' && user.farmOwner && farm.farmReport.coopReports.isNotEmpty)
                                                    ? Container(
                                                        key: const ValueKey('download_button'),
                                                        margin: const EdgeInsets.only(left: 8),
                                                        decoration: BoxDecoration(
                                                            color: AppColors.surfaceLight, // changed here
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: AppColors.success, width: 2),
                                                        ),
                                                        child: Material(
                                                            color: Colors.transparent,
                                                            shape: const CircleBorder(),
                                                            child: InkWell(
                                                                customBorder: const CircleBorder(),
                                                                onTap: () async {
                                                                    final MessageResponse response = await service.sendReportViaEmail(
                                                                        farmId: farm.id,
                                                                        userId: user.id,
                                                                    );

                                                                    if (response.success) {
                                                                        _showSuccessSnackBar(response.message);
                                                                    } else {
                                                                        _showErrorSnackBar(response.message);
                                                                    }
                                                                },
                                                                child: const Padding(
                                                                    padding: EdgeInsets.all(8.0),
                                                                    child: Icon(Icons.download, color: AppColors.success),
                                                                ),
                                                            ),
                                                        ),
                                                    )
                                                    : const SizedBox.shrink(),

                                        ),

                                    ],
                                ),
                            ],
                        ),
                    ),

                    // Rounded Card at the bottom
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(25),
                                    topRight: Radius.circular(25),
                                ),
                                boxShadow: [
                                    BoxShadow(
                                        color: AppColors.textTertiaryLight,
                                        blurRadius: 1,
                                        offset: Offset(0, -1),
                                    ),
                                ],
                            ),
                            height: 20,
                        ),
                    ),
                ],
            ),
        );
    }

}

