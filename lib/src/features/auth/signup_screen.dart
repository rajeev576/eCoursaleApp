import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';

/// Native signup. Auto-selects the mode from the backend:
///  - phone-OTP signup when SMS is configured (bot-resistant, no captcha);
///  - else direct email/password signup (the "normal way", works immediately).
/// Fully native — no webview.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool? _otpEnabled; // null = loading
  bool _loading = false;
  bool _otpSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMode() async {
    final enabled = await ref.read(authRepoProvider).signupOtpEnabled();
    if (mounted) setState(() => _otpEnabled = enabled);
  }

  void _onAuthed() {
    ref.invalidate(hasSessionProvider);
    ref.invalidate(schoolConfigProvider);
    if (mounted) context.go('/home');
  }

  Future<void> _submitDirect() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepoProvider).signupDirect(
            firstName: _first.text.trim(), lastName: _last.text.trim(),
            email: _email.text.trim(), phone: _phone.text.trim(),
            password: _password.text,
          );
      _onAuthed();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sent = await ref.read(authRepoProvider).signupRequestOtp(
            firstName: _first.text.trim(), lastName: _last.text.trim(),
            phone: _phone.text.trim(), email: _email.text.trim(),
            password: _password.text,
          );
      if (!sent) {
        // OTP turned off server-side between load and submit → fall back.
        setState(() => _otpEnabled = false);
      } else {
        setState(() => _otpSent = true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepoProvider).signupVerifyOtp(_phone.text.trim(), _otp.text.trim());
      _onAuthed();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: _otpEnabled == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _otpSent ? _otpStep() : _formStep(),
                ),
              ),
            ),
    );
  }

  Widget _formStep() {
    final otp = _otpEnabled == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Join ${AppConfig.appName}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _field(_first, 'First name', Icons.person_outline)),
          const SizedBox(width: 10),
          Expanded(child: _field(_last, 'Last name', Icons.person_outline)),
        ]),
        const SizedBox(height: 12),
        if (otp) ...[
          _field(_phone, 'Phone number', Icons.phone_outlined, keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _field(_email, 'Email (optional)', Icons.email_outlined, keyboard: TextInputType.emailAddress),
        ] else ...[
          _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(_phone, 'Phone (optional)', Icons.phone_outlined, keyboard: TextInputType.phone),
        ],
        const SizedBox(height: 12),
        _field(_password, 'Password (min 6)', Icons.lock_outline, obscure: true),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _loading ? null : (otp ? _requestOtp : _submitDirect),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(otp ? 'Send OTP' : 'Create account'),
        ),
        const SizedBox(height: 14),
        Center(child: TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign in'))),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verify your phone',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('We sent a code to ${_phone.text.trim()}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        _field(_otp, 'Enter OTP', Icons.sms_outlined, keyboard: TextInputType.number),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify & create account'),
        ),
        TextButton(onPressed: _loading ? null : _requestOtp, child: const Text('Resend OTP')),
        TextButton(onPressed: () => setState(() => _otpSent = false), child: const Text('Change details')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon),
        isDense: true,
      ),
    );
  }
}
