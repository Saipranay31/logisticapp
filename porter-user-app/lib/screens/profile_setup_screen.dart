import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController    = TextEditingController();
  final _addressController = TextEditingController();
  final _nameFocus         = FocusNode();
  final _addressFocus      = FocusNode();
  bool _isLoading          = false;
  bool _nameValid          = false;

  // ── Design tokens — mirrors home_screen.dart _Theme ──────────────
  static const _bg          = Color(0xFFF5F5F7);
  static const _white       = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF888888); // gray focus ring
  static const _green       = Color(0xFF00C853);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecond  = Color(0xFF888888);
  static const _textHint    = Color(0xFFCCCCCC);
  static const _border      = Color(0xFFEBEBEB);
  static const _cardShadow  = Color(0x10000000);

  late AnimationController _animCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    _nameController.addListener(() {
      final valid = _nameController.text.trim().length >= 2;
      if (valid != _nameValid) setState(() => _nameValid = valid);
    });
    _nameFocus.addListener(() => setState(() {}));
    _addressFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _nameFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    FocusScope.of(context).unfocus();
    final name    = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty)    { _snack('Please enter your name'); return; }
    if (address.isEmpty) { _snack('Please enter your home address'); return; }

    setState(() => _isLoading = true);
    try {
      await ApiService.updateProfile(fullName: name);
      await ApiService.addAddress(
        label: 'Home', address: address, latitude: 0, longitude: 0,
      );
      if (!mounted) return;
      Provider.of<AuthProvider>(context, listen: false).updateName(name);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Something went wrong. Please try again.', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      backgroundColor: isError ? const Color(0xFFFF3B30) : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32),
                            _buildHero(),
                            const SizedBox(height: 36),
                            _buildNameField(),
                            const SizedBox(height: 16),
                            _buildAddressField(),
                            const SizedBox(height: 36),
                            _buildCTAButton(),
                            const SizedBox(height: 20),
                            _buildTerms(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(color: _cardShadow, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Step 2 of 5',
              style: TextStyle(
                color: _primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set up your\nprofile',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Quick setup — takes less than a minute',
          style: TextStyle(
            color: _textSecond,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    final focused = _nameFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('YOUR NAME'),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? _accent : _border,
              width: focused ? 1.8 : 1.5,
            ),
            boxShadow: focused
                ? [BoxShadow(
                    color: _primary.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4))]
                : const [],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.person_outline_rounded,
                  color: focused ? _primary : _textHint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    hintStyle: TextStyle(
                        color: _textHint, fontSize: 15, fontWeight: FontWeight.w400),
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              if (_nameValid)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: _green, size: 14),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    final focused = _addressFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('HOME ADDRESS'),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: focused ? _primary : _border,
              width: focused ? 1.8 : 1.5,
            ),
            boxShadow: focused
                ? [BoxShadow(
                    color: _primary.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4))]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 0, 0),
                child: Icon(Icons.location_on_outlined,
                    color: focused ? _primary : _textHint, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _addressController,
                  focusNode: _addressFocus,
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 2,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Start typing your address...',
                    hintStyle: TextStyle(
                        color: _textHint, fontSize: 15, fontWeight: FontWeight.w400),
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(0, 16, 16, 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 13, color: _textHint.withOpacity(0.9)),
            const SizedBox(width: 5),
            const Text(
              'Saved for faster booking next time',
              style: TextStyle(
                  color: _textHint, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCTAButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _completeSetup,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Continue',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.1)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildTerms() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
              color: _textHint,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.7),
          children: [
            const TextSpan(text: 'By continuing you agree to our '),
            const TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '\nand '),
            const TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );
}