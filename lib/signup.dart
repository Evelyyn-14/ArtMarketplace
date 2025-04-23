import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Text(
              'Artwork Marketplace',
              style: GoogleFonts.supermercadoOne(
                fontSize: 35,
                fontWeight: FontWeight.bold
              ),
            ),
            Image.asset(
              'assets/artIcon.png',
              height: 100,
            ),
            const SizedBox(height: 50),
            Container(
              width: 300,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10)
              ),
            )
          ],
        ),
      )
    );
  }
}