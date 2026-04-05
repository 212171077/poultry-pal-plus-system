import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'bottom_app_bar_border_painter.dart';
import 'common.dart';
import 'farm_dashboard.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});

    @override
    State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
    int _selectedIndex = 2;
    Farm? farm;
    User? user;
    String _appBarTitle = "My Coops";
    List<Coop> coops = [];
    List<Widget> _widgetOptions = [];
    PoultryPalService service = PoultryPalService();

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
            FarmDashboard(farm: farm, user: user),
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
                if (a.active == b.active) return 0; // Keep relative order if both same
                return a.active ? -1 : 1; // Active first
            });
        return Builder(
            builder: (BuildContext context) {
                return Column(
                    children: [
                        Expanded(
                            child: coops.isEmpty
                                ? const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                            'Let\'s add your coop details to get started.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: AppColors.textTertiaryLight,
                                                fontWeight: FontWeight.w500,
                                            ),
                                        ),
                                    ),
                                )
                                : // Sort so active coops come first

                                ListView.builder(
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
                        const SingleChildScrollView(
                            child: Column(
                                children: [
                                    SizedBox(height: 50), // Space at the bottom
                                ],
                            ),
                        )

                    ],
                );
            },
        );
    }

    void _onItemTapped(int index, String title) {
        setState(() {
                _selectedIndex = index;
                _appBarTitle = title;
            });
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

    @override
    Widget build(BuildContext context) {
        // Show loading screen if data hasn't been initialized yet
        if (farm == null || user == null || _widgetOptions.isEmpty) {
            return Scaffold(
                appBar: AppBar(
                    title: const Text("Loading..."),
                    elevation: 0,
                ),
                body: const Center(
                    child: CircularProgressIndicator(),
                ),
            );
        }

        return Scaffold(
            extendBody: true, // Let the FAB overlap the nav bar background
            floatingActionButton: Visibility(
                visible: MediaQuery.of(context).viewInsets.bottom == 0,
                child: FloatingActionButton(
                    onPressed: () => _onItemTapped(2, "My Coops"),
                    backgroundColor: _selectedIndex == 2
                        ? AppColors.success : Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add_home_work_outlined, size: 28),
                ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            appBar: customAppBar(context, farm!, user!, _appBarTitle, _logout),

            body: Center(
                child: (_selectedIndex < _widgetOptions.length && _widgetOptions.isNotEmpty)
                    ? _widgetOptions[_selectedIndex]
                    : const CircularProgressIndicator(),
            ),
            bottomNavigationBar: Stack(
                children: [
                    BottomAppBar(
                        shape: const CircularNotchedRectangle(),
                        notchMargin: 6.0,
                        child: SizedBox(
                            height: 60,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                    Expanded(
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                                _buildBottomNavItem(Icons.fact_check, 'Reminders', 0),
                                                _buildBottomNavItem(Icons.bar_chart, 'Dashboard', 1),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(width: 60), // Leave space for the center button
                                    Expanded(
                                        child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                                _buildBottomNavItem(Icons.person, 'Profile', 3),
                                                _buildBottomNavItem(Icons.settings, 'Settings', 4),
                                            ],
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),
                    Positioned.fill(
                        child: IgnorePointer(
                            child: CustomPaint(
                                painter: BottomAppBarBorderPainter(
                                    color: AppColors.borderLight,
                                ),
                            ),
                        ),
                    ),
                ],
            ),

        );
    }

    Widget _buildBottomNavItem(IconData icon, String label, int index) {
        return IconButton(
            icon: Icon(icon),
            onPressed: () => _onItemTapped(index, label),
            color: _selectedIndex == index
                ? AppColors.success : Theme.of(context).primaryColor,
        );
    }

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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                                    color: showCoopTypeError ? AppColors.error : Theme.of(context).primaryColor,
                                                                                ),
                                                                            ),
                                                                            const SizedBox(height: 3),
                                                                            Container(
                                                                                width: double.infinity, // Expand horizontally
                                                                                decoration: BoxDecoration(
                                                                                    border: Border.all(
                                                                                        color: showCoopTypeError ? AppColors.error : Theme.of(context).primaryColor.withAlpha(128),
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
                                                                                                    color: coopType == 'Broiler' ? Colors.white : Colors.black,
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                        'Layers': Padding(
                                                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                                                            child: Text(
                                                                                                'Layers',
                                                                                                style: TextStyle(
                                                                                                    color: coopType == 'Layers' ? Colors.white : Colors.black,
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                    },
                                                                                    borderColor: AppColors.borderLight,
                                                                                    selectedColor: AppColors.primary,
                                                                                    unselectedColor: Colors.white,
                                                                                    pressedColor: AppColors.surfaceVariantLight,
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
                                                                                    color: showGrowthPhaseError ? AppColors.error : Theme.of(context).primaryColor,
                                                                                ),
                                                                            ),
                                                                            const SizedBox(height: 3),
                                                                            Container(
                                                                                width: double.infinity,
                                                                                decoration: BoxDecoration(
                                                                                    border: Border.all(
                                                                                        color: showGrowthPhaseError
                                                                                            ? AppColors.error
                                                                                            : Theme.of(context).primaryColor.withAlpha(128),
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
                                                                                                        : Colors.black,
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
                                                                                                        : Colors.black,
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
                                                                                                        : Colors.black,
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                    },
                                                                                    borderColor: AppColors.borderLight,
                                                                                    selectedColor: AppColors.primary,
                                                                                    unselectedColor: Colors.white,
                                                                                    pressedColor: AppColors.surfaceVariantLight,
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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

    PreferredSizeWidget customAppBar(
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
                                                    color: Theme.of(context).primaryColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                ),
                                            ),
                                        ),
                                        IconButton(
                                            icon: Icon(Icons.logout_sharp, color: Theme.of(context).primaryColor),
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
                                                            color: Theme.of(context).primaryColor,
                                                        ),
                                                    ).animate().fadeIn(duration: 600.ms).moveY(begin: 30),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                        "${user.surname} ${user.name}",
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: Theme.of(context).primaryColor,
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
                            decoration: const BoxDecoration(
                                color: AppColors.backgroundLight,
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

