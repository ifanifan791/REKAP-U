import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skripsi/login/halaman_login.dart';

class HalamanSplashScreen extends StatefulWidget {
  const HalamanSplashScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HalamanSplashScreenState();
}

class _HalamanSplashScreenState extends State<HalamanSplashScreen> {
  startSplashScreen() async {
    var duration = const Duration(seconds: 4);
    return Timer(duration, () async {
      SharedPreferences spInstance = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    startSplashScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Menggunakan MediaQuery untuk mendapatkan ukuran layar
    Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gambar akan memiliki ukuran responsif
            Image.asset(
              "assets/images/logo.png", // Perbaiki path jika perlu
              width: screenSize.width * 1.0, // 50% dari lebar layar
              height: screenSize.height * 0.35, // 25% dari tinggi layar
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
