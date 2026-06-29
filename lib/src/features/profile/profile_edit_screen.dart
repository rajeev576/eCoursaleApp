import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'profile_screen.dart' show meProvider;

/// Native profile edit — update name, phone, bio, address via PATCH /me.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  final _address = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _bio, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(contentRepoProvider).updateProfile({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'phone_number': _phone.text.trim(),
        'bio': _bio.text.trim(),
        'comm_address': _address.text.trim(),
      });
      ref.invalidate(meProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load profile.')),
        data: (u) {
          if (!_loaded && u != null) {
            _first.text = u.firstName;
            _last.text = u.lastName;
            _phone.text = u.phone;
            _bio.text = u.bio;
            _address.text = u.address;
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(_first, 'First name', Icons.person_outline),
              const SizedBox(height: 12),
              _field(_last, 'Last name', Icons.person_outline),
              const SizedBox(height: 12),
              _field(_phone, 'Phone', Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_bio, 'Bio', Icons.info_outline, maxLines: 3),
              const SizedBox(height: 12),
              _field(_address, 'Address', Icons.home_outlined, maxLines: 2),
              const SizedBox(height: 12),
              if (u != null)
                Text('Email: ${u.email}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1, TextInputType? keyboard}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder(),
      ),
    );
  }
}
