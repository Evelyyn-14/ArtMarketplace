import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
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

  Future<Map<String, double>?> _fetchCurrencyRates() async {
    const apiKey = '5baf1a60d46eecfeae37c6c53ce08986'; // Replace with your valid API key
    const url = 'https://api.currencylayer.com/live?access_key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['quotes'] != null) {
          final quotes = data['quotes'] as Map<String, dynamic>;
          return quotes.map((key, value) => MapEntry(key.substring(3), value.toDouble()));
        } else {
          debugPrint('Currency Layer API Error: ${data['error']['info']}');
          return null;
        }
      } else {
        debugPrint('Failed to fetch currency rates. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching currency rates: $e');
      return null;
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
                onPressed: () {
                  _purchaseArtwork(context, artwork);
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
                style: ElevatedButton.styleFrom(),
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

  void _purchaseArtwork(BuildContext context, DocumentSnapshot artwork) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final buyerBalance = userDoc['balance']?.toDouble() ?? 0.0;

    final priceInUSD = artwork['price']?.toDouble() ?? 0.0;

    final conversionRates = await _fetchCurrencyRates();
    if (conversionRates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch currency rates.')),
      );
      return;
    }

    String selectedCurrency = conversionRates.keys.first;
    double convertedPrice = priceInUSD * (conversionRates[selectedCurrency] ?? 1.0);


   await showDialog(
  context: context,
  builder: (context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: DropdownButtonFormField<String>(
            value: selectedCurrency,
            items: conversionRates.keys.map((currency) {
              return DropdownMenuItem<String>(
                value: currency,
                child: Text(currency),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedCurrency = value;
                convertedPrice =
                    priceInUSD * (conversionRates[value] ?? 1.0);
              });
            },
          ),
          actions: [
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  },
);

    if (buyerBalance < convertedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance.')),
      );
      return;
    }

    // Simulate purchase
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'balance': buyerBalance - convertedPrice,
      });

      await FirebaseFirestore.instance.collection('artworks').doc(artwork.id).update({
        'sold': true,
        'buyerId': userId,
      });

      final artistId = artwork['artistId'];
      await FirebaseFirestore.instance.collection('users').doc(artistId).update({
        'total_sales': FieldValue.increment(1),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete purchase: $e')),
      );
    }
  }
}