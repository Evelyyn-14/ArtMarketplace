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

class BuyerMarketplace extends StatefulWidget {
  @override
  _BuyerMarketplaceState createState() => _BuyerMarketplaceState();
}

class _BuyerMarketplaceState extends State<BuyerMarketplace> {
  final GlobalKey<ScaffoldState> _menuKey = GlobalKey<ScaffoldState>();
  final Apiservices _apiServices = Apiservices();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStyle = 'All';
  double _minPrice = 0.0;
  double _maxPrice = double.infinity;

  List<dynamic> _allData = [];
  List<dynamic> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _updateFirestoreData();
    final data = await _fetchCombinedData();
    setState(() {
      _allData = data;
      _filteredData = data;
    });
  }

  Future<void> _updateFirestoreData() async {
    final col = FirebaseFirestore.instance.collection('artworks');
    final snapshot = await col.get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('category')) {
        await col.doc(doc.id).update({'category': 'Uncategorized'});
      }
      if (!data.containsKey('style')) {
        await col.doc(doc.id).update({'style': 'Unknown'});
      }
    }
  }

  Future<List<dynamic>> _fetchCombinedData() async {
    try {
      final artSnap = await FirebaseFirestore.instance.collection('artworks').get();
      final pixabay = await _apiServices.getImages('art');
      return [...artSnap.docs, ...pixabay];
    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }

  Future<Map<String, double>?> _fetchCurrencyRates() async {
    const apiKey = '5baf1a60d46eecfeae37c6c53ce08986';
    final url = 'https://api.currencylayer.com/live?access_key=$apiKey';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && body['quotes'] != null) {
          final quotes = Map<String, dynamic>.from(body['quotes']);
          return {for (var e in quotes.entries) e.key.substring(3): (e.value as num).toDouble()};
        } else {
          debugPrint('CurrencyLayer error: ${body['error']['info']}');
        }
      } else {
        debugPrint('HTTP ${res.statusCode} fetching rates');
      }
    } catch (e) {
      debugPrint('Error fetching rates: $e');
    }
    return null;
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _allData.where((item) {
        if (item is DocumentSnapshot) {
          final d = item.data()! as Map<String, dynamic>;
          final title = (d['title'] as String?)?.toLowerCase() ?? '';
          final desc  = (d['description'] as String?)?.toLowerCase() ?? '';
          final cat   = d['category'] as String? ?? 'Uncategorized';
          final style = d['style'] as String? ?? 'Unknown';
          final price = (d['price'] as num?)?.toDouble() ?? 0.0;

          final matchesSearch   = title.contains(_searchQuery) || desc.contains(_searchQuery);
          final matchesCategory = _selectedCategory == 'All' || cat == _selectedCategory;
          final matchesStyle    = _selectedStyle    == 'All' || style == _selectedStyle;
          final matchesPrice    = price >= _minPrice && price <= _maxPrice;

          return matchesSearch && matchesCategory && matchesStyle && matchesPrice;
        } else if (item is Map<String, dynamic>) {
          final tags = (item['tags'] as String?)?.toLowerCase() ?? '';
          return tags.contains(_searchQuery);
        }
        return false;
      }).toList();
    });
  }

  void _showFilterDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Filter Artworks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(labelText: 'Category'),
              items: ['All', 'Painting', 'Sculpture', 'Photography']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              decoration: InputDecoration(labelText: 'Style'),
              items: ['All', 'Abstract', 'Realism', 'Modern']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStyle = v!),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _minPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Min Price'),
                    onChanged: (v) => setState(() => _minPrice = double.tryParse(v) ?? 0),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxPrice == double.infinity ? '' : _maxPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Max Price'),
                    onChanged: (v) => setState(() => _maxPrice = double.tryParse(v) ?? double.infinity),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _applyFilters();
              Navigator.of(ctx).pop();
            },
            child: Text('Apply'),
          )
        ],
      ),
    );
  }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search artworks...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v.toLowerCase();
                _applyFilters();
              }),
            ),
          ),
          Expanded(
            child: _filteredData.isEmpty
                ? Center(child: Text('No artworks found.'))
                : ListView.builder(
                    itemCount: _filteredData.length,
                    itemBuilder: (c, i) {
                      final item = _filteredData[i];
                      if (item is DocumentSnapshot) {
                        final data = item.data()! as Map<String, dynamic>;
                        final bytes = base64Decode(data['imageBase64'] as String);
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(data['artistId']).get(),
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final artist = snap.data?['name'] ?? 'Unknown';
                            return _buildArtworkCard(c, item, artist, bytes, userId);
                          },
                        );
                      } else if (item is Map<String, dynamic>) {
                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.network(item['webformatURL'] ?? '', width: double.infinity, height: 200, fit: BoxFit.cover),
                              SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  item['tags'] as String? ?? 'No description',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                ),
                              ),
                              SizedBox(height: 10),
                            ],
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, String userId) {
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.orange.shade100),
          child: Text('Menu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: Icon(Icons.dashboard),
          title: Text('Dashboard'),
          onTap: () async {
            final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            final name = doc['name'] ?? 'User';
            final bal  = (doc['balance'] as num?)?.toDouble() ?? 0;
            Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => BuyerDashboard(userName: name, balance: bal)));
          },
        ),
        ListTile(leading: Icon(Icons.store), title: Text('MarketPlace'), onTap: () => Navigator.pop(ctx)),
        ListTile(leading: Icon(Icons.chat_bubble), title: Text('Chat'), onTap: () => Navigator.pushNamed(ctx, '/chat')),
        ListTile(leading: Icon(Icons.star), title: Text('Favorites'), onTap: () => Navigator.pushNamed(ctx, '/favorites')),
        ListTile(
          leading: Icon(Icons.logout),
          title: Text('Logout'),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => LoginScreen()));
          },
        ),
      ]),
    );
  }

  Card _buildArtworkCard(BuildContext ctx, DocumentSnapshot art, String artistName, Uint8List imgBytes, String userId) {
    final data = art.data()! as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.all(10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Image.memory(imgBytes, width: 200, height: 200, fit: BoxFit.cover),
          if (data['sold'] == true)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                color: Colors.red.withOpacity(0.8),
                padding: const EdgeInsets.all(4),
                child: const Text('SOLD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? 'Untitled', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(data['description'] ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 5),
            Text('By: $artistName', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 5),
            Text('\$${(data['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.info, size: 16),
                  label: const Text('Details', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showArtworkDetails(ctx, art, artistName),
                ),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(userId).collection('favorites').doc(art.id).snapshots(),
                builder: (c, favSnap) {
                  final isFav = favSnap.data?.exists ?? false;
                  return IconButton(
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
                    onPressed: () async {
                      final favRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('favorites').doc(art.id);
                      if (isFav) {
                        await favRef.delete();
                        ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Removed from favorites!')));
                      } else {
                        await favRef.set({
                          'title': data['title'],
                          'description': data['description'],
                          'price': data['price'],
                          'imageBase64': data['imageBase64'],
                          'artistId': data['artistId'],
                        });
                        ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Added to favorites!')));
                      }
                    },
                  );
                },
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _showArtworkDetails(BuildContext context, DocumentSnapshot artwork, String artistName) {
    final outerContext = context;
    final imageBase64 = artwork['imageBase64'] as String;
    final imageBytes = base64Decode(imageBase64);
    final artPrice = artwork['price']?.toDouble() ?? 0.0;

    showDialog(
      context: outerContext,
      builder: (BuildContext dialogContext) {
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
                  Navigator.of(dialogContext).pop();
                  _purchaseArtwork(outerContext, artwork);
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Buy Now'),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.chat_bubble),
              label: const Text('Chat Artist'),
              onPressed: () async {
                final userId = FirebaseAuth.instance.currentUser!.uid;
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
                Navigator.of(dialogContext).pop();
                Navigator.pushNamed(outerContext, '/chat', arguments: {
                  'chatRoomId': chatRoomId,
                  'artistName': artistName,
                  'autoFocus': true,
                });
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _purchaseArtwork(BuildContext context, DocumentSnapshot art) async {
    if (!mounted) return;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!mounted) return;
    double balance = (userDoc['balance'] as num?)?.toDouble() ?? 0.0;

    final data = art.data()! as Map<String, dynamic>;
    final usdPrice = (data['price'] as num?)?.toDouble() ?? 0.0;

    final rates = await _fetchCurrencyRates();
    if (!mounted) return;
    if (rates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch currency rates.')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String selectedCurrency = rates.keys.first;
        double converted = usdPrice * (rates[selectedCurrency] ?? 1);

        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Select Currency'),
              content: DropdownButtonFormField<String>(
                value: selectedCurrency,
                items: rates.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    selectedCurrency = v;
                    converted = usdPrice * (rates[v] ?? 1);
                  });
                },
              ),
              actions: [
                TextButton(
                  child: const Text('Confirm'),
                  onPressed: () {
                    Navigator.of(ctx).pop({
                      'currency': selectedCurrency,
                      'converted': converted,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (result == null) {
      return;
    }

    final double converted = result['converted'] as double;
    if (balance < converted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'balance': balance - converted,
      });
      await FirebaseFirestore.instance.collection('artworks').doc(art.id).update({
        'sold': true,
        'buyerId': userId,
      });

      final artistId = data['artistId'];
      final artistDoc = await FirebaseFirestore.instance.collection('users').doc(artistId).get();
      if (!mounted) return;
      if (artistDoc.exists) {
        final artistBal = (artistDoc['balance'] as num?)?.toDouble() ?? 0.0;
        final artistSales = (artistDoc['total_sales'] as num?)?.toDouble() ?? 0.0;
        final artistPurchases = (artistDoc['total_purchases'] as num?)?.toInt() ?? 0;
        await FirebaseFirestore.instance.collection('users').doc(artistId).update({
          'balance': artistBal + converted,
          'total_sales': artistSales + converted,
          'total_purchases': artistPurchases + 1,
        });
      } else {
        throw Exception('Artist document does not exist.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase successful!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    }
  }
}
