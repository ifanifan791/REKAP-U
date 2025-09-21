import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'pembagian.dart';

class NominalPage extends StatefulWidget {
  final String pendapatanType;
  final String? existingNominal;
  final List<Map<String, dynamic>>? existingPembagian;
  final String? pendapatanDocId;

  const NominalPage({
    super.key,
    required this.pendapatanType,
    this.existingNominal,
    this.existingPembagian,
    this.pendapatanDocId,
  });

  @override
  State<NominalPage> createState() => _NominalPageState();
}

class _NominalPageState extends State<NominalPage> {
  final TextEditingController _nominalController = TextEditingController();
  final NumberFormat _currencyFormatter = NumberFormat.decimalPattern('id');

  @override
  void initState() {
    super.initState();
    if (widget.existingNominal != null && widget.existingNominal!.isNotEmpty) {
      String formattedNominal = _currencyFormatter.format(int.tryParse(widget.existingNominal!) ?? 0);
      _nominalController.text = formattedNominal;
    }
  }

  void _onLanjutPressed() {
    if (_nominalController.text.isEmpty || _nominalController.text == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal tidak boleh kosong')),
      );
      return;
    }

    final enteredNominal = _nominalController.text.replaceAll('.', '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PembagianPage(
          nominal: enteredNominal,
          pendapatanType: widget.pendapatanType,
          existingPembagian: widget.existingPembagian,
          pendapatanDocId: widget.pendapatanDocId,
        ),
      ),
    );
  }

  void _formatNominal(String value) {
    String cleanedValue = value.replaceAll('.', '');
    if (cleanedValue.isEmpty) {
      _nominalController.text = '';
      _nominalController.selection = TextSelection.fromPosition(
        const TextPosition(offset: 0),
      );
      return;
    }

    String formattedValue = _currencyFormatter.format(int.parse(cleanedValue));
    _nominalController.value = TextEditingValue(
      text: formattedValue,
      selection: TextSelection.fromPosition(
        TextPosition(offset: formattedValue.length),
      ),
    );
  }

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nominal'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nominal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Rp.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 180,
                          child: TextFormField(
                            controller: _nominalController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: _formatNominal,
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                              hintText: 'Masukkan nominal',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: _onLanjutPressed,
                child: const Text(
                  'Lanjut',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
