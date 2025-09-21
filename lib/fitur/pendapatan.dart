import 'package:flutter/material.dart';
import 'nominal.dart';

class PendapatanPage extends StatefulWidget {
  final String? existingPendapatanType;
  final String? existingNominal;
  final List<Map<String, dynamic>>? existingPembagian;
  final String? pendapatanDocId;

  const PendapatanPage({
    super.key,
    this.existingPendapatanType,
    this.existingNominal,
    this.existingPembagian,
    this.pendapatanDocId,
  });

  @override
  State<PendapatanPage> createState() => _PendapatanPageState();
}

class _PendapatanPageState extends State<PendapatanPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _pendapatanOptions = ['Mingguan', 'Bulanan'];

  @override
  void initState() {
    super.initState();
    if (widget.existingPendapatanType != null && widget.existingPendapatanType!.isNotEmpty) {
      int index = _pendapatanOptions.indexOf(widget.existingPendapatanType!);
      if (index != -1) {
        _currentPage = index;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(index);
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onLanjutPressed() {
    final selectedPendapatan = _pendapatanOptions[_currentPage];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NominalPage(
          pendapatanType: selectedPendapatan,
          existingNominal: widget.existingNominal,
          existingPembagian: widget.existingPembagian,
          pendapatanDocId: widget.pendapatanDocId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPage(String title, bool isSelected) {
    return Center(
      child: Text(
        title,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.black : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pendapatan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'Pilih Jenis Pendapatan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                itemCount: _pendapatanOptions.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _buildPage(
                    _pendapatanOptions[index],
                    _currentPage == index,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                  elevation: 5,
                  shadowColor: Colors.yellow[300],
                ),
                onPressed: _onLanjutPressed,
                child: const Text(
                  'Lanjut',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
