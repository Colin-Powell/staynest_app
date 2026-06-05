import 'package:flutter/material.dart';

class AddPropertyView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPublish;

  const AddPropertyView({
    super.key,
    required this.onBack,
    required this.onPublish,
  });

  @override
  State<AddPropertyView> createState() => _AddPropertyViewState();
}

class _AddPropertyViewState extends State<AddPropertyView>
    with SingleTickerProviderStateMixin {
  int _step = 1;

  // Form controllers
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedType = 'Apartment';

  static const Color _primary = Color(0xFF6366F1); // indigo — matches typical "primary" in Tailwind

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      widget.onPublish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(),
                      const SizedBox(height: 32),
                      _buildFormTitle(),
                      const SizedBox(height: 24),
                      _buildForm(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Color(0xFF111827),
                size: 24,
              ),
            ),
          ),
          // Title (centered, accounting for back button width)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 40),
              child: Text(
                'Add Property',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ───────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final stepNum = i + 1;
        final isActive = stepNum <= _step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? _primary : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Form Title ───────────────────────────────────────────────────────────

  Widget _buildFormTitle() {
    final titles = ['Basic Information', 'Property Details', 'Photos & Review'];
    return Text(
      titles[_step - 1],
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
        letterSpacing: -0.4,
      ),
    );
  }

  // ─── Form ─────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextInput(
          label: 'Property Title',
          controller: _titleController,
          placeholder: 'Enter property title',
        ),
        const SizedBox(height: 20),
        _buildDropdown(),
        const SizedBox(height: 20),
        _buildPriceInput(),
        const SizedBox(height: 20),
        _buildTextInput(
          label: 'Location',
          controller: _locationController,
          placeholder: 'Enter location',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primary.withOpacity(0.5), width: 1.5),
      ),
    );
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          decoration: _inputDecoration(hint: placeholder),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    final types = ['Apartment', 'House', 'Studio'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Property Type'),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF6B7280)),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
              items: types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Price (per month)'),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          decoration: _inputDecoration(hint: '0.00').copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 20, right: 4),
              child: Text(
                '\$',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          ),
        ),
      ],
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLastStep = _step == 3;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      child: GestureDetector(
        onTap: _handleNext,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            isLastStep ? 'Publish Property' : 'Next',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}