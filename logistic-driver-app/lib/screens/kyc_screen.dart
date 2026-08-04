import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> with TickerProviderStateMixin {

  static const Color _primaryBlack   = Color(0xFF000000);
  static const Color _accentBlue     = Color(0xFF276EF1);
  static const Color _scaffoldBg     = Color(0xFFFFFFFF);
  static const Color _cardBg         = Color(0xFFFFFFFF);
  static const Color _cardBorder     = Color(0xFFE8E8E8);
  static const Color _activeBorder   = Color(0xFF000000);
  static const Color _inputBg        = Color(0xFFF6F6F6);
  static const Color _inputBorder    = Color(0xFFE0E0E0);
  static const Color _titleColor     = Color(0xFF000000);
  static const Color _bodyText       = Color(0xFF1A1A1A);
  static const Color _mutedText      = Color(0xFF9E9E9E);
  static const Color _iconBg         = Color(0xFFF0F0F0);
  static const Color _successGreen   = Color(0xFF22C55E);
  static const Color _amber          = Color(0xFFF59E0B);
  // FIX: selected state uses white bg with black border — no dark fill
  static const Color _selectedBg     = Color(0xFFFFFFFF);

  static const double     _appBarTitleSize  = 17.0;
  static const double     _sectionTitleSize = 22.0;
  static const double     _cardLabelSize    = 15.0;
  static const double     _cardSubSize      = 12.5;
  static const double     _btnFontSize      = 16.0;
  static const FontWeight _btnFontWeight    = FontWeight.w700;
  static const double     _cardRadius    = 14.0;
  static const double     _btnRadius     = 14.0;
  static const double     _inputRadius   = 12.0;
  static const double     _cardPadH      = 16.0;
  static const double     _cardPadV      = 16.0;
  static const double     _pagePadH      = 20.0;
  static const double     _cardSpacing   = 10.0;
  static const double     _iconSize      = 44.0;
  static const double     _btnHeight     = 54.0;
  static const double     _progressH     = 4.0;

  static List<BoxShadow> get _cardShadow => [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  int  _step = 0;
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  final _imagePicker = ImagePicker();

  File? _profileImage;
  final _nameCtrl    = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String _selectedVehicle = 'BIKE';
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleModelCtrl  = TextEditingController();

  File? _aadhaarFile;
  File? _licenseFile;
  File? _rcFile;
  File? _insuranceFile;

  Map<String, bool> _uploadProgress = {
    'AADHAAR': false, 'LICENSE': false, 'RC': false, 'INSURANCE': false,
  };

  String _kycStatus = 'PENDING';

  final _vehicles = [
    {'type': 'BIKE',       'label': 'Bike',       'emoji': '🏍', 'desc': 'Small packages, fast delivery'},
    {'type': 'AUTO',       'label': 'Auto',       'emoji': '🛺', 'desc': 'Medium loads, 3-wheeler'},
    {'type': 'MINI_TRUCK', 'label': 'Mini Truck', 'emoji': '🚛', 'desc': 'Large items, house shifting'},
    {'type': 'TRUCK',      'label': 'Truck',      'emoji': '🚚', 'desc': 'Heavy loads, commercial'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _checkKycStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).loadDriverProfile();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _licenseCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _vehicleModelCtrl.dispose();
    super.dispose();
  }

  void _animateStep(int newStep) {
    setState(() => _step = newStep);
    _animCtrl.forward(from: 0);
  }

  Future<void> _checkKycStatus() async {
    try {
      final r = await ApiService.getDriverProfile();
      setState(() => _kycStatus = r.kycStatus);
      if (_kycStatus == 'VERIFIED' || _kycStatus == 'SUBMITTED') {
        setState(() => _step = 3);
      }
    } catch (_) {}
  }

  Future<void> _pickDocument(String docType) async {
    try {
      final result = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (result != null) {
        setState(() {
          switch (docType) {
            case 'AADHAAR':  _aadhaarFile   = File(result.path); break;
            case 'LICENSE':  _licenseFile   = File(result.path); break;
            case 'RC':       _rcFile        = File(result.path); break;
            case 'INSURANCE':_insuranceFile = File(result.path); break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  Future<void> _uploadDocumentFile(String docType, File file) async {
    try {
      setState(() => _uploadProgress[docType] = true);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await ApiService.uploadDocumentFile(
        driverProfileId: auth.driverProfileId ?? '',
        documentType:    docType,
        file:            file,
      );
      setState(() => _uploadProgress[docType] = false);
    } catch (e) {
      setState(() => _uploadProgress[docType] = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: _pagePadH, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_step < 3) _buildProgressBar(),
                if (_step == 0) _buildStep0Profile(),
                if (_step == 1) _buildStep1Vehicle(),
                if (_step == 2) _buildStep2Documents(),
                if (_step == 3) _buildStep3Status(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _scaffoldBg,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      title: Text(
        _stepTitle(),
        style: const TextStyle(
          color:      _titleColor,
          fontSize:   _appBarTitleSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      leading: _step > 0 && _step < 3
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: _titleColor,
              onPressed: () => _animateStep(_step - 1),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: _cardBorder),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _progressH,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i <= _step ? _primaryBlack : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          )),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_step + 1} of 3',
          style: const TextStyle(color: _mutedText, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildStep0Profile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Your Profile', 'Add your name, license and photo'),
        const SizedBox(height: 22),
        _buildProfilePhotoPicker(),
        const SizedBox(height: 16),
        _inputField('Full Name', _nameCtrl, Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _inputField('Driver License Number', _licenseCtrl, Icons.badge_outlined),
        const SizedBox(height: 30),
        _primaryButton('Continue', () async {
          if (_nameCtrl.text.isEmpty) { _showSnack('Please enter your full name'); return; }
          if (_licenseCtrl.text.isEmpty) { _showSnack('Please enter your license number'); return; }
          setState(() => _isLoading = true);
          try {
            await ApiService.updateProfileWithLicense(
              licenseNumber: _licenseCtrl.text.trim(),
              fullName:      _nameCtrl.text.trim(),
              profilePictureFile: _profileImage,
            );
          } catch (e) {
            if (mounted) _showSnack('❌ Failed to update profile: $e');
            setState(() => _isLoading = false);
            return;
          }
          // Note: updateProfileWithLicense already syncs fullName to User entity
          // on the backend, so no need to call updateUserProfile separately.
          // (Calling /api/user/profile from a DRIVER token returns 403.)
          final auth = Provider.of<AuthProvider>(context, listen: false);
          auth.updateFullName(_nameCtrl.text.trim());
          if (mounted) {
            setState(() => _isLoading = false);
            _animateStep(1);
          }
        }),
      ],
    );
  }

  Widget _buildProfilePhotoPicker() {
    return GestureDetector(
      onTap: _showPhotoPickerSheet,
      child: Container(
        height: 150,
        width:  double.infinity,
        decoration: BoxDecoration(
          // FIX: always white so any text/icon is clearly visible
          color:        Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          border:       Border.all(
            color: _profileImage != null ? _activeBorder : _cardBorder,
            width: _profileImage != null ? 2.0 : 1.5,
          ),
        ),
        child: _profileImage == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: _inputBg, shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo_outlined, color: _primaryBlack, size: 24),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add Profile Photo',
                  style: TextStyle(color: _bodyText, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Optional · tap to upload',
                  style: TextStyle(color: _mutedText, fontSize: 12),
                ),
              ])
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_cardRadius - 2),
                    child: Image.file(_profileImage!, fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: const Text('Tap to change', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _profileImage = null),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showPhotoPickerSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(99)),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Select Photo', style: TextStyle(color: _titleColor, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              _sheetOption(icon: Icons.camera_alt_outlined, label: 'Camera', subtitle: 'Take a photo now',
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final f = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (f != null) setState(() => _profileImage = File(f.path));
                  } catch (_) {}
                }),
              Divider(height: 1, indent: 72, color: _cardBorder),
              _sheetOption(icon: Icons.photo_library_outlined, label: 'Gallery', subtitle: 'Choose from photos',
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final f = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (f != null) setState(() => _profileImage = File(f.path));
                  } catch (_) {}
                }),
              if (_profileImage != null) ...[
                Divider(height: 1, indent: 72, color: _cardBorder),
                _sheetOption(icon: Icons.delete_outline_rounded, label: 'Remove', subtitle: 'Clear current photo',
                  iconColor: Colors.red.shade400,
                  onTap: () { Navigator.pop(ctx); setState(() => _profileImage = null); }),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (iconColor ?? _primaryBlack).withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? _primaryBlack, size: 22),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _bodyText, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: _mutedText, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStep1Vehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Your Vehicle', 'Select the type you drive'),
        const SizedBox(height: 20),

        ...(_vehicles.map((v) {
          final selected = _selectedVehicle == v['type'];
          return GestureDetector(
            onTap: () => setState(() => _selectedVehicle = v['type']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(bottom: _cardSpacing),
              padding: EdgeInsets.symmetric(horizontal: _cardPadH, vertical: _cardPadV),
              decoration: BoxDecoration(
                // FIX: always white card background — selected state shown via border only
                color:        Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border:       Border.all(
                  color: selected ? _primaryBlack : _cardBorder,
                  width: selected ? 2.0 : 1.5,
                ),
                boxShadow: selected ? [] : _cardShadow,
              ),
              child: Row(children: [
                Container(
                  width: _iconSize, height: _iconSize,
                  decoration: BoxDecoration(
                    // FIX: icon box — black bg when selected (emoji is always visible), grey bg otherwise
                    color: selected ? _primaryBlack : _iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(v['emoji']!, style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v['label']!, style: TextStyle(
                    // FIX: label text always black regardless of selection
                    color:      _bodyText,
                    fontSize:   _cardLabelSize,
                    fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 2),
                  Text(v['desc']!, style: const TextStyle(color: _mutedText, fontSize: 12)),
                ])),
                AnimatedOpacity(
                  opacity: selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(color: _primaryBlack, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ]),
            ),
          );
        })).toList(),

        const SizedBox(height: 6),
        _inputField('Vehicle Number (e.g. KA01AB1234)', _vehicleNumberCtrl, Icons.confirmation_number_outlined),
        const SizedBox(height: 12),
        _inputField('Vehicle Model (optional)', _vehicleModelCtrl, Icons.directions_car_outlined),
        const SizedBox(height: 30),

        _primaryButton('Register Vehicle', () async {
          if (_vehicleNumberCtrl.text.isEmpty) { _showSnack('Enter vehicle number'); return; }
          setState(() => _isLoading = true);
          try {
            await ApiService.registerVehicle(
              vehicleType:   _selectedVehicle,
              vehicleNumber: _vehicleNumberCtrl.text.trim(),
              vehicleModel:  _vehicleModelCtrl.text.trim(),
            );
          } catch (_) {}
          setState(() => _isLoading = false);
          _animateStep(2);
        }),
      ],
    );
  }

  Widget _buildStep2Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBanner(),
        const SizedBox(height: 24),
        _sectionHeader('Required Documents', 'Upload clear photos of each document'),
        const SizedBox(height: 16),

        _buildDocCard(label: 'Driving License', subtitle: 'Valid DL — both sides',
            icon: Icons.credit_card_outlined, docType: 'LICENSE', file: _licenseFile,
            onTap: () => _pickDocument('LICENSE')),
        SizedBox(height: _cardSpacing),

        _buildDocCard(label: 'Vehicle RC', subtitle: 'Registration certificate',
            icon: Icons.description_outlined, docType: 'RC', file: _rcFile,
            onTap: () => _pickDocument('RC')),
        SizedBox(height: _cardSpacing),

        _buildDocCard(label: 'Insurance', subtitle: 'Valid insurance certificate',
            icon: Icons.shield_outlined, docType: 'INSURANCE', file: _insuranceFile,
            onTap: () => _pickDocument('INSURANCE')),
        SizedBox(height: _cardSpacing),

        _buildDocCard(label: 'Aadhaar Card', subtitle: 'Government ID proof',
            icon: Icons.badge_outlined, docType: 'AADHAAR', file: _aadhaarFile,
            onTap: () => _pickDocument('AADHAAR')),

        const SizedBox(height: 30),

        _primaryButton('Submit KYC', () async {
          if (_aadhaarFile == null || _licenseFile == null || _rcFile == null || _insuranceFile == null) {
            _showSnack('Please upload all 4 required documents');
            return;
          }
          setState(() => _isLoading = true);
          try {
            if (_aadhaarFile   != null) await _uploadDocumentFile('AADHAAR',   _aadhaarFile!);
            if (_licenseFile   != null) await _uploadDocumentFile('LICENSE',   _licenseFile!);
            if (_rcFile        != null) await _uploadDocumentFile('RC',        _rcFile!);
            if (_insuranceFile != null) await _uploadDocumentFile('INSURANCE', _insuranceFile!);
            await ApiService.submitKyc();
            setState(() { _kycStatus = 'SUBMITTED'; });
            _animateStep(3);
          } catch (e) {
            _showSnack('Error: $e');
          }
          setState(() => _isLoading = false);
        }, icon: Icons.verified_outlined),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: _primaryBlack, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Make sure all photos are clear and well-lit for faster verification.',
                style: TextStyle(color: _bodyText, fontSize: 12.5, height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _amber.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pending_outlined, color: _amber, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pending Verification',
              style: TextStyle(color: _amber, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('Upload all 4 documents to proceed',
              style: TextStyle(color: _amber.withOpacity(0.75), fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _buildDocCard({
    required String   label,
    required String   subtitle,
    required IconData icon,
    required String   docType,
    required File?    file,
    required VoidCallback onTap,
  }) {
    final isSelected  = file != null;
    final isUploading = _uploadProgress[docType] == true;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: _cardPadH, vertical: _cardPadV),
        decoration: BoxDecoration(
          // FIX: always white — selected state shown via border + icon only
          color:        Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          border:       Border.all(
            color: isSelected ? _activeBorder : _cardBorder,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected ? [] : _cardShadow,
        ),
        child: Row(children: [
          Container(
            width: _iconSize, height: _iconSize,
            decoration: BoxDecoration(
              // FIX: icon container black when selected so icon is visible; grey when not
              color:         isSelected ? _primaryBlack : _iconBg,
              borderRadius:  BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : _mutedText, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(
              // FIX: label always black — visible on white card
              color: _bodyText, fontSize: _cardLabelSize, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              isSelected ? file!.path.split('/').last : subtitle,
              style: TextStyle(
                color:    isSelected ? _primaryBlack : _mutedText,
                fontSize: _cardSubSize,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ])),

          const SizedBox(width: 10),
          if (isUploading)
            const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlack))
          else if (isSelected)
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _successGreen.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: _successGreen, size: 16),
            )
          else
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
              child: const Icon(Icons.upload_rounded, color: _mutedText, size: 16),
            ),
        ]),
      ),
    );
  }

  Widget _buildStep3Status() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: _statusColor().withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(), color: _statusColor(), size: 46),
          ),
          const SizedBox(height: 22),
          Text(_statusTitle(), style: TextStyle(
            color: _titleColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_statusDesc(), textAlign: TextAlign.center,
                style: const TextStyle(color: _mutedText, fontSize: 14, height: 1.65)),
          ),
          const SizedBox(height: 36),
          if (_kycStatus == 'VERIFIED')
            _primaryButton('Start Driving!', () => Navigator.pushReplacementNamed(context, '/home')),
          if (_kycStatus == 'REJECTED')
            _primaryButton('Re-submit KYC', () { setState(() { _step = 0; _kycStatus = 'PENDING'; }); _animCtrl.forward(from: 0); }),
          if (_kycStatus == 'SUBMITTED' || _kycStatus == 'PENDING')
            SizedBox(
              width: double.infinity,
              height: _btnHeight,
              child: OutlinedButton.icon(
                onPressed: _checkKycStatus,
                icon: const Icon(Icons.refresh_rounded, color: _primaryBlack, size: 20),
                label: const Text('Refresh Status', style: TextStyle(color: _primaryBlack, fontWeight: FontWeight.w700, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _primaryBlack, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        color: _titleColor, fontSize: _sectionTitleSize,
        fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _mutedText, fontSize: 13)),
    ]);
  }

  Widget _inputField(String hint, TextEditingController ctrl, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        // FIX: white background so typed text (black) is always visible
        color:        Colors.white,
        borderRadius: BorderRadius.circular(_inputRadius),
        border:       Border.all(color: _inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: _bodyText, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled:true,fillColor: Colors.white,
          prefixIcon: Icon(icon, color: _mutedText, size: 20),
          hintText:   hint,
          hintStyle:  const TextStyle(color: _mutedText, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap, {IconData? icon}) {
    return SizedBox(
      width:  double.infinity,
      height: _btnHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:         _primaryBlack,
          disabledBackgroundColor: _primaryBlack.withOpacity(0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: _btnFontSize,
                  fontWeight: _btnFontWeight, letterSpacing: 0.1)),
              ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _stepTitle() => switch (_step) {
    0 => 'Registration',
    1 => 'Vehicle',
    2 => 'Documents',
    3 => 'KYC Status',
    _ => 'KYC'
  };

  Color _statusColor() => switch (_kycStatus) {
    'VERIFIED'  => _successGreen,
    'SUBMITTED' => _amber,
    'REJECTED'  => const Color(0xFFDC2626),
    _           => _mutedText,
  };

  IconData _statusIcon() => switch (_kycStatus) {
    'VERIFIED'  => Icons.check_circle_rounded,
    'SUBMITTED' => Icons.hourglass_top_rounded,
    'REJECTED'  => Icons.cancel_rounded,
    _           => Icons.pending_rounded,
  };

  String _statusTitle() => switch (_kycStatus) {
    'VERIFIED'  => 'You\'re Verified!',
    'SUBMITTED' => 'Under Review',
    'REJECTED'  => 'KYC Rejected',
    _           => 'Pending',
  };

  String _statusDesc() => switch (_kycStatus) {
    'VERIFIED'  => 'Your account is verified. Go online and start accepting deliveries.',
    'SUBMITTED' => 'Documents are under review. This usually takes 24–48 hours.',
    'REJECTED'  => 'Your KYC was rejected. Please re-submit with the correct documents.',
    _           => 'Complete all steps to start earning with Porter.',
  };
}