import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'fitur/SemuaTransaksi.dart';
import 'transaksi.dart';
import 'notifikasi.dart';
import 'ProfilPage.dart';
import 'services/NotificationService.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  num totalPemasukan = 0;
  num totalPengeluaran = 0;
  num saldo = 0;
  String userName = 'User';
  int unreadCount = 0;

  List<Map<String, dynamic>> transaksiList = [];
  Map<String, double> kategoriDistribusi = {};
  Map<String, double> pengeluaranAktual = {};
  Map<String, double> alokasiBudget = {};

@override
void initState() {
  super.initState();
  checkAndResetBudget(); // Cek dan reset otomatis jika waktunya
}

void checkAndResetBudget() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final uid = user.uid;
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('periode')
      .doc('data')
      .get();

  if (!snapshot.exists) return;

  final data = snapshot.data()!;
  final lastReset = (data['lastReset'] as Timestamp).toDate();
  final selectedPeriod = data['periode']; // "Mingguan" / "Bulanan"
  final now = DateTime.now();

  bool shouldReset = false;

  if (selectedPeriod == 'Mingguan') {
    shouldReset = now.difference(lastReset).inDays >= 7;
  } else if (selectedPeriod == 'Bulanan') {
    shouldReset = now.month != lastReset.month || now.year != lastReset.year;
  }

  if (shouldReset) {
    await performReset(uid);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('periode')
        .doc('data')
        .update({'lastReset': Timestamp.now()});
  }
}

Future<void> performReset(String uid) async {
  final firestore = FirebaseFirestore.instance;

  // Gunakan set dengan merge untuk membuat dokumen jika belum ada
  await firestore.collection('users').doc(uid).set({
    'saldo': 0,
  }, SetOptions(merge: true));

  // Hapus data pemasukan
  final pemasukan = await firestore.collection('users').doc(uid).collection('pemasukan').get();
  for (var doc in pemasukan.docs) {
    await doc.reference.delete();
  }

  // Hapus data pengeluaran
  final pengeluaran = await firestore.collection('users').doc(uid).collection('pengeluaran').get();
  for (var doc in pengeluaran.docs) {
    await doc.reference.delete();
  }
}


Future<void> resetAnggaran() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Panggil fungsi performReset untuk menghapus data transaksi dan budget
    await performReset(uid);

    // Reset nilai total di dokumen user (jika masih diperlukan, performReset sudah mereset saldo)
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'totalPemasukan': 0, // Ini mungkin tidak lagi diperlukan jika data pemasukan dihapus
      'totalPengeluaran': 0, // Ini mungkin tidak lagi diperlukan jika data pengeluaran dihapus
      'saldo': 0, // performReset sudah mereset saldo
    }, SetOptions(merge: true));

    // Hapus koleksi 'budget' jika ada (performReset sudah menghapus 'pembagian_budget')
    // Jika 'budget' dan 'pembagian_budget' adalah hal yang sama, salah satunya bisa dihapus.
    // Berdasarkan kode Anda, 'pembagian_budget' dihapus di performReset,
    // dan 'budget' dihapus di resetAnggaran. Pastikan mana yang relevan.
    final budgetCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('budget');

    final budgetSnapshot = await budgetCollection.get();
    for (var doc in budgetSnapshot.docs) {
      await doc.reference.delete();
    }

    setState(() {
      totalPemasukan = 0;
      totalPengeluaran = 0;
      saldo = 0;
      alokasiBudget = {};
      transaksiList = []; // Tambahkan ini untuk mereset tampilan transaksi
      kategoriDistribusi = {}; // Tambahkan ini untuk mereset tampilan distribusi
      pengeluaranAktual = {}; // Tambahkan ini untuk mereset tampilan pengeluaran aktual
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anggaran berhasil direset.')),
    );
  } catch (e) {
    print('Error saat reset anggaran: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal reset anggaran.')),
    );
  }
}


  // Perbaikan untuk load dashboard data dengan error handling yang lebih baik
