import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

const String _kAppName = 'Porter Driver';
const String _kTagline = 'Earn on your schedule';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  static const _bg          = Color(0xFFFFFFFF);
  static const _primary     = Color(0xFF1A1A2E);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textMuted   = Color(0xFF999999);

  late AnimationController _logoCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;

  late AnimationController _textCtrl;
  late Animation<double>   _textOpacity;
  late Animation<Offset>   _textSlide;

  late AnimationController _bottomCtrl;
  late Animation<double>   _bottomOpacity;
  late Animation<Offset>   _bottomSlide;

  late AnimationController _loaderCtrl;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl, curve: const Interval(0.0, 0.5)));

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _textCtrl, curve: Curves.easeOutCubic));

    _bottomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bottomOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _bottomCtrl, curve: Curves.easeOut));
    _bottomSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _bottomCtrl, curve: Curves.easeOutCubic));

    _loaderCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();

    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _textCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _bottomCtrl.forward();
    });

    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final ok = await Provider.of<AuthProvider>(context, listen: false).checkAuth();
    if (!mounted) return;
    if (!ok) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final profile = await ApiService.getDriverProfile();
      if (!mounted) return;
      if (profile.kycStatus != 'VERIFIED') {
  Navigator.pushReplacementNamed(context, '/kyc');
} else if (!profile.isActive) {
  Navigator.pushReplacementNamed(context, '/suspended');
} else {
  Navigator.pushReplacementNamed(context, '/home');
}
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // 401/403 handler already navigated — don't double-navigate
      if (msg.contains('Session expired') || msg.contains('suspended')) return;
      Navigator.pushReplacementNamed(context, '/kyc');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _bottomCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Centre content ────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo box
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: _buildLogoBox(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App name + tagline
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _kAppName,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _kTagline,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom loader + copyright ─────────────────
              SlideTransition(
                position: _bottomSlide,
                child: FadeTransition(
                  opacity: _bottomOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildLoader(),
                        const SizedBox(height: 18),
                        const Text(
                          '© 2025 $_kAppName',
                          style: TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoBox() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _primary.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }

  Widget _buildLoader() {
    return AnimatedBuilder(
      animation: _loaderCtrl,
      builder: (_, __) {
        final t = _loaderCtrl.value;
        double left, width;
        if (t < 0.5) {
          left  = 0;
          width = (t / 0.5) * 0.6;
        } else {
          left  = ((t - 0.5) / 0.5);
          width = 0.6 * (1 - (t - 0.5) / 0.5);
        }

        return SizedBox(
          width: 48,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(children: [
              Container(color: const Color(0xFFEBEBEB)),
              FractionallySizedBox(
                widthFactor: width.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(48 * left, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}