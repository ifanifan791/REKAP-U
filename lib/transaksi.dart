import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skripsi/notifikasi.dart';
import 'dashboard.dart';
import 'fitur/SemuaTransaksi.dart';
import 'ProfilPage.dart';
import 'services/NotificationService.dart';

class TransaksiPage extends StatefulWidget {
  const TransaksiPage({super.key});

  @override
  State<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends State<TransaksiPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isPemasukan = true;
  String? selectedKategori;
  int unreadCount = 0;

  final TextEditingController nominalController = TextEditingController();
  final TextEditingController catatanController = TextEditingController();

  final List<String> kategoriPemasukan = ['Pembayaran', 'Lainnya'];
  final List<String> kategoriPengeluaran = [
    'Makanan',
    'Transportasi',
    'Lifestyle',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _simpanTransaksi() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final nominalText =
        nominalController.text.replaceAll('.', '').replaceAll(',', '');
    final nominal = num.tryParse(nominalText) ?? 0;
    final catatan = catatanController.text.trim();
    final kategori = selectedKategori;

    // Validasi jika ada field yang kosong
    if (nominalText.isEmpty || kategori == null || catatan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi semua data')),
      );
      return;
    }

    // Validasi nominal negatif atau nol
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal tidak valid')),
      );
      return;
    }

    final timestamp = Timestamp.now();
    final data = {
      'nominal': nominal,
      'nama': catatan,
      'kategori': kategori,
      'createdAt': timestamp,
      'tanggal':
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      'pendapatanType': isPemasukan ? 'pemasukan' : 'pengeluaran',
    };

    final collection = isPemasukan ? 'pendapatan' : 'pengeluaran';

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .add(data);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil disimpan')),
    );

    setState(() {
      nominalController.clear();
      catatanController.clear();
      selectedKategori = null;
    });
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadNotificationCount();
    setState(() {
      unreadCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBE6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Tambah Transaksi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0.5,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFFFFD60A),
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const SemuaTransaksiPage()),
            );
          } else if (index == 2) {
            // Jangan pakai push biasa, gunakan pushReplacement juga
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const TransaksiPage()), // ganti ke halaman tambah transaksi
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NotificationPage()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Beranda'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Transaksi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Tambah',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifikasi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle: Pemasukan - Pengeluaran
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isPemasukan = true;
                            selectedKategori = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isPemasukan
                                ? const Color(0xFFFFD60A)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pemasukan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPemasukan ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isPemasukan = false;
                            selectedKategori = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isPemasukan
                                ? const Color(0xFFFFD60A)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pengeluaran',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !isPemasukan ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Input Nominal
              TextFormField(
                controller: nominalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cleaned.isEmpty) {
                    nominalController.text = '';
                    nominalController.selection =
                        const TextSelection.collapsed(offset: 0);
                    return;
                  }

                  final number = int.parse(cleaned);
                  final formatted = NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: '',
                    decimalDigits: 0,
                  ).format(number);

                  nominalController.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Dropdown Kategori
              DropdownButtonFormField<String>(
                value: selectedKategori,
                isExpanded: true,
                items: (isPemasukan ? kategoriPemasukan : kategoriPengeluaran)
                    .map((kategori) => DropdownMenuItem<String>(
                          value: kategori,
                          child: Row(
                            children: [
                              Icon(
                                kategori == 'Makanan'
                                    ? Icons.fastfood
                                    : kategori == 'Transportasi'
                                        ? Icons.directions_bus
                                        : kategori == 'Lifestyle'
                                            ? Icons.shopping_bag
                                            : Icons.category,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(kategori),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedKategori = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Catatan
              TextFormField(
                controller: catatanController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Catatan',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tombol Simpan
              ElevatedButton(
                onPressed: _simpanTransaksi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD60A),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
