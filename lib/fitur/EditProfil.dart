// lib/fitur/edit_profil.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfilPage extends StatefulWidget {
  const EditProfilPage({super.key});

  @override
  State<EditProfilPage> createState() => _EditProfilPageState();
}

class _EditProfilPageState extends State<EditProfilPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _namaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _namaController.text = _auth.currentUser?.displayName ?? '';
  }

  void _updateProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(_namaController.text.trim());
      await user.reload(); // Refresh data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.pop(context); // Kembali ke halaman sebelumnya
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD60A),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
