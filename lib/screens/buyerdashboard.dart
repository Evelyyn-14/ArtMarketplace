import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'buyermarketplace.dart';

class BuyerDashboard extends StatefulWidget {
  final String userName;
  double balance;

  BuyerDashboard({
    super.key,
    required this.userName,
    required this.balance,
  });

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  void _withdraw() async {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Withdraw'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
             decoration: const InputDecoration(
              border: OutlineInputBorder()
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                double withdrawAmount = double.tryParse(amountController.text) ?? 0.0;
                if (withdrawAmount > 0 && withdrawAmount <= widget.balance) {
                  setState(() {
                    widget.balance -= withdrawAmount;
                  });
                  await firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                    'balance': widget.balance,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdraw Successful.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insufficient balance')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Withdraw'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),            
          ],
        );
      },
    );
  }

  void _deposit() async {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deposit'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
             decoration: const InputDecoration(
              border: OutlineInputBorder()
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                double depositAmount = double.tryParse(amountController.text) ?? 0.0;
                if (depositAmount > 0) {
                  setState(() {
                    widget.balance += depositAmount;
                  });
                  await firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                    'balance': widget.balance,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully deposited.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount.')),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Deposit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),            
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTopSoldArtworks() async {
    final querySnapshot = await firestore
        .collection('artworks')
        .orderBy('price', descending: true)
        .limit(10)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
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
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Marketplace'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => BuyerMarketplace()),
                );
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Welcome ${widget.userName}!',
              style: GoogleFonts.anton(
                fontSize: 35,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 350,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Balance',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '\$${widget.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _deposit,
                                child: const Text(
                                  'Deposit',
                                  style: TextStyle(
                                    color: Colors.lightGreen,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: _withdraw,
                                child: const Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: Colors.lightGreen,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTopSoldArtworks(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return const Center(child: Text('No expensive sold artworks found.'));
              }

              final artworks = snapshot.data!;
              return Center(
                child: Container(
                  width: 350,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: const Text(
                          'Top 10 Expensive Artworks',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...artworks.map((artwork) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  artwork['title'] ?? 'Untitled',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '\$${(artwork['price'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}