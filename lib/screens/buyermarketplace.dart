import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'login.dart';
import 'buyerdashboard.dart';

class Buyermarketplace extends StatelessWidget {
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

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuyerDashboard(
                      userName: userName,
                      balance: balance,
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
                Navigator.pushNamed(context, '/chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pushNamed(context, '/favorites');
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('artworks').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No artworks on sell.'));
          }
          final artworks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: artworks.length,
            itemBuilder: (context, index) {
              final artwork = artworks[index];
              final imageBase64 = artwork['imageBase64'] as String;
              final imageBytes = base64Decode(imageBase64);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(artwork['artistId']).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final artistName = userSnapshot.data?['name'] ?? 'Unknown Artist';

                  return Card(
                    margin: EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Image.memory(
                              imageBytes,
                              fit: BoxFit.cover,
                              width: 200,
                              height: 200,
                            ),
                            if (artwork['sold'] == true) 
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  color: Colors.red.withOpacity(0.8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'SOLD',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artwork['title'] ?? 'Untitled',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 5),
                              Text(
                                artwork['description'] ?? 'No description',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'By: $artistName',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '\$${artwork['price']?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              SizedBox(height: 10),
                              if (artwork['sold'] != true)
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final userId = FirebaseAuth.instance.currentUser!.uid;
                                    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                                    final buyerBalance = userDoc['balance']?.toDouble() ?? 0.0;
                                    final artPrice = artwork['price']?.toDouble() ?? 0.0;

                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Purchase Details'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Artist: $artistName'),
                                              Text('Price: \$${artPrice.toStringAsFixed(2)}'),
                                              Text('Your Balance: \$${buyerBalance.toStringAsFixed(2)}'),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text('Close'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                if (buyerBalance >= artPrice) {
                                                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                                    'balance': buyerBalance - artPrice,
                                                  });

                                                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                                    'purchaseCount': FieldValue.increment(1),
                                                  });

                                                  await FirebaseFirestore.instance.collection('artworks').doc(artwork.id).update({
                                                    'sold': true,
                                                    'buyerId': userId, 
                                                  });

                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: Text('Purchase Successful'),
                                                        content: Text('You have successfully purchased the artwork.'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: Text('OK'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: Text('Insufficient Balance'),
                                                        content: Text('You do not have enough balance to purchase this artwork.'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                            child: Text('OK'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                }
                                              },
                                              child: Text('Confirm'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  icon: Icon(Icons.shopping_cart),
                                  label: Text('Buy Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}