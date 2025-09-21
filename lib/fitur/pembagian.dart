import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard.dart';

class PembagianPage extends StatefulWidget {
  final String pendapatanType;
  final String nominal;
  final List<Map<String, dynamic>>? existingPembagian;
  final String? pendapatanDocId;

  const PembagianPage({
    super.key,
    required this.pendapatanType,
    required this.nominal,
    this.existingPembagian,
    this.pendapatanDocId,
  });

  @override
  State<PembagianPage> createState() => _PembagianPageState();
}

class _PembagianPageState extends State<PembagianPage> {
  List<PembagianItem> pembagianList = [];

  final List<String> kategoriList = ['Transportasi', 'Makanan', 'Lifestyle', 'Lainnya'];
  final List<String> persentaseList = ['25', '30', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    if (widget.existingPembagian != null && widget.existingPembagian!.isNotEmpty) {
      pembagianList = widget.existingPembagian!.map((data) {
        return PembagianItem(
          kategori: data['kategori'],
          persentase: data['persentase'],
        );
      }).toList();
    } else {
      pembagianList = [PembagianItem()];
    }
  }

  void _addPembagian() {
    setState(() {
      pembagianList.add(PembagianItem());
    });
  }

  void _savePembagian() async {
    int totalPersentase = 0;

    for (var item in pembagianList) {
      int persen = 0;
      if (item.persentase == 'Lainnya') {
        persen = int.tryParse(item.persentaseLainnya ?? '0') ?? 0;
      } else {
        persen = int.tryParse(item.persentase?.replaceAll('%', '') ?? '0') ?? 0;
      }
      totalPersentase += persen;
    }

    if (totalPersentase > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total persentase tidak boleh lebih dari 100%')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user != null) {
      final pendapatanRef = widget.pendapatanDocId != null
          ? firestore.collection('users').doc(user.uid).collection('pendapatan').doc(widget.pendapatanDocId)
          : firestore.collection('users').doc(user.uid).collection('pendapatan').doc();

      await pendapatanRef.set({
        'pendapatanType': widget.pendapatanType,
        'nominal': widget.nominal,
        'createdAt': Timestamp.now(),
      });

      final pembagianRef = pendapatanRef.collection('pembagian');

      // Delete existing pembagian documents if editing
      if (widget.pendapatanDocId != null) {
        final existingPembagianDocs = await pembagianRef.get();
        for (var doc in existingPembagianDocs.docs) {
          await doc.reference.delete();
        }
      }

      for (var item in pembagianList) {
        String kategori = item.kategori == 'Lainnya' ? (item.kategoriLainnya ?? 'Lainnya') : (item.kategori ?? '');
        String persentase = item.persentase == 'Lainnya' ? (item.persentaseLainnya ?? '0') + '%' : (item.persentase ?? '0%');

        await pembagianRef.add({
          'kategori': kategori,
          'persentase': persentase,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembagian berhasil disimpan')),
      );

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pembagian'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pembagian', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pembagianList.length,
                itemBuilder: (context, index) {
                  return PembagianForm(
                    kategoriList: kategoriList,
                    persentaseList: persentaseList,
                    pembagianItem: pembagianList[index],
                    onChanged: (kategori, persentase) {
                      setState(() {
                        pembagianList[index].kategori = kategori;
                        pembagianList[index].persentase = persentase;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _addPembagian,
                child: const Text('Tambah Pembagian'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _savePembagian,
                child: const Text('Simpan Semua'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PembagianItem {
  String? kategori;
  String? persentase;
  String? kategoriLainnya;
  String? persentaseLainnya;

  PembagianItem({this.kategori, this.persentase, this.kategoriLainnya, this.persentaseLainnya});
}

class PembagianForm extends StatelessWidget {
  final List<String> kategoriList;
  final List<String> persentaseList;
  final PembagianItem pembagianItem;
  final Function(String?, String?) onChanged;

  const PembagianForm({
    super.key,
    required this.kategoriList,
    required this.persentaseList,
    required this.pembagianItem,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori :', style: TextStyle(fontSize: 16)),
          DropdownButtonFormField<String>(
            value: pembagianItem.kategori,
            hint: const Text('Pilih Kategori'),
            items: kategoriList.map((kategori) {
              return DropdownMenuItem<String>(
                value: kategori,
                child: Text(kategori),
              );
            }).toList(),
            onChanged: (value) {
              pembagianItem.kategoriLainnya = null;
              onChanged(value, pembagianItem.persentase);
            },
            decoration: const InputDecoration(border: UnderlineInputBorder()),
          ),
          if (pembagianItem.kategori == 'Lainnya') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: pembagianItem.kategoriLainnya,
              onChanged: (value) {
                pembagianItem.kategoriLainnya = value;
              },
              decoration: const InputDecoration(hintText: 'Masukkan Kategori'),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Persentase :', style: TextStyle(fontSize: 16)),
          DropdownButtonFormField<String>(
            value: pembagianItem.persentase,
            hint: const Text('Pilih Persentase'),
            items: [
              if (pembagianItem.persentase != null && !persentaseList.contains(pembagianItem.persentase))
                DropdownMenuItem<String>(
                  value: pembagianItem.persentase,
                  child: Text(pembagianItem.persentase!),
                ),
              ...persentaseList.map((persentase) {
                return DropdownMenuItem<String>(
                  value: persentase,
                  child: Text(persentase),
                );
              }).toList(),
            ],
            onChanged: (value) {
              pembagianItem.persentaseLainnya = null;
              onChanged(pembagianItem.kategori, value);
            },
            decoration: const InputDecoration(border: UnderlineInputBorder()),
          ),
          if (pembagianItem.persentase == 'Lainnya') ...[
            const SizedBox(height: 8),
            TextFormField(
              initialValue: pembagianItem.persentaseLainnya,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                pembagianItem.persentaseLainnya = value;
              },
              decoration: const InputDecoration(hintText: 'Masukkan Persentase (%)'),
            ),
          ],
        ],
      ),
    );
  }
}
