import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skripsi/dashboard.dart';
import 'package:skripsi/transaksi.dart';
import 'package:skripsi/notifikasi.dart';
import 'package:skripsi/ProfilPage.dart';
import 'package:skripsi/services/NotificationService.dart';

class SemuaTransaksiPage extends StatefulWidget {
  const SemuaTransaksiPage({super.key});

  @override
  State<SemuaTransaksiPage> createState() => _SemuaTransaksiPageState();
}

class _SemuaTransaksiPageState extends State<SemuaTransaksiPage> {
  String selectedFilter = 'Semua';
  final List<String> filterOptions = ['Semua', 'Pemasukan', 'Pengeluaran'];

  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    fetchUnreadNotifications();
  }

  void fetchUnreadNotifications() async {
    final count = await NotificationService.getUnreadNotificationCount();
    setState(() {
      unreadCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFBE6),
        body: const Center(
          child: Text(
            "Silakan login terlebih dahulu",
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      );
    }

    final pendapatanRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pendapatan');
    final pengeluaranRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pengeluaran');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBE6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Semua Transaksi',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: 1,
        selectedItemColor: const Color(0xFFFFD60A),
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const DashboardPage()));
          } else if (i == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransaksiPage()));
          } else if (i == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationPage()));
          } else if (i == 4) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfilePage()));
          }
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Transaksi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_rounded), label: 'Tambah'),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: (() async* {
          final pendapatanSnap = await pendapatanRef.get();
          final pengeluaranSnap = await pengeluaranRef.get();

          List<Map<String, dynamic>> items = [];

          for (var doc in pendapatanSnap.docs) {
            final d = doc.data();
            items.add({
              'nama': d['nama'] ?? 'Pemasukan',
              'tanggal': d['tanggal'] ?? '',
              'nominal': double.tryParse(d['nominal'].toString()) ??
                  0.0, // Ensure nominal is a number
              'jenis': 'pemasukan',
              'icon': Icons.account_balance_wallet_rounded,
            });
          }

          for (var doc in pengeluaranSnap.docs) {
            final d = doc.data();
            items.add({
              'nama': d['nama'] ?? 'Pengeluaran',
              'tanggal': d['tanggal'] ?? '',
              'nominal': double.tryParse(d['nominal'].toString()) ??
                  0.0, // Ensure nominal is a number
              'jenis': 'pengeluaran',
              'icon': _getIconForCategory(d['kategori'] ?? 'Lainnya'),
            });
          }

          items.sort((a, b) =>
              (b['tanggal'] as String).compareTo(a['tanggal'] as String));
          yield items;
        })(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD60A)),
              ),
            );
          }

          final allItems = snapshot.data!;
          final filteredItems = allItems.where((item) {
            if (selectedFilter == 'Semua') return true;
            return item['jenis'] == selectedFilter.toLowerCase();
          }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter Transaksi',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937))),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filterOptions.map((option) {
                          final isSelected = selectedFilter == option;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedFilter = option;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFD60A)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFFD60A)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      option == 'Semua'
                                          ? Icons.all_inclusive_rounded
                                          : option == 'Pemasukan'
                                              ? Icons.trending_up_rounded
                                              : Icons.trending_down_rounded,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // List transaksi
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.receipt_long_rounded,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Belum ada data untuk ditampilkan',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final jenis = item['jenis'] as String;
                          final nominal = item['nominal'];
                          final isPengeluaran = jenis == 'pengeluaran';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isPengeluaran
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.1)
                                        : const Color(0xFF10B981)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item['icon'],
                                    size: 24,
                                    color: isPengeluaran
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['nama'],
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTanggal(item['tanggal']),
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isPengeluaran
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.1)
                                        : const Color(0xFF10B981)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isPengeluaran
                                        ? '-Rp ${_formatRupiah(nominal)}'
                                        : '+Rp ${_formatRupiah(nominal)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isPengeluaran
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTanggal(String tanggalStr) {
    try {
      final tanggal = DateTime.parse(tanggalStr);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(tanggal);
    } catch (e) {
      return tanggalStr;
    }
  }

  String _formatRupiah(dynamic nominal) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    return formatter.format(nominal);
  }

  IconData _getIconForCategory(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'transportasi':
        return Icons.directions_car_rounded;
      case 'makanan':
        return Icons.restaurant_rounded;
      case 'lifestyle':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'kesehatan':
        return Icons.local_hospital_rounded;
      case 'belanja':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
