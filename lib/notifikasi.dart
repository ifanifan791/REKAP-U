import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skripsi/dashboard.dart';
import 'fitur/SemuaTransaksi.dart';
import 'package:skripsi/transaksi.dart';
import 'ProfilPage.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  int _getUnreadCount() {
    return notifications.where((n) => n['isRead'] == false).length;
  }

  Future<void> _loadNotifications() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Generate budget notifications
      await _generateBudgetNotifications(user.uid);

      // Load notifications from Firestore
      final notificationSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> loadedNotifications = [];

      for (var doc in notificationSnapshot.docs) {
        final data = doc.data();
        loadedNotifications.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'type': data['type'] ?? 'info',
          'category': data['category'] ?? '',
          'percentage': data['percentage'] ?? 0,
          'timestamp': data['timestamp'] as Timestamp,
          'isRead': data['isRead'] ?? false,
        });
      }

      setState(() {
        notifications = loadedNotifications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generateBudgetNotifications(String userId) async {
    try {
      // Get budget allocations
      Map<String, double> alokasiBudget = {};
      Map<String, double> pengeluaranAktual = {};

      // Load budget allocations
      final pendapatanSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('pendapatan')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in pendapatanSnapshot.docs) {
        final data = doc.data();
        num nominal = num.tryParse(data['nominal'].toString()) ?? 0;

        final pembagianSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('pendapatan')
            .doc(doc.id)
            .collection('pembagian')
            .get();

        for (var pembagianDoc in pembagianSnapshot.docs) {
          final pembagianData = pembagianDoc.data();
          String kategori = pembagianData['kategori'] ?? 'Lainnya';
          String persentaseStr = pembagianData['persentase'] ?? '0%';
          double persentase =
              double.tryParse(persentaseStr.replaceAll('%', '')) ?? 0;
          double nominalKategori = (persentase / 100) * nominal;

          alokasiBudget[kategori] =
              (alokasiBudget[kategori] ?? 0) + nominalKategori;
        }
      }

      // Load actual spending
      final pengeluaranSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('pengeluaran')
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in pengeluaranSnapshot.docs) {
        final data = doc.data();
        num nominal = num.tryParse(data['nominal'].toString()) ?? 0;
        String kategori = (data['kategori'] ?? 'Lainnya').toString();
        pengeluaranAktual[kategori] =
            (pengeluaranAktual[kategori] ?? 0) + nominal;
      }

      // Generate notifications for each category
      for (String kategori in alokasiBudget.keys) {
        final budget = alokasiBudget[kategori] ?? 0;
        final spent = pengeluaranAktual[kategori] ?? 0;

        if (budget > 0) {
          final percentage = (spent / budget) * 100;

          // Check for 50%, 80%, and 100% thresholds
          List<int> thresholds = [50, 80, 100];

          for (int threshold in thresholds) {
            if (percentage >= threshold) {
              await _createNotificationIfNotExists(
                userId,
                kategori,
                threshold,
                percentage,
                budget,
                spent,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating budget notifications: $e');
    }
  }

  Future<void> _createNotificationIfNotExists(
    String userId,
    String kategori,
    int threshold,
    double actualPercentage,
    double budget,
    double spent,
  ) async {
    try {
      // Check if notification already exists for this category and threshold
      final existingNotification = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('category', isEqualTo: kategori)
          .where('percentage', isEqualTo: threshold)
          .where('type', isEqualTo: 'budget_alert')
          .limit(1)
          .get();

      if (existingNotification.docs.isEmpty) {
        // Create new notification
        String title = _getBudgetAlertTitle(threshold);
        String message = _getBudgetAlertMessage(
            kategori, threshold, actualPercentage, budget, spent);
        String notificationType = _getNotificationType(threshold);

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': title,
          'message': message,
          'type': 'budget_alert',
          'category': kategori,
          'percentage': threshold,
          'actualPercentage': actualPercentage,
          'budget': budget,
          'spent': spent,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'severity': notificationType,
        });
      }
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  String _getBudgetAlertTitle(int threshold) {
    switch (threshold) {
      case 50:
        return 'Peringatan Budget 50%';
      case 80:
        return 'Peringatan Budget 80%';
      case 100:
        return 'Budget Terlampaui!';
      default:
        return 'Peringatan Budget';
    }
  }

  String _getBudgetAlertMessage(String kategori, int threshold,
      double actualPercentage, double budget, double spent) {
    String formattedBudget = budget
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    String formattedSpent = spent
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

    switch (threshold) {
      case 50:
        return 'Budget kategori $kategori telah mencapai ${actualPercentage.toStringAsFixed(1)}%. Terpakai: Rp $formattedSpent dari Rp $formattedBudget';
      case 80:
        return 'Budget kategori $kategori hampir habis! Sudah terpakai ${actualPercentage.toStringAsFixed(1)}%. Terpakai: Rp $formattedSpent dari Rp $formattedBudget';
      case 100:
        return 'Budget kategori $kategori telah terlampaui! Terpakai: Rp $formattedSpent dari budget Rp $formattedBudget';
      default:
        return 'Budget kategori $kategori memerlukan perhatian';
    }
  }

  String _getNotificationType(int threshold) {
    switch (threshold) {
      case 50:
        return 'warning';
      case 80:
        return 'urgent';
      case 100:
        return 'critical';
      default:
        return 'info';
    }
  }

  Color _getNotificationColor(String severity) {
    switch (severity) {
      case 'warning':
        return Colors.orange.shade100;
      case 'urgent':
        return Colors.red.shade100;
      case 'critical':
        return Colors.red.shade200;
      default:
        return Colors.blue.shade100;
    }
  }

  IconData _getNotificationIcon(String severity) {
    switch (severity) {
      case 'warning':
        return Icons.warning_amber;
      case 'urgent':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getNotificationIconColor(String severity) {
    switch (severity) {
      case 'warning':
        return Colors.orange;
      case 'urgent':
        return Colors.red.shade700;
      case 'critical':
        return Colors.red.shade800;
      default:
        return Colors.blue;
    }
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  List<Map<String, dynamic>> _getTodayNotifications() {
    final today = DateTime.now();
    return notifications.where((notification) {
      final notificationDate =
          (notification['timestamp'] as Timestamp).toDate();
      return notificationDate.year == today.year &&
          notificationDate.month == today.month &&
          notificationDate.day == today.day;
    }).toList();
  }

  List<Map<String, dynamic>> _getEarlierNotifications() {
    final today = DateTime.now();
    return notifications.where((notification) {
      final notificationDate =
          (notification['timestamp'] as Timestamp).toDate();
      return !(notificationDate.year == today.year &&
          notificationDate.month == today.month &&
          notificationDate.day == today.day);
    }).toList();
  }

  Future<void> _markAsRead(String notificationId) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Update local state
      setState(() {
        final index =
            notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBE6),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBE6),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      // Bottom Navigation Bar
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
          currentIndex: 3,
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransaksiPage()),
              );
            } else if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            }
          },
          // 🔻 HAPUS `const` dari sini
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
                  if (_getUnreadCount() > 0)
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
                          '${_getUnreadCount()}',
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD60A)))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFFFFD60A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Today's Notifications
                      if (_getTodayNotifications().isNotEmpty) ...[
                        const Text(
                          'Hari Ini',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._getTodayNotifications().map((notification) =>
                            _buildNotificationItem(notification)),
                        const SizedBox(height: 24),
                      ],

                      // Earlier Notifications
                      if (_getEarlierNotifications().isNotEmpty) ...[
                        const Text(
                          'Sebelumnya',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._getEarlierNotifications().map((notification) =>
                            _buildNotificationItem(notification)),
                      ],

                      // Empty State
                      if (notifications.isEmpty) ...[
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_rounded,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada notifikasi',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Notifikasi budget akan muncul di sini',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final severity = notification['severity'] ?? 'info';
    final isRead = notification['isRead'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markAsRead(notification['id']),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getNotificationColor(severity),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRead
                    ? Colors.transparent
                    : _getNotificationIconColor(severity),
                width: isRead ? 0 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNotificationIconColor(severity).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getNotificationIcon(severity),
                    color: _getNotificationIconColor(severity),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                decoration: isRead
                                    ? TextDecoration.none
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getNotificationIconColor(severity),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'],
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getTimeAgo(notification['timestamp']),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
