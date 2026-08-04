import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SuspendedScreen extends StatefulWidget {
  const SuspendedScreen({super.key});

  @override
  State<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends State<SuspendedScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    try {
      final profile = await ApiService.getDriverProfile();
      if (!mounted) return;
      if (profile.isActive && profile.kycStatus == 'VERIFIED') {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (profile.isActive) {
        Navigator.pushReplacementNamed(context, '/kyc');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account still suspended. Contact admin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to check status. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 52,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Account Suspended',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your account has been suspended by the admin. Please contact support to resolve this issue.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checking ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Check Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text(
                  'Sign out',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
              ),
              const Spacer(),
              const Text(
                '© 2025 Porter Driver',
                style: TextStyle(
                  color: Color(0xFFCCCCCC),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