Future<void> _loadDashboardData() async {
  try {
    final User? user = _auth.currentUser;
    if (user == null) {
      debugPrint('User tidak terautentikasi');
      return;
    }

    // Load user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      setState(() {
        userName = userDoc.data()?['name'] ?? 'User';
      });
    }

    // Load data secara paralel untuk performa yang lebih baik
    await Future.wait([
      _loadPemasukanDanPembagian(),
      _loadPengeluaranAktual(),
      _loadTransaksiHistory(),
      _loadUnreadCount(),
    ]);

    debugPrint('Dashboard data loaded successfully');
  } catch (e) {
    debugPrint('Error loading dashboard data: $e');
    // Tampilkan error kepada user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memuat data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadNotificationCount();
    setState(() {
      unreadCount = count;
    });
  }

  Future<void> _loadPemasukanDanPembagian() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final pendapatanSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pendapatan')
        .orderBy('createdAt', descending: true)
        .get();

    num totalPendapatan = 0;
    Map<String, double> totalAlokasi = {};
    Map<String, double> kategoriPersentase = {};

    for (var doc in pendapatanSnapshot.docs) {
      final data = doc.data();
      num nominal = num.tryParse(data['nominal'].toString()) ?? 0;
      totalPendapatan += nominal;

      // Ambil data pembagian untuk setiap pendapatan
      final pembagianSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pendapatan')
          .doc(doc.id)
          .collection('pembagian')
          .get();

      for (var pembagianDoc in pembagianSnapshot.docs) {
        final pembagianData = pembagianDoc.data();
        String kategori = pembagianData['kategori'] ?? 'Lainnya';
        String persentaseStr = pembagianData['persentase'] ?? '0%';

        // Parse persentase (hapus simbol %)
        double persentase =
            double.tryParse(persentaseStr.replaceAll('%', '')) ?? 0;

        // Hitung nominal untuk kategori ini
        double nominalKategori = (persentase / 100) * nominal;

        totalAlokasi[kategori] =
            (totalAlokasi[kategori] ?? 0) + nominalKategori;
      }
    }

    // Hitung persentase untuk grafik berdasarkan total alokasi
    final totalAlokasiSum =
        totalAlokasi.values.fold(0.0, (sum, value) => sum + value);

    if (totalAlokasiSum > 0) {
      totalAlokasi.forEach((kategori, nominalKategori) {
        kategoriPersentase[kategori] = nominalKategori / totalAlokasiSum;
      });
    }

    setState(() {
      totalPemasukan = totalPendapatan;
      kategoriDistribusi = kategoriPersentase;
      alokasiBudget = totalAlokasi;
    });
  }

  Future<void> _loadPengeluaranAktual() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      final pengeluaranSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pengeluaran')
          .orderBy('createdAt', descending: true)
          .get();

      Map<String, double> actualSpending = {};
      num totalPengeluaranAktual = 0;

      for (var doc in pengeluaranSnapshot.docs) {
        final data = doc.data();
        num nominal = num.tryParse(data['nominal'].toString()) ?? 0;
        String kategori = (data['kategori'] ?? 'Lainnya').toString();

        totalPengeluaranAktual += nominal;
        actualSpending[kategori] = (actualSpending[kategori] ?? 0) + nominal;
      }

      setState(() {
        totalPengeluaran = totalPengeluaranAktual;
        pengeluaranAktual = actualSpending;
        saldo = totalPemasukan - totalPengeluaranAktual;
      });
    } catch (e) {
      debugPrint('Error loading pengeluaran: $e');
      setState(() {
        totalPengeluaran = 0;
        saldo = totalPemasukan;
      });
    }
  }

  Future<void> _loadTransaksiHistory() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> transaksi = [];

    // Tambahkan transaksi pendapatan
    final pendapatanSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pendapatan')
        .orderBy('createdAt', descending: true)
        .get();

    for (var doc in pendapatanSnapshot.docs) {
      final data = doc.data();
      num nominal = num.tryParse(data['nominal'].toString()) ?? 0;

      transaksi.add({
        'nama': 'Pendapatan ${data['pendapatanType'] ?? 'Mingguan'}',
        'tanggal': _formatDate(data['createdAt']),
        'nominal': nominal,
        'jenis': 'pemasukan',
        'icon': Icons.account_balance_wallet,
        'timestamp': data['createdAt'],
      });
    }

    // Tambahkan transaksi pengeluaran
    try {
      final pengeluaranSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pengeluaran')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in pengeluaranSnapshot.docs) {
        final data = doc.data();
        num nominal = num.tryParse(data['nominal'].toString()) ?? 0;
        String kategori = (data['kategori'] ?? 'Lainnya').toString();

        transaksi.add({
          'nama': data['nama'] ?? 'Pengeluaran',
          'tanggal': _formatDate(data['createdAt']),
          'nominal': nominal,
          'jenis': 'pengeluaran',
          'icon': _getIconForCategory(kategori),
          'timestamp': data['createdAt'],
        });
      }
    } catch (e) {
      debugPrint('Error loading pengeluaran for history: $e');
    }

    // Urutkan berdasarkan timestamp dan ambil 4 terakhir
    transaksi.sort((a, b) {
      final timestampA = a['timestamp'] as Timestamp?;
      final timestampB = b['timestamp'] as Timestamp?;

      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;

      return timestampB.compareTo(timestampA);
    });

    setState(() {
      transaksiList = transaksi.take(4).toList();
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }

  IconData _getIconForCategory(String kategori) {
    switch (kategori.toLowerCase()) {
      case 'transportasi':
        return Icons.directions_car;
      case 'makanan':
        return Icons.restaurant;
      case 'lifestyle':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'kesehatan':
        return Icons.local_hospital;
      case 'belanja':
        return Icons.shopping_cart;
      case 'tabungan':
        return Icons.savings;
      default:
        return Icons.category;
    }
  }

  Color _getColorForUsage(double usage) {
    if (usage >= 0.8) {
      return const Color(0xFFEF4444); // Merah
    } else if (usage >= 0.5) {
      return Colors.orange; // Kuning
    } else {
      return const Color(0xFF10B981); // Hijau
    }
  }

  bool _isOverBudget(String kategori) {
    final budget = alokasiBudget[kategori] ?? 0;
    final spent = pengeluaranAktual[kategori] ?? 0;
    return spent > budget && budget > 0;
  }

  double _getBudgetUsagePercentage(String kategori) {
    final budget = alokasiBudget[kategori] ?? 0;
    final spent = pengeluaranAktual[kategori] ?? 0;
    if (budget == 0) return 0;
    return (spent / budget).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBE6),

      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFFD60A),
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          elevation: 0,
          onTap: (index) {
            if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const SemuaTransaksiPage()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransaksiPage()),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationPage()),
              );
            } else if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Transaksi',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_rounded),
              label: 'Tambah',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_rounded),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
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
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),

      // Main Body
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: Colors.yellow,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD60A), Color(0xFFFFC107)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hai, $userName! 👋',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Selamat datang kembali',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
  onPressed: () async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Anggaran'),
        content: const Text('Apakah kamu yakin ingin mereset anggaran?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
        ],
      ),
    );

    if (confirm == true) {
      await resetAnggaran(); // atau "bulanan" sesuai logika aplikasi
      await _loadDashboardData(); // agar data terbaru dimuat ulang
    }
  },
  child: const Text('Reset Anggaran'),
)


                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Saldo Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo Tersisa',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rp ${saldo.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: saldo >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Pemasukan dan Pengeluaran Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Pemasukan',
                          icon: Icons.trending_up_rounded,
                          amount: totalPemasukan,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Pengeluaran',
                          icon: Icons.trending_down_rounded,
                          amount: totalPengeluaran,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Distribusi Budget (Rencana Pembagian)
                if (kategoriDistribusi.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pembagian Budget',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(20),
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
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: kategoriDistribusi.entries.map((entry) {
                              final kategori = entry.key;
                              final persentase = entry.value;
                              final isOverBudget = _isOverBudget(kategori);
                              final budgetUsage =
                                  _getBudgetUsagePercentage(kategori);

                              return _buildKategoriCard(kategori, persentase,
                                  isOverBudget, budgetUsage);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Transaksi Terakhir
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transaksi Terakhir',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SemuaTransaksiPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Lihat Semua',
                              style: TextStyle(
                                color: Color(0xFFFFD60A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                        child: Column(
                          children: [
                            if (transaksiList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Belum ada transaksi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...transaksiList.asMap().entries.map((entry) {
                                final index = entry.key;
                                final transaksi = entry.value;
                                final isLast =
                                    index == transaksiList.length - 1;

                                return _buildTransaksiItem(
                                  transaksi['icon'],
                                  transaksi['nama'],
                                  transaksi['tanggal'],
                                  transaksi['jenis'] == 'pengeluaran'
                                      ? '-${transaksi['nominal'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}'
                                      : '+${transaksi['nominal'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                  transaksi['jenis'],
                                  isLast,
                                );
                              }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required num amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriCard(
    String kategori,
    double persentase,
    bool isOverBudget,
    double budgetUsage,
  ) {
    final budgetAmount = alokasiBudget[kategori] ?? 0;
    final spentAmount = pengeluaranAktual[kategori] ?? 0;
    final color = _getColorForUsage(budgetUsage);

    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding from 16 to 12
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Add this to minimize space usage
        children: [
          // Circular progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 45, // Reduced from 50 to 45
                width: 45, // Reduced from 50 to 45
                child: CircularProgressIndicator(
                  value: budgetUsage,
                  strokeWidth: 3, // Reduced from 4 to 3
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: Colors.grey[300],
                ),
              ),
              Text(
                '${(budgetUsage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11, // Reduced from 12 to 11
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8 to 6

          // Nama Kategori
          Text(
            kategori,
            style: const TextStyle(
              fontSize: 11, // Reduced from 12 to 11
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3), // Reduced from 4 to 3

          // Budget yang dialokasikan
          Text(
            'Budget: Rp ${budgetAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
            style: const TextStyle(
              fontSize: 9, // Reduced from 10 to 9
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Jumlah yang telah dipakai
          if (spentAmount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Terpakai: Rp ${spentAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
              style: TextStyle(
                fontSize: 9, // Reduced from 10 to 9
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Progress bar horizontal
          if (budgetAmount > 0) ...[
            const SizedBox(height: 3), // Reduced from 4 to 3
            Container(
              height: 3, // Reduced from 4 to 3
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: budgetUsage,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransaksiItem(
    IconData icon,
    String title,
    String date,
    String amount,
    String jenis,
    bool isLast,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.grey[100]!,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: jenis == 'pengeluaran'
                  ? const Color(0xFFEF4444).withOpacity(0.1)
                  : const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: jenis == 'pengeluaran'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rp $amount',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: jenis == 'pengeluaran'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}
