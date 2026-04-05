import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:poultry_pal_plus_app/models/farm.dart';
import 'package:poultry_pal_plus_app/models/user.dart';
import '../models/coop.dart';
import '../service/poultry_pal_service.dart';
import 'common.dart';

class ProfilePage extends StatefulWidget {
    final Farm farm;
    final User user;
    final VoidCallback onCoopUpdated;
    final PoultryPalService service = PoultryPalService();

    ProfilePage(
    {super.key, required this.farm, required this.user, required this.onCoopUpdated});

    @override
    _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
    // Method to handle edit action
    void onEditPressed(String category) {
        print("Editing $category");
    }

    PoultryPalService service = PoultryPalService();

    void _showUpdateUserDetailsBottomSheet(BuildContext context, User user,
        Farm farm, VoidCallback onCoopUpdated) {
        final formKey = GlobalKey<FormState>();
        String name = user.name;
        String surname = user.surname;
        String email = user.email;
        String phoneNumber = user.phoneNumber;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
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
                                                color: AppColors.surface(context),
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
                                                    'Update Personal Details',
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
                                                                const SizedBox(height: 24),
                                                                Common.buildTextField(
                                                                    label: 'Name',
                                                                    icon: Icons.account_box_outlined,
                                                                    initialValue: name,
                                                                    onChanged: (value) => name = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter name'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Surname',
                                                                    icon: Icons.account_box_outlined,
                                                                    initialValue: surname,
                                                                    onChanged: (value) => surname = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter surname'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Email',
                                                                    icon: Icons.mail_outlined,
                                                                    initialValue: email,
                                                                    onChanged: (value) => email = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter email'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Phone Number',
                                                                    icon: Icons.phone,
                                                                    initialValue: phoneNumber,
                                                                    onChanged: (value) => phoneNumber = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter phone number'
                                                                        : null,
                                                                    context: context,
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
                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.updateUser(
                                                                                        id: user.id,
                                                                                        farmId: farm.id,
                                                                                        name: name,
                                                                                        surname: surname,
                                                                                        email: email,
                                                                                        phoneNumber: phoneNumber,
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
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
                                                                                        color: AppColors.onPrimary,
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

    void _showLoginDetailsBottomSheet(BuildContext context, User user,
        Farm farm, VoidCallback onCoopUpdated) async {
        final formKey = GlobalKey<FormState>();

        String currentPassword = '';
        String newPassword = '';
        String confirmPassword = '';
        bool isPasswordRequirementsExpanded = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
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
                                                color: AppColors.surface(context),
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
                                                    'Update Login Details',
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

                                                                ProfileField(
                                                                    icon: Icons.lock_person,
                                                                    label: 'Username',
                                                                    value: widget.user.email,
                                                                ),
                                                                 SizedBox(height: 6),
                                                                Container(
                                                                    margin:  EdgeInsets.symmetric(vertical: 12),
                                                                    padding:  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                    decoration: BoxDecoration(
                                                                        color: AppColors.surfaceVariant(context),
                                                                        borderRadius: BorderRadius.circular(12),
                                                                        border: Border.all(color: AppColors.border(context)),
                                                                    ),
                                                                    child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            GestureDetector(
                                                                                onTap: () {
                                                                                    setModalState(() {
                                                                                            isPasswordRequirementsExpanded = !isPasswordRequirementsExpanded;
                                                                                        });
                                                                                },
                                                                                child: Row(
                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                        Text(
                                                                                            'View Password Requirements',
                                                                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                                                                fontWeight: FontWeight.w600,
                                                                                                color: AppColors.textPrimary(context),
                                                                                            ),
                                                                                        ),
                                                                                        AnimatedRotation(
                                                                                            turns: isPasswordRequirementsExpanded ? 0.5 : 0,
                                                                                            duration: const Duration(milliseconds: 200),
                                                                                            child: const Icon(
                                                                                                Icons.expand_more,
                                                                                                color: AppColors.success,
                                                                                            ),
                                                                                        ),
                                                                                    ],
                                                                                ),
                                                                            ),
                                                                            AnimatedCrossFade(
                                                                                firstChild: const SizedBox.shrink(),
                                                                                secondChild: const Padding(
                                                                                    padding: EdgeInsets.only(top: 12.0),
                                                                                    child: Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                            _PasswordRequirementRow(text: "At least 8 characters long"),
                                                                                            _PasswordRequirementRow(text: "At least one uppercase letter"),
                                                                                            _PasswordRequirementRow(text: "At least one lowercase letter"),
                                                                                            _PasswordRequirementRow(text: "At least one number"),
                                                                                            _PasswordRequirementRow(text: "At least one special character (!@#\$%^&*)"),
                                                                                        ],
                                                                                    ),
                                                                                ),
                                                                                crossFadeState: isPasswordRequirementsExpanded
                                                                                    ? CrossFadeState.showSecond
                                                                                    : CrossFadeState.showFirst,
                                                                                duration: const Duration(milliseconds: 250),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ),

                                                                const SizedBox(height: 14),
                                                                Common.buildTextField(
                                                                    label: 'Current Password',
                                                                    icon: Icons.password_rounded,
                                                                    initialValue: currentPassword,
                                                                    onChanged: (value) => currentPassword = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter your current password'
                                                                        : null,
                                                                    context: context,
                                                                    isPassword: true,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'New Password',
                                                                    icon: Icons.password_rounded,
                                                                    initialValue: newPassword,
                                                                    onChanged: (value) => newPassword = value,
                                                                    validator: (value) {
                                                                        if (value == null || value.isEmpty) {
                                                                            return 'Please enter a new password';
                                                                        } else if (value.length < 8) {
                                                                            return 'Password must be at least 8 characters long';
                                                                        } else if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                                                            return 'Password must contain at least one uppercase letter';
                                                                        } else if (!RegExp(r'[a-z]').hasMatch(value)) {
                                                                            return 'Password must contain at least one lowercase letter';
                                                                        } else if (!RegExp(r'[0-9]').hasMatch(value)) {
                                                                            return 'Password must contain at least one number';
                                                                        } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                                                                            .hasMatch(value)) {
                                                                            return 'Password must contain at least one special character';
                                                                        }
                                                                        return null;
                                                                    },
                                                                    context: context,
                                                                    isPassword: true,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Confirm Password',
                                                                    icon: Icons.password_rounded,
                                                                    initialValue: confirmPassword,
                                                                    onChanged: (value) => confirmPassword = value,
                                                                    validator: (value) {
                                                                        if (value == null || value.isEmpty) {
                                                                            return 'Please confirm your password';
                                                                        } else if (value != newPassword) {
                                                                            return 'Passwords do not match';
                                                                        }
                                                                        return null;
                                                                    },
                                                                    context: context,
                                                                    isPassword: true,
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
                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.updateLoginDetails(
                                                                                        userId: user.id,
                                                                                        currentPassword: currentPassword,
                                                                                        newPassword: newPassword,
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
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
                                                                                        color: AppColors.onPrimary,
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

    void _showFarmDetailsBottomSheet(BuildContext context, User user,
        Farm farm, VoidCallback onCoopUpdated) async {
        final formKey = GlobalKey<FormState>();
        String farmName = farm.farmName;
        String addressLine1 = farm.address.addressLine1 ?? '';
        String addressLine2 = farm.address.addressLine2 ?? '';
        String state = farm.address.state ?? '';
        String city = farm.address.city ?? '';
        String postalCode = farm.address.postalCode ?? '';
        String country = farm.address.country ?? '';

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
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
                                                color: AppColors.surface(context),
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
                                                    'Update Farm Details',
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
                                                                const SizedBox(height: 24),

                                                                Common.buildTextField(
                                                                    label: 'Farm Name',
                                                                    icon: Icons.home_outlined,
                                                                    initialValue: farmName,
                                                                    onChanged: (value) => farmName = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter farm name'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Address Line 1',
                                                                    icon: Icons.location_on_outlined,
                                                                    initialValue: addressLine1,
                                                                    onChanged: (value) => addressLine1 = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter address line 1'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Address line 2 ',
                                                                    icon: Icons.location_on_outlined,
                                                                    initialValue: addressLine2,
                                                                    onChanged: (value) => addressLine2 = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter address line 2'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'State',
                                                                    icon: Icons.map_outlined,
                                                                    initialValue: state,
                                                                    onChanged: (value) => state = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter state'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'City',
                                                                    icon: Icons.location_city,
                                                                    initialValue: city,
                                                                    onChanged: (value) => city = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter city'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Postal Code',
                                                                    icon: Icons.email_outlined,
                                                                    initialValue: postalCode,
                                                                    onChanged: (value) => postalCode = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter postal code'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Country',
                                                                    icon: Icons.flag,
                                                                    initialValue: country,
                                                                    onChanged: (value) => country = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter country'
                                                                        : null,
                                                                    context: context,
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
                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response =
                                                                                        await service.updateFarmDetails(
                                                                                            updatedByUserId: user.id,
                                                                                            farmId: farm.id,
                                                                                            farmName: farmName,
                                                                                            farmAddressLine1: addressLine1,
                                                                                            farmAddressLine2: addressLine2,
                                                                                            farmState: state,
                                                                                            farmCity: city,
                                                                                            farmPostalCode: postalCode,
                                                                                            farmCountry: country,
                                                                                        );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
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
                                                                                        color: AppColors.onPrimary,
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

    Future<void> _showFarmDetailsDialog(BuildContext context, User user,
        Farm farm, VoidCallback onCoopUpdated) async {
        final formKey = GlobalKey<FormState>();
        String farmName = farm.farmName;
        String addressLine1 = farm.address.addressLine1 ?? '';
        String addressLine2 = farm.address.addressLine2 ?? '';
        String state = farm.address.state ?? '';
        String city = farm.address.city ?? '';
        String postalCode = farm.address.postalCode ?? '';
        String country = farm.address.country ?? '';

        showDialog(
            context: context,
            builder: (BuildContext context) {
                return StatefulBuilder(
                    builder: (context, setState) {
                        return Dialog(
                            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                            child: SizedBox(
                                width: 400,
                                child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Form(
                                        key: formKey,
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                Text(
                                                    'Update Farm Details',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(color: AppColors.adaptivePrimary(context)),
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'Farm Name',
                                                    icon: Icons.home_outlined,
                                                    initialValue: farmName,
                                                    onChanged: (value) => farmName = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter farm name'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'Address Line 1',
                                                    icon: Icons.location_on_outlined,
                                                    initialValue: addressLine1,
                                                    onChanged: (value) => addressLine1 = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter address line 1'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'Address line 2 ',
                                                    icon: Icons.location_on_outlined,
                                                    initialValue: addressLine2,
                                                    onChanged: (value) => addressLine2 = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter address line 2'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'State',
                                                    icon: Icons.map_outlined,
                                                    initialValue: state,
                                                    onChanged: (value) => state = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter state'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'City',
                                                    icon: Icons.location_city,
                                                    initialValue: city,
                                                    onChanged: (value) => city = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter city'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'Postal Code',
                                                    icon: Icons.email_outlined,
                                                    initialValue: postalCode,
                                                    onChanged: (value) => postalCode = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter postal code'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 10),
                                                Common.buildTextField(
                                                    label: 'Country',
                                                    icon: Icons.flag,
                                                    initialValue: country,
                                                    onChanged: (value) => country = value,
                                                    validator: (value) => value == null || value.isEmpty
                                                        ? 'Please enter country'
                                                        : null,
                                                    context: context,
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                        TextButton(
                                                            child: const Text(
                                                                'Cancel',
                                                                style: TextStyle(color: AppColors.error),
                                                            ),
                                                            onPressed: () => Navigator.of(context).pop(),
                                                        ),
                                                        ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                                backgroundColor: AppColors.adaptivePrimary(context),
                                                            ),
                                                            onPressed: () async {
                                                                if (formKey.currentState!.validate()) {
                                                                    final response =
                                                                        await service.updateFarmDetails(
                                                                            updatedByUserId: user.id,
                                                                            farmId: farm.id,
                                                                            farmName: farmName,
                                                                            farmAddressLine1: addressLine1,
                                                                            farmAddressLine2: addressLine2,
                                                                            farmState: state,
                                                                            farmCity: city,
                                                                            farmPostalCode: postalCode,
                                                                            farmCountry: country,
                                                                        );

                                                                    response.success
                                                                        ? _showSuccessSnackBar(
                                                                            "Personal details updated successful",
                                                                            onCoopUpdated)
                                                                        : _showErrorSnackBar(response.message);

                                                                    Navigator.of(context).pop();
                                                                }
                                                            },
                                                            child: const Text(
                                                                'Submit',
                                                                style: TextStyle(color: AppColors.onPrimary),
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
                    },
                );
            },
        );
    }

    void _showErrorSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.error),
        );
    }

    void _showSuccessSnackBar(String message, VoidCallback onCoopUpdated) {
        onCoopUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.success),
        );
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Owner Details Section
                        ProfileSection(
                            title: 'My Personal Details',
                            fields: [
                                ProfileField(
                                    icon: Icons.lock_person,
                                    label: 'Role',
                                    value:
                                    widget.user.farmOwner ? 'Farm Owner' : 'Farm Employee',
                                ),
                                ProfileField(
                                    icon: Icons.person,
                                    label: 'Name',
                                    value: widget.user.name),
                                ProfileField(
                                    icon: Icons.person,
                                    label: 'Surname',
                                    value: widget.user.surname),
                                ProfileField(
                                    icon: Icons.email,
                                    label: 'Email',
                                    value: widget.user.email),
                                ProfileField(
                                    icon: Icons.phone,
                                    label: 'Phone Number',
                                    value: widget.user.phoneNumber),
                            ],
                            onEdit: () => _showUpdateUserDetailsBottomSheet(
                                context, widget.user, widget.farm, widget.onCoopUpdated),
                            isEditEnabled: true),

                        ProfileSection(
                            title: 'Login Details',
                            fields: [
                                ProfileField(
                                    icon: Icons.lock_person,
                                    label: 'Username',
                                    value: widget.user.email),
                                const ProfileField(
                                    icon: Icons.password_outlined,
                                    label: 'Password',
                                    value: '*************************'),
                            ],
                            onEdit: () => _showLoginDetailsBottomSheet(
                                context, widget.user, widget.farm, widget.onCoopUpdated),
                            isEditEnabled: true),

                        // Farm Details Section
                        ProfileSection(
                            title: 'Farm Details',
                            fields: [
                                ProfileField(
                                    icon: Icons.home,
                                    label: 'Farm Name',
                                    value: widget.farm.farmName),
                                ProfileField(
                                    icon: Icons.location_on,
                                    label: 'Address Line 1',
                                    value: widget.farm.address.addressLine1 ??
                                        '.............................'),
                                ProfileField(
                                    icon: Icons.location_on,
                                    label: 'Address Line 2',
                                    value: widget.farm.address.addressLine2 ??
                                        '.............................'),
                                ProfileField(
                                    icon: Icons.map,
                                    label: 'State',
                                    value: widget.farm.address.state ??
                                        '.............................'),
                                ProfileField(
                                    icon: Icons.location_city,
                                    label: 'City',
                                    value: widget.farm.address.city ??
                                        '.............................'),
                                ProfileField(
                                    icon: Icons.mail_outline,
                                    label: 'Postal Code',
                                    value: widget.farm.address.postalCode ??
                                        '.............................'),
                                ProfileField(
                                    icon: Icons.flag,
                                    label: 'Country',
                                    value: widget.farm.address.country ??
                                        '.............................'),
                            ],
                            onEdit: () => _showFarmDetailsBottomSheet(
                                context, widget.user, widget.farm, widget.onCoopUpdated),
                            isEditEnabled: widget.user.farmOwner),

                        // Employees Section
                        EmployeeListSection(
                            title: 'Farm users',
                            employees: widget.farm.users.map((user) {
                                    return {
                                        'id': user.id,
                                        'name': user.name,
                                        'surname': user.surname,
                                        'formattedRoles': user.getFormattedRoles(),
                                        'roles': user.roles.toString(),
                                        'userCoopIds': user.userCoopIds.toString(),
                                    };
                                }).toList(),
                            user: widget.user,
                            farm: widget.farm,
                            onCoopUpdated: widget.onCoopUpdated,
                        ),

                        const SingleChildScrollView(
                            child: Column(
                                children: [
                                    SizedBox(height: 100), // Space at the bottom
                                ],
                            ),
                        )

                    ],
                ),
            ),
        );
    }
}

class ProfileSection extends StatelessWidget {
    final String title;
    final List<ProfileField> fields;
    final VoidCallback onEdit;
    final bool isEditEnabled;

    const ProfileSection(
    {super.key, required this.title,
        required this.fields,
        required this.onEdit,
        required this.isEditEnabled});

    @override
    Widget build(BuildContext context) {
        return Card(
            color: AppColors.surface(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(
                                    title,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.adaptivePrimary(context)),
                                ),
                                if (isEditEnabled)
                                IconButton(
                                    icon:  Icon(Icons.edit, color: AppColors.success),
                                    onPressed: onEdit,
                                ),
                            ],
                        ),
                        Divider(color: AppColors.border(context)),
                        Column(children: fields),
                    ],
                ),
            ),
        );
    }
}

class ProfileField extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;

    const ProfileField({super.key, required this.icon, required this.label, required this.value});

    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
                children: [
                    Icon(icon, color: AppColors.iconPrimary(context), size: 20),
                     SizedBox(width: 8),
                    Text(
                        "$label: ",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                    ),
                    Expanded(
                        child: Text(
                            value,
                            style: TextStyle(color: AppColors.textSecondary(context)),
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                ],
            ),
        );
    }
}

class EmployeeListSection extends StatelessWidget {
    final String title;
    final List<Map<String, String>> employees;
    final User user;
    final Farm farm;
    final VoidCallback onCoopUpdated;

    const EmployeeListSection(
    {super.key, required this.title,
        required this.employees,
        required this.user,
        required this.farm,
        required this.onCoopUpdated});

    @override
    Widget build(BuildContext context) {
        return Card(
            color: AppColors.surface(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 12.0),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(
                                    title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.adaptivePrimary(context),
                                    ),
                                ),
                                if (user.farmOwner)
                                IconButton(
                                    icon: const Icon(Icons.add_circle_outline_sharp,
                                        color: AppColors.success),
                                    onPressed: () => {
                                        _showAddUserBottomSheet(context, user, farm, onCoopUpdated)
                                    },
                                ),
                            ],
                        ),
                        Divider(color: AppColors.border(context)),
                        Column(
                            children: employees.map((employee) {
                                    String initials = (employee['name']?[0] ?? '') +
                                        (employee['surname']?[0] ?? '');



                                    return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        child: ListTile(
                                            leading: CircleAvatar(
                                                backgroundColor: AppColors.adaptivePrimary(context),
                                                radius: 24,
                                                child: Text(
                                                    initials.toUpperCase(),
                                                    style: const TextStyle(
                                                        color: AppColors.onPrimary,
                                                        fontWeight: FontWeight.bold,
                                                    ),
                                                ),
                                            ),
                                            title: Text(
                                                '${employee['name']} ${employee['surname']}',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary(context),
                                                ),
                                            ),
                                            subtitle: Text(
                                                employee['formattedRoles']!,
                                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
                                            ),
                                            trailing: user.farmOwner
                                                ? PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert,
                                                        color: AppColors.success),
                                                    onSelected: (String value) {
                                                        _handleMenuSelection(
                                                            context,
                                                            onCoopUpdated,
                                                            employee['id']!,
                                                            '${employee['name']!} ${employee['surname']!}',
                                                            employee['roles']!,
                                                            value,
                                                            farm,
                                                            employee['userCoopIds']!,
                                                        );
                                                    },
                                                    itemBuilder: (BuildContext context) => [
                                                        const PopupMenuItem(
                                                            value: 'RemoveUser',
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.delete, color: AppColors.error),
                                                                    SizedBox(width: 8),
                                                                    Text('Remove User'),
                                                                ],
                                                            ),
                                                        ),
                                                        const PopupMenuItem(
                                                            value: 'UpdateRoles',
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.edit, color: AppColors.info),
                                                                    SizedBox(width: 8),
                                                                    Text('Update Role(s)'),
                                                                ],
                                                            ),
                                                        ),
                                                        const PopupMenuItem(
                                                            value: 'UserCoops',
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.home_work_outlined, color: AppColors.primary),
                                                                    SizedBox(width: 8),
                                                                    Text('User Coop(s)'),
                                                                ],
                                                            ),
                                                        ),
                                                    ],
                                                )
                                                : null,
                                        ),
                                    );
                                }).toList(),
                        ),
                    ],
                ),
            ),
        );
    }

    void _handleMenuSelection(BuildContext context, VoidCallback onCoopUpdated,
        String userId, String employeeName, String roles, String action, Farm farm, String userCoopIds) {
        switch (action) {
            case 'UpdateRoles':
                _showUpdateRolesBottomSheet(
                    context, userId, roles, employeeName, onCoopUpdated);
                break;
            case 'RemoveUser':
                _showRemoveUserDialog(context, onCoopUpdated, userId, employeeName);
                break;
            case 'UserCoops':
                _showUserCoopsDialog(context, userId, farm, userCoopIds, employeeName, onCoopUpdated);
                break;
        }
    }

    void _showRemoveUserDialog(BuildContext context, VoidCallback onCoopUpdated,
        String userID, String employeeName) {
        PoultryPalService service = PoultryPalService();
        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: const Text("Remove user"),
                    content: Text(
                        'Are you sure you want to remove $employeeName from the farm? '
                        'This user will loose all access to the farm'),
                    actions: [
                        TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                        ),
                        TextButton(
                            child: const Text('Confirm'),
                            onPressed: () async {
                                final response = await service.removedUser(
                                    updatedByUserId: user.id,
                                    farmId: farm.id,
                                    userId: userID,
                                );

                                response.success
                                    ? _showSuccessSnackBar(
                                        "User roles updated successful", onCoopUpdated, context)
                                    : _showErrorSnackBar(response.message, context);
                                Navigator.of(context).pop();
                            },
                        ),
                    ],
                );
            },
        );
    }

    void _showUserCoopsDialog(
        BuildContext context,
        String userId,
        Farm farm,
        String strUserCoopIds,
        String employeeName,
        VoidCallback onCoopUpdated,
    ) async {
        PoultryPalService service = PoultryPalService();
        final formKey = GlobalKey<FormState>();

        List<String> userCoopIds = (strUserCoopIds.isNotEmpty && strUserCoopIds.length > 2)
            ? strUserCoopIds.substring(1, strUserCoopIds.length - 1)
                .split(',')
                .map((role) => role.trim())
                .where((id) => id.isNotEmpty)
                .toList()
            : <String>[];

        List<Coop> coops = farm.coops;

        // Pre-select existing user coops
        List<String> selectedUserCoops = List.from(userCoopIds);

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
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
                                                color: AppColors.surface(context),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                                                    'Update User Coops',
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
                                                        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                const SizedBox(height: 18),
                                                                Align(
                                                                    alignment: Alignment.centerLeft,
                                                                    child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Padding(
                                                                                padding:  EdgeInsets.only(bottom: 6),
                                                                                child: Text(
                                                                                    'Assign coops to $employeeName',
                                                                                    style: TextStyle(
                                                                                        fontSize: 16,
                                                                                        fontWeight: FontWeight.w700,
                                                                                        color: AppColors.textPrimary(context),
                                                                                    ),
                                                                                ),
                                                                            ),

                                                                            // Info note
                                                                            Container(
                                                                                decoration: BoxDecoration(
                                                                                    color: AppColors.info.withValues(alpha: 0.1),
                                                                                    borderRadius: BorderRadius.circular(10),
                                                                                    border: Border.all(
                                                                                        color: AppColors.info.withValues(alpha: 0.35),
                                                                                    ),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                                child: Row(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                        const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                                                                                        const SizedBox(width: 10),
                                                                                        Expanded(
                                                                                            child: RichText(
                                                                                                text: TextSpan(
                                                                                                    style: TextStyle(
                                                                                                        fontSize: 13,
                                                                                                        color: AppColors.textSecondary(context),
                                                                                                        height: 1.4,
                                                                                                    ),
                                                                                                    children: const [
                                                                                                        TextSpan(
                                                                                                            text: 'Note: ',
                                                                                                            style: TextStyle(
                                                                                                                fontWeight: FontWeight.w700,
                                                                                                                color: AppColors.info,
                                                                                                            ),
                                                                                                        ),
                                                                                                        TextSpan(
                                                                                                            text: 'Access is limited to the selected coops. If none are selected, the user will have no access.',
                                                                                                        ),
                                                                                                    ],
                                                                                                ),
                                                                                            ),
                                                                                        ),
                                                                                    ],
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ),

                                                                const SizedBox(height: 8),
                                                                ListView.builder(
                                                                    shrinkWrap: true,
                                                                    physics: const NeverScrollableScrollPhysics(),
                                                                    itemCount: coops.length,
                                                                    itemBuilder: (context, index) {
                                                                        final coop = coops[index];
                                                                        final isSelected = selectedUserCoops.contains(coop.id);

                                                                        return GestureDetector(
                                                                            onTap: () {
                                                                                setModalState(() {
                                                                                        if (isSelected) {
                                                                                            selectedUserCoops.remove(coop.id);
                                                                                        } else {
                                                                                            selectedUserCoops.add(coop.id);
                                                                                        }
                                                                                    });
                                                                            },
                                                                            child: Card(
                                                                                elevation: 3,
                                                                                margin:  EdgeInsets.symmetric(vertical: 8),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(16),
                                                                                    side: BorderSide(
                                                                                        color: isSelected
                                                                                            ? AppColors.adaptivePrimary(context)
                                                                                            : AppColors.border(context),
                                                                                        width: isSelected ? 1.5 : 1,
                                                                                    ),
                                                                                ),
                                                                                child: Padding(
                                                                                    padding: const EdgeInsets.all(12.0),
                                                                                    child: Row(
                                                                                        children: [
                                                                                            // Coop Image
                                                                                            ClipRRect(
                                                                                                borderRadius: BorderRadius.circular(12),
                                                                                                child:
                                                                                                ClipRRect(
                                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                                    child: Image.asset(
                                                                                                        coop.imageUrl,
                                                                                                        width: 45,
                                                                                                        height: 45,
                                                                                                        fit: BoxFit.cover,
                                                                                                    ),
                                                                                                ),

                                                                                            ),
                                                                                            const SizedBox(width: 14),

                                                                                            // Coop Info
                                                                                            Expanded(
                                                                                                child: Column(
                                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                    children: [
                                                                                                        Text(
                                                                                                            coop.coopName,
                                                                                                            style: TextStyle(
                                                                                                                fontSize: 16,
                                                                                                                fontWeight: FontWeight.w700,
                                                                                                                color: AppColors.textPrimary(context),
                                                                                                            ),
                                                                                                        ),
                                                                                                         SizedBox(height: 4),
                                                                                                        Text(
                                                                                                            "${coop.coopType.toLowerCase().capitalize()} (${coop.growthPhase.value})",
                                                                                                            style: TextStyle(
                                                                                                                fontSize: 12,
                                                                                                                color: AppColors.textSecondary(context),
                                                                                                            ),
                                                                                                            overflow: TextOverflow.ellipsis,
                                                                                                        )
                                                                                                    ],
                                                                                                ),
                                                                                            ),

                                                                                            // Checkbox
                                                                                            Checkbox(
                                                                                                value: isSelected,
                                                                                                activeColor: AppColors.adaptivePrimary(context),
                                                                                                shape: RoundedRectangleBorder(
                                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                                ),
                                                                                                onChanged: (checked) {
                                                                                                    setModalState(() {
                                                                                                            if (checked == true) {
                                                                                                                selectedUserCoops.add(coop.id);
                                                                                                            } else {
                                                                                                                selectedUserCoops.remove(coop.id);
                                                                                                            }
                                                                                                        });
                                                                                                },
                                                                                            ),
                                                                                        ],
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        );
                                                                    },
                                                                ),

                                                                const SizedBox(height: 0),

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

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.updateResponsibleUser(
                                                                                        farmId: farm.id,
                                                                                        userId: userId,
                                                                                        coopIds: selectedUserCoops,
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
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
                                                                                        color: AppColors.onPrimary,
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
                                                                                padding: const EdgeInsets.symmetric(
                                                                                    horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
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

    void _showUpdateRolesBottomSheet(
        BuildContext context,
        String userId,
        String roles,
        String employeeName,
        VoidCallback onCoopUpdated,
    ) async {
        PoultryPalService service = PoultryPalService();
        final formKey = GlobalKey<FormState>();

        List<String> selectedRoles = roles
            .substring(1, roles.length - 1)
            .split(',')
            .map((role) => role.trim())
            .where((role) => role.isNotEmpty)
            .toList();

        final availableRoles = [
        {
            "id": "ROLE_USER",
            "label": "General User",
            "icon": Icons.person_outline,
            "description": "Basic access to the system",
        },
        {
            "id": "ROLE_FARM_MANAGER",
            "label": "Farm Manager",
            "icon": Icons.manage_accounts,
            "description": "Full control of farm operations",
        },
        {
            "id": "ROLE_FARM_WORKER",
            "label": "Farm Worker",
            "icon": Icons.agriculture,
            "description": "Day-to-day coop management",
        },
        ];

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.65,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: AppColors.surface(context),
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
                                                    'Update User Roles',
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

                                        // Scrollable content
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                 SizedBox(height: 12),
                                                                Text(
                                                                    'Assign roles to $employeeName',
                                                                    style: TextStyle(
                                                                        fontSize: 15,
                                                                        fontWeight: FontWeight.w700,
                                                                        color: AppColors.textPrimary(context),
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                 // Info note
                                                                 Container(
                                                                     decoration: BoxDecoration(
                                                                         color: AppColors.info.withValues(alpha: 0.1),
                                                                         borderRadius: BorderRadius.circular(10),
                                                                         border: Border.all(
                                                                             color: AppColors.info.withValues(alpha: 0.35),
                                                                         ),
                                                                     ),
                                                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                     child: Row(
                                                                         crossAxisAlignment: CrossAxisAlignment.start,
                                                                         children: [
                                                                             const Icon(Icons.info_outline,
                                                                                 color: AppColors.info, size: 18),
                                                                             const SizedBox(width: 10),
                                                                             Expanded(
                                                                                 child: RichText(
                                                                                     text: TextSpan(
                                                                                         style: TextStyle(
                                                                                             fontSize: 13,
                                                                                             color: AppColors.textSecondary(context),
                                                                                             height: 1.4,
                                                                                         ),
                                                                                         children: const [
                                                                                             TextSpan(
                                                                                                 text: 'Note: ',
                                                                                                 style: TextStyle(
                                                                                                     fontWeight: FontWeight.w700,
                                                                                                     color: AppColors.info,
                                                                                                 ),
                                                                                             ),
                                                                                             TextSpan(
                                                                                                 text: 'The user\'s access will reflect the selected roles. At least one role must be assigned.',
                                                                                             ),
                                                                                         ],
                                                                                     ),
                                                                                 ),
                                                                             ),
                                                                         ],
                                                                     ),
                                                                 ),
                                                                const SizedBox(height: 8),

                                                                // Roles multi-select cards
                                                                ListView.builder(
                                                                    shrinkWrap: true,
                                                                    physics: const NeverScrollableScrollPhysics(),
                                                                    itemCount: availableRoles.length,
                                                                    itemBuilder: (context, index) {
                                                                        final role = availableRoles[index];
                                                                        final roleId = role["id"] as String;
                                                                        final isSelected = selectedRoles.contains(roleId);

                                                                        return GestureDetector(
                                                                            onTap: () {
                                                                                setModalState(() {
                                                                                        if (isSelected) {
                                                                                            selectedRoles.remove(roleId);
                                                                                        } else {
                                                                                            selectedRoles.add(roleId);
                                                                                        }
                                                                                    });
                                                                            },
                                                                            child: Card(
                                                                                elevation: 3,
                                                                                margin:
                                                                                 EdgeInsets.symmetric(vertical: 8),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(16),
                                                                                    side: BorderSide(
                                                                                        color: isSelected
                                                                                            ? AppColors.adaptivePrimary(context)
                                                                                            : AppColors.border(context),
                                                                                        width: isSelected ? 2 : 1,
                                                                                    ),
                                                                                ),
                                                                                child: Padding(
                                                                                    padding:  EdgeInsets.all(12.0),
                                                                                    child: Row(
                                                                                        children: [
                                                                                            Icon(role["icon"] as IconData,
                                                                                                size: 32,
                                                                                                color: isSelected
                                                                                                    ? AppColors.adaptivePrimary(context)
                                                                                                    : AppColors.textSecondary(context)),
                                                                                            const SizedBox(width: 14),
                                                                                            Expanded(
                                                                                                child: Column(
                                                                                                    crossAxisAlignment:
                                                                                                    CrossAxisAlignment.start,
                                                                                                    children: [
                                                                                                        Text(
                                                                                                            role["label"] as String,
                                                                                                            style: TextStyle(
                                                                                                                fontSize: 16,
                                                                                                                fontWeight: FontWeight.w700,
                                                                                                                color: AppColors.textPrimary(context),
                                                                                                            ),
                                                                                                        ),
                                                                                                         SizedBox(height: 4),
                                                                                                        Text(
                                                                                                            role["description"] as String,
                                                                                                            style: TextStyle(
                                                                                                                fontSize: 13,
                                                                                                                color: AppColors.textSecondary(context),
                                                                                                            ),
                                                                                                        ),
                                                                                                    ],
                                                                                                ),
                                                                                            ),
                                                                                            Checkbox(
                                                                                                value: isSelected,
                                                                                                activeColor:
                                                                                                AppColors.adaptivePrimary(context),
                                                                                                shape: RoundedRectangleBorder(
                                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                                ),
                                                                                                onChanged: (checked) {
                                                                                                    setModalState(() {
                                                                                                            if (checked == true) {
                                                                                                                selectedRoles.add(roleId);
                                                                                                            } else {
                                                                                                                selectedRoles.remove(roleId);
                                                                                                            }
                                                                                                        });
                                                                                                },
                                                                                            ),
                                                                                        ],
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        );
                                                                    },
                                                                ),

                                                                const SizedBox(height: 0),
                                                                 Row(
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
                                                                                     if (selectedRoles.isEmpty) {
                                                                                         await Common.showLottieDialog(
                                                                                             context,
                                                                                             lottiePath: 'assets/lottie/error.json',
                                                                                             message: "Please select at least one role.",
                                                                                             autoCloseAfter: const Duration(seconds: 3),
                                                                                         );
                                                                                         return;
                                                                                     }
                                                                                     await Common.showLottieDialog(
                                                                                         context,
                                                                                         lottiePath: 'assets/lottie/loading_animation.json',
                                                                                     );
                                                                                     final response = await service.updateUserRoles(
                                                                                         updatedByUserId: user.id,
                                                                                         farmId: farm.id,
                                                                                         userId: userId,
                                                                                         roles: selectedRoles,
                                                                                     );
                                                                                     if (context.mounted) {
                                                                                         Navigator.of(context, rootNavigator: true).pop();
                                                                                     }
                                                                                     if (response.success) {
                                                                                         await Common.showLottieDialog(
                                                                                             context,
                                                                                             lottiePath: 'assets/lottie/success_check.json',
                                                                                             autoCloseAfter: const Duration(seconds: 2),
                                                                                         );
                                                                                         if (context.mounted) {
                                                                                             Navigator.of(context).pop();
                                                                                         }
                                                                                         onCoopUpdated();
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
                                                                                         color: AppColors.onPrimary,
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
                                                                                 padding: const EdgeInsets.symmetric(
                                                                                     horizontal: 20, vertical: 12),
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

    void _showAddUserBottomSheet(BuildContext context, User user, Farm farm,
        VoidCallback onCoopUpdated) async {
        PoultryPalService service = PoultryPalService();
        final formKey = GlobalKey<FormState>();
        String name = '';
        String surname = '';
        String email = '';
        String phoneNumber = '';
        List<String> selectedRoles = [];
        final roles = {
            'ROLE_FARM_MANAGER': 'Farm Manager',
            'ROLE_FARM_WORKER': 'Farm Worker',
        };

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: AppColors.surface(context),
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
                                                color: AppColors.surface(context),
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
                                                    'Add Farm User',
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
                                                                const SizedBox(height: 24),

                                                                Common.buildTextField(
                                                                    label: 'Employee Name',
                                                                    icon: Icons.account_box_outlined,
                                                                    onChanged: (value) => name = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter employee name'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Employee Surname',
                                                                    icon: Icons.account_box_outlined,
                                                                    onChanged: (value) => surname = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter employee surname'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Employee Email',
                                                                    icon: Icons.mail_outlined,
                                                                    onChanged: (value) => email = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter employee email'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Employee Phone Number',
                                                                    icon: Icons.phone,
                                                                    onChanged: (value) => phoneNumber = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter employee phone number'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Align(
                                                                    alignment: Alignment.centerLeft,
                                                                    child: Padding(
                                                                        padding: EdgeInsets.fromLTRB(14, 0, 0, 0),
                                                                        child: Text(
                                                                            'Select Role(s)',
                                                                            style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: AppColors.textPrimary(context),
                                                                            ),
                                                                        ),
                                                                    ),
                                                                ),
                                                                // Use Wrap and Chip widgets to display roles more appealingly

                                                                Container(
                                                                    padding:  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                                    decoration: BoxDecoration(
                                                                        border: Border.all(color: AppColors.border(context)),
                                                                        borderRadius: BorderRadius.circular(16),
                                                                        color: AppColors.surfaceVariant(context),
                                                                        boxShadow: [
                                                                            BoxShadow(
                                                                                color: Colors.black.withOpacity(0.05),
                                                                                blurRadius: 5,
                                                                                offset: const Offset(0, 2),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                    width: double.infinity,
                                                                    child: Center(
                                                                        child: Wrap(
                                                                            alignment: WrapAlignment.center,
                                                                            spacing: 12.0,
                                                                            runSpacing: 8.0,
                                                                            children: roles.entries.map((entry) {
                                                                                    final roleKey = entry.key;
                                                                                    final roleLabel = entry.value;
                                                                                    final isSelected = selectedRoles.contains(roleKey);

                                                                                    return ChoiceChip(
                                                                                        label: Text(
                                                                                            roleLabel,
                                                                                            style: TextStyle(
                                                                                                fontWeight: FontWeight.w600,
                                                                                                color: isSelected ? Colors.white : AppColors.textPrimary(context),
                                                                                            ),
                                                                                        ),
                                                                                        selected: isSelected,
                                                                                        onSelected: (bool selected) {
                                                                                            setModalState(() {
                                                                                                    if (selected) {
                                                                                                        selectedRoles.add(roleKey);
                                                                                                    } else {
                                                                                                        selectedRoles.remove(roleKey);
                                                                                                    }
                                                                                                });
                                                                                        },
                                                                                        selectedColor: AppColors.primary,
                                                                                        backgroundColor: AppColors.border(context),
                                                                                        shape: RoundedRectangleBorder(
                                                                                            borderRadius: BorderRadius.circular(12),
                                                                                            side: BorderSide(
                                                                                                color: isSelected
                                                                                                    ? AppColors.primary
                                                                                                    : AppColors.border(context),
                                                                                            ),
                                                                                        ),
                                                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                                                    );
                                                                                }).toList(),
                                                                        ),
                                                                    ),
                                                                ),

                                                                const SizedBox(height: 6),

                                                                if (selectedRoles.isEmpty)
                                                                const Text(
                                                                    'Please select at least one role.',
                                                                    style: TextStyle(
                                                                        color: AppColors.error,
                                                                        fontWeight: FontWeight.w500,
                                                                    ),
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
                                                                                    if (!isFormValid || selectedRoles.isEmpty) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.addFarmUser(
                                                                                        addedByUserId: user.id,
                                                                                        farmId: farm.id,
                                                                                        name: name,
                                                                                        surname: surname,
                                                                                        email: email,
                                                                                        phoneNumber: phoneNumber,
                                                                                        roles: selectedRoles,
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
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
                                                                                        color: AppColors.onPrimary,
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

    void _showErrorSnackBar(String message, BuildContext context) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.error),
        );
    }

    void _showSuccessSnackBar(
        String message, VoidCallback onCoopUpdated, BuildContext context) {
        onCoopUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.success),
        );
    }
}

class _PasswordRequirementRow extends StatelessWidget {
    final String text;

    const _PasswordRequirementRow({required this.text});

    @override
    Widget build(BuildContext context) {
        return Padding(
            padding:  EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
                children: [
                    Icon(Icons.check_circle_outline, size: 18, color: AppColors.textSecondary(context)),
                     SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            text,
                            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary(context)),
                        ),
                    ),
                ],
            ),
        );
    }
}

extension StringExtension on String {
    String capitalize() {
        return "${this[0].toUpperCase()}${substring(1)}";
    }
}

