import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/session_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _barangay = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _barangay.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    setState(() => _error = null);
    try {
      await session.register({
        'first_name': _firstName.text.trim(),
        'middle_name': _middleName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'barangay_name': _barangay.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 12),
          TextField(
              controller: _middleName,
              decoration: const InputDecoration(labelText: 'Middle name')),
          const SizedBox(height: 12),
          TextField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Last name')),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 12),
          TextField(
              controller: _barangay,
              decoration: const InputDecoration(labelText: 'Barangay')),
          const SizedBox(height: 12),
          TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: session.isBusy ? null : _submit,
            child: Text(session.isBusy ? 'Creating account...' : 'Register'),
          ),
        ],
      ),
    );
  }
}
