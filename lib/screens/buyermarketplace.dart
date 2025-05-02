import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'login.dart';
import 'buyerdashboard.dart';
import 'package:art_marketplace/services/apiService.dart';

class Buyermarketplace extends StatelessWidget {
  final GlobalKey<ScaffoldState> _menuKey = GlobalKey<ScaffoldState>();
  final Apiservices _apiServices = Apiservices();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

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
      drawer: _buildDrawer(context, userId),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchCombinedData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No artworks or images found.'));
          }

          final combinedData = snapshot.data!;

          return ListView.builder(
            itemCount: combinedData.length,
            itemBuilder: (context, index) {
              final item = combinedData[index];

              if (item is DocumentSnapshot) {
                final artwork = item;
                final imageBase64 = artwork['imageBase64'] as String;
                final imageBytes = base64Decode(imageBase64);

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(artwork['artistId']).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final artistName = userSnapshot.data?['name'] ?? 'Unknown Artist';

                    return _buildArtworkCard(context, artwork, artistName, imageBytes, userId);
                  },
                );
              } else {
                final pixabayImage = item;
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        pixabayImage['webformatURL'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          pixabayImage['tags'] ?? 'No description',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<List<dynamic>> _fetchCombinedData() async {
    try {
      final artworkQuerySnapshot = await FirebaseFirestore.instance.collection('artworks').get();
      final artworks = artworkQuerySnapshot.docs;

      final pixabayImages = await _apiServices.getImages('art');

      return [...artworks, ...pixabayImages];
    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }

  Widget _buildDrawer(BuildContext context, String userId) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
            ),
            child: const Text(
              'Menu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () async {
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
    );
  }

  Widget _buildArtworkCard(BuildContext context, DocumentSnapshot artwork, String artistName, Uint8List imageBytes, String userId) {
    return Card(
      margin: const EdgeInsets.all(10),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Text(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork['title'] ?? 'Untitled',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  artwork['description'] ?? 'No description',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  'By: $artistName',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${artwork['price']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showArtworkDetails(context, artwork, artistName);
                        },
                        icon: const Icon(Icons.info, size: 16),
                        label: const Text(
                          'Details',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('favorites')
                          .doc(artwork.id)
                          .snapshots(),
                      builder: (context, favoriteSnapshot) {
                        final isFavorite = favoriteSnapshot.data?.exists ?? false;

                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            if (isFavorite) {
                              // Remove from favorites
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('favorites')
                                  .doc(artwork.id)
                                  .delete();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Removed from favorites!')),
                              );
                            } else {
                              // Add to favorites
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('favorites')
                                  .doc(artwork.id)
                                  .set({
                                'title': artwork['title'],
                                'description': artwork['description'],
                                'price': artwork['price'],
                                'imageBase64': artwork['imageBase64'],
                                'artistId': artwork['artistId'],
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added to favorites!')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(BuildContext context, DocumentSnapshot artwork, String artistName) {
    final imageBase64 = artwork['imageBase64'] as String;
    final imageBytes = base64Decode(imageBase64);
    final artPrice = artwork['price']?.toDouble() ?? 0.0;
    final userId = FirebaseAuth.instance.currentUser!.uid;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: MemoryImage(imageBytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  artwork['title'] ?? 'Untitled',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  artwork['description'] ?? 'No description available.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  '\$${artPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 10),
                Text(
                  'Artist: $artistName',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          actions: [
            if (artwork['sold'] != true)
              ElevatedButton.icon(
                onPressed: () async {
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                  final buyerBalance = userDoc['balance']?.toDouble() ?? 0.0;

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Purchase Details'),
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
                            child: const Text('Close'),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (buyerBalance >= artPrice) {
                                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                                  'balance': buyerBalance - artPrice,
                                });
                                await FirebaseFirestore.instance.collection('artworks').doc(artwork.id).update({
                                  'sold': true,
                                  'buyerId': userId,
                                });
                                final artistDocRef = FirebaseFirestore.instance.collection('users').doc(artwork['artistId']);
                                final artistDoc = await artistDocRef.get();

                                if (artistDoc.exists) {
                                  final artistBalance = artistDoc['balance']?.toDouble() ?? 0.0;
                                  final artistTotalSales = artistDoc['total_sales']?.toDouble() ?? 0.0;
                                  final artworksSold = artistDoc['total_purchases'] ?? 0;

                                  await artistDocRef.update({
                                    'balance': artistBalance + artPrice,
                                    'total_sales': artistTotalSales + artPrice,
                                    'total_purchases': artworksSold + 1,
                                  });
                                } else {
                                  throw Exception('Artist document does not exist.');
                                }

                                final buyerDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
                                final buyerDoc = await buyerDocRef.get();

                                if (buyerDoc.exists) {
                                  final buyerTotalPurchases = buyerDoc['total_purchases']?.toDouble() ?? 0.0;

                                  await buyerDocRef.update({
                                    'total_purchases': buyerTotalPurchases + artPrice,
                                  });
                                } else {
                                  throw Exception('Buyer document does not exist.');
                                }

                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Purchase successful!')),
                                );
                              } else {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Insufficient balance.')),
                                );
                              }
                            },
                            child: const Text('Confirm'),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Buy Now'),
                style: ElevatedButton.styleFrom(
                ),
              ),
            TextButton(
              onPressed: () async {
                final chatRoomId = '${userId}_${artwork['artistId']}';
                final chatRoomRef = FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId);

                final chatRoomSnapshot = await chatRoomRef.get();
                if (!chatRoomSnapshot.exists) {
                  await chatRoomRef.set({
                    'participants': [userId, artwork['artistId']],
                    'emails': {
                      userId: FirebaseAuth.instance.currentUser!.email,
                      artwork['artistId']: artistName,
                    },
                  });
                }
                Navigator.pushNamed(context, '/chat', arguments: {
                  'chatRoomId': chatRoomId,
                  'artistName': artistName,
                });
              },
              child: const Text('Chat'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}