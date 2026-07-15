import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/utils/validators.dart';
import 'package:smartscan/features/business_card/data/services/native_contacts_service.dart';
import 'package:smartscan/features/business_card/presentation/providers/business_card_provider.dart';

class BusinessCardEditScreen extends ConsumerStatefulWidget {
  const BusinessCardEditScreen({super.key});

  @override
  ConsumerState<BusinessCardEditScreen> createState() =>
      _BusinessCardEditScreenState();
}

class _BusinessCardEditScreenState
    extends ConsumerState<BusinessCardEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _designationController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  final List<TextEditingController> _phoneControllers = [];
  final List<TextEditingController> _emailControllers = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final card = ref.read(businessCardProvider).parsedCard;
    _nameController = TextEditingController(text: card?.fullName ?? '');
    _companyController = TextEditingController(text: card?.companyName ?? '');
    _designationController =
        TextEditingController(text: card?.designation ?? '');
    _websiteController = TextEditingController(text: card?.website ?? '');
    _addressController = TextEditingController(text: card?.address ?? '');

    final phones = card?.phoneNumbers ?? [];
    if (phones.isEmpty) {
      _phoneControllers.add(TextEditingController());
    } else {
      for (final p in phones) { _phoneControllers.add(TextEditingController(text: p)); }
    }

    final emails = card?.emailAddresses ?? [];
    if (emails.isEmpty) {
      _emailControllers.add(TextEditingController());
    } else {
      for (final e in emails) { _emailControllers.add(TextEditingController(text: e)); }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    for (final c in _phoneControllers) { c.dispose(); }
    for (final c in _emailControllers) { c.dispose(); }
    super.dispose();
  }

  void _addPhoneField() {
    setState(() {
      _phoneControllers.add(TextEditingController());
    });
  }

  void _removePhoneField(int index) {
    setState(() {
      _phoneControllers[index].dispose();
      _phoneControllers.removeAt(index);
    });
  }

  void _addEmailField() {
    setState(() {
      _emailControllers.add(TextEditingController());
    });
  }

  void _removeEmailField(int index) {
    setState(() {
      _emailControllers[index].dispose();
      _emailControllers.removeAt(index);
    });
  }

  void _updateProvider() {
    ref.read(businessCardProvider.notifier).updateCardField(
      fullName: _nameController.text.trim(),
      phoneNumbers: _phoneControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      emailAddresses: _emailControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      companyName: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
    );
  }

  Future<void> _saveToContacts() async {
    _updateProvider();

    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(businessCardProvider.notifier);
    notifier.setSaving(true);
    notifier.setError(null);

    final state = ref.read(businessCardProvider);
    final card = state.parsedCard;
    if (card == null) return;

    final contactsService = NativeContactsService();

    try {
      final isDuplicate = await contactsService.isDuplicate(card);
      if (isDuplicate && mounted) {
        notifier.setDuplicate(true);
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFDA856), size: 24),
                const SizedBox(width: 8),
                const Text('Duplicate Contact'),
              ],
            ),
            content: const Text(
              'A contact with similar name or phone number already exists in your device. Do you want to save anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        );

        if (proceed != true) {
          notifier.setSaving(false);
          return;
        }
      }

      final success = await contactsService.saveContact(card);

      if (!mounted) return;

      if (success) {
        notifier.setSaved(true);
        notifier.setSaving(false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Contact Saved!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.fullName ?? 'Contact',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.hint,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    notifier.reset();
                    context.go('/dashboard');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      } else {
        notifier.setError('Failed to save contact. Please check permissions.');
        notifier.setSaving(false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save. Check contacts permission.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      notifier.setSaving(false);
      notifier.setError('Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessCardProvider);
    final card = state.parsedCard;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Review Contact',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (card?.imagePath != null)
                _buildCardPreview(card!.imagePath!),

              const SizedBox(height: 20),

              _buildSectionHeader('PERSONAL DETAILS'),
              const SizedBox(height: 8),
              _buildInputCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter a name';
                        return null;
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildTextField(
                      controller: _designationController,
                      label: 'Designation / Title',
                      icon: Icons.work_outline_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('COMPANY'),
              const SizedBox(height: 8),
              _buildInputCard(
                child: _buildTextField(
                  controller: _companyController,
                  label: 'Company Name',
                  icon: Icons.business_rounded,
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('PHONE NUMBERS'),
              const SizedBox(height: 8),
              _buildInputCard(
                child: Column(
                  children: [
                    for (int i = 0; i < _phoneControllers.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _buildPhoneEmailRow(
                        controller: _phoneControllers[i],
                        icon: Icons.phone_rounded,
                        label: 'Phone ${i + 1}',
                        keyboardType: TextInputType.phone,
                        canRemove: _phoneControllers.length > 1,
                        onRemove: () => _removePhoneField(i),
                      ),
                    ],
                    const Divider(height: 1, color: AppColors.border),
                    InkWell(
                      onTap: _addPhoneField,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Add another number',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('EMAIL ADDRESSES'),
              const SizedBox(height: 8),
              _buildInputCard(
                child: Column(
                  children: [
                    for (int i = 0; i < _emailControllers.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _buildPhoneEmailRow(
                        controller: _emailControllers[i],
                        icon: Icons.email_outlined,
                        label: 'Email ${i + 1}',
                        keyboardType: TextInputType.emailAddress,
                        canRemove: _emailControllers.length > 1,
                        onRemove: () => _removeEmailField(i),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            return Validators.email(v);
                          }
                          return null;
                        },
                      ),
                    ],
                    const Divider(height: 1, color: AppColors.border),
                    InkWell(
                      onTap: _addEmailField,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Add another email',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('OTHER DETAILS'),
              const SizedBox(height: 8),
              _buildInputCard(
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Website',
                      icon: Icons.language_rounded,
                      keyboardType: TextInputType.url,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      icon:               Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: state.isSaving ? null : _saveToContacts,
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.contacts_rounded, size: 22),
                  label: Text(
                    state.isSaving ? 'Saving...' : 'Save to Contacts',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.hint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreview(String imagePath) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.credit_card_outlined,
                size: 48, color: AppColors.hint),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.hint,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: (_) => _updateProvider(),
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label'.toLowerCase(),
          prefixIcon: Icon(icon, color: AppColors.hint, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          labelStyle: const TextStyle(
            color: AppColors.hint,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPhoneEmailRow({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool canRemove = false,
    VoidCallback? onRemove,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: AppColors.hint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              onChanged: (_) => _updateProvider(),
              decoration: InputDecoration(
                hintText: 'Enter $label'.toLowerCase(),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.remove_circle_outline,
                    color: AppColors.error.withValues(alpha: 0.7), size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
