import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'artistdashboard.dart';
import 'login.dart';

class MarketPlace extends StatelessWidget {
  final GlobalKey<ScaffoldState> _menuKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _menuKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _menuKey.currentState?.openDrawer();
          },
        ),
        centerTitle: true,
        title: Text(
          'MarketPlace',
          style: GoogleFonts.bebasNeue(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
              ),
              child: Text(
                'Menu',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () async {
                final userId = FirebaseAuth.instance.currentUser!.uid;
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                final userName = userDoc['name'] ?? 'User';
                final balance = userDoc['balance']?.toDouble() ?? 0.0;
                final totalSales = userDoc['total_sales']?.toDouble() ?? 0.0;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArtistDashboard(
                      userName: userName,
                      balance: balance,
                      totalSales: totalSales,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('MarketPlace'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble),
              title: const Text('Chat'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
