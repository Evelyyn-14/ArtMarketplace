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

  List<dynamic> _filteredData = [];
  List<dynamic> _allData = [];

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

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      key: _menuKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _menuKey.currentState?.openDrawer(),
        ),
        centerTitle: true,
        title: Text(
          'MarketPlace',
          style: GoogleFonts.bebasNeue(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context, userId),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search artworks...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),
          Expanded(
            child: _filteredData.isEmpty
                ? const Center(child: Text('No artworks found.'))
                : ListView.builder(
                    itemCount: _filteredData.length,
                    itemBuilder: (context, index) {
                      final item = _filteredData[index];

                      if (item is DocumentSnapshot) {
                        final artwork = item;
                        final imageBase64 = artwork['imageBase64'] as String;
                        final imageBytes = base64Decode(imageBase64);

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(artwork['artistId'])
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final artistName =
                                userSnapshot.data?['name'] ?? 'Unknown Artist';

                            return _buildArtworkCard(
                                context, artwork, artistName, imageBytes, userId);
                          },
                        );
                      } else {
                        final pixabayImage = item as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.network(
                                pixabayImage['webformatURL'] ?? '',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  (pixabayImage['tags'] as String?) ??
                                      'No description',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700]),
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
                  ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _fetchCombinedData() async {
    try {
      final artworkQuerySnapshot =
          await FirebaseFirestore.instance.collection('artworks').get();
      final artworks = artworkQuerySnapshot.docs;
      final pixabayImages = await _apiServices.getImages('art');
      return [...artworks, ...pixabayImages];
    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }

  Future<Map<String, double>?> _fetchCurrencyRates() async {
    const apiKey = '5baf1a60d46eecfeae37c6c53ce08986';
    const url = 'https://api.currencylayer.com/live?access_key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['quotes'] != null) {
          final quotes = data['quotes'] as Map<String, dynamic>;
          return quotes.map((key, value) =>
              MapEntry(key.substring(3), (value as num).toDouble()));
        } else {
          debugPrint('Currency Layer API Error: ${data['error']['info']}');
        }
      } else {
        debugPrint('Failed to fetch currency rates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching currency rates: $e');
    }
    return null;
  }

  Widget _buildDrawer(BuildContext context, String userId) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.orange.shade100),
            child: const Text(
              'Menu',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () async {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              final userName = userDoc['name'] ?? 'User';
              final balance = (userDoc['balance'] as num?)?.toDouble() ?? 0.0;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BuyerDashboard(
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
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble),
            title: const Text('Chat'),
            onTap: () => Navigator.pushNamed(context, '/chat'),
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Favorites'),
            onTap: () => Navigator.pushNamed(context, '/favorites'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(
    BuildContext context,
    DocumentSnapshot artwork,
    String artistName,
    Uint8List imageBytes,
    String userId,
  ) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Text(
                      'SOLD',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
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
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  artwork['description'] ?? 'No description',
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  'By: $artistName',
                  style:
                      TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 5),
                Text(
                  '\$${(artwork['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.info, size: 16),
                        label: const Text('Details', style: TextStyle(fontSize: 12)),
                        onPressed: () =>
                            _showArtworkDetails(context, artwork, artistName),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
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
                        final isFavorite =
                            favoriteSnapshot.data?.exists ?? false;
                        return IconButton(
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            final favRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('favorites')
                                .doc(artwork.id);
                            if (isFavorite) {
                              await favRef.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Removed from favorites!')));
                            } else {
                              await favRef.set({
                                'title': artwork['title'],
                                'description': artwork['description'],
                                'price': artwork['price'],
                                'imageBase64': artwork['imageBase64'],
                                'artistId': artwork['artistId'],
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Added to favorites!')));
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

  void _showArtworkDetails(
      BuildContext context, DocumentSnapshot artwork, String artistName) {
    final imageBytes = base64Decode(artwork['imageBase64'] as String);
    final artPrice = (artwork['price'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
                      image: MemoryImage(imageBytes), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                artwork['title'] ?? 'Untitled',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                artwork['description'] ?? 'No description available.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                '\$${artPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              const SizedBox(height: 10),
              Text(
                'Artist: $artistName',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          if (artwork['sold'] != true)
            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Buy Now'),
              onPressed: () {
                Navigator.of(context).pop();
                _purchaseArtwork(context, artwork);
              },
            ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _purchaseArtwork(
      BuildContext context, DocumentSnapshot artwork) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final buyerBalance =
        (userDoc['balance'] as num?)?.toDouble() ?? 0.0;
    final priceInUSD = (artwork['price'] as num?)?.toDouble() ?? 0.0;

    final conversionRates = await _fetchCurrencyRates();
    if (conversionRates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch currency rates.')));
      return;
    }

    String selectedCurrency = conversionRates.keys.first;
    double convertedPrice = priceInUSD * (conversionRates[selectedCurrency] ?? 1);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Select Currency'),
          content: DropdownButtonFormField<String>(
            value: selectedCurrency,
            items: conversionRates.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedCurrency = val;
                convertedPrice = priceInUSD * (conversionRates[val] ?? 1);
              });
            },
          ),
          actions: [
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
      ),
    );

    if (buyerBalance < convertedPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance.')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'balance': buyerBalance - convertedPrice,
      });
      await FirebaseFirestore.instance
          .collection('artworks')
          .doc(artwork.id)
          .update({'sold': true, 'buyerId': userId});
      final artistId = artwork['artistId'];
      await FirebaseFirestore.instance.collection('users').doc(artistId).update(
          {'total_sales': FieldValue.increment(1)});

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase successful!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete purchase: $e')));
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _allData.where((item) {
        if (item is DocumentSnapshot) {
          final data = item.data() as Map<String, dynamic>;
          final title       = (data['title']       as String?)?.toLowerCase() ?? '';
          final description = (data['description'] as String?)?.toLowerCase() ?? '';
          final category    = (data['category']    as String?) ?? 'Uncategorized';
          final style       = (data['style']       as String?) ?? 'Unknown';
          final price       = (data['price']       as num?)?.toDouble()   ?? 0.0;

          final matchesSearch   = title.contains(_searchQuery.toLowerCase()) ||
                                   description.contains(_searchQuery.toLowerCase());
          final matchesCategory = _selectedCategory == 'All' ||
                                   category == _selectedCategory;
          final matchesStyle    = _selectedStyle    == 'All' ||
                                   style    == _selectedStyle;
          final matchesPrice    = price >= _minPrice && price <= _maxPrice;

          return matchesSearch && matchesCategory && matchesStyle && matchesPrice;
        }

        if (item is Map<String, dynamic>) {
          final tags = (item['tags'] as String?)?.toLowerCase() ?? '';
          return tags.contains(_searchQuery.toLowerCase());
        }

        return false;
      }).toList();
    });
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Artworks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: ['All', 'Painting', 'Sculpture', 'Photography']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedStyle,
              items: ['All', 'Abstract', 'Realism', 'Modern']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedStyle = val!),
              decoration: const InputDecoration(labelText: 'Style'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _minPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Min Price'),
                    onChanged: (v) =>
                        setState(() => _minPrice = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxPrice == double.infinity
                        ? ''
                        : _maxPrice.toString(),
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Max Price'),
                    onChanged: (v) => setState(() =>
                        _maxPrice = double.tryParse(v) ?? double.infinity),
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
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFirestoreData() async {
    final artworksCollection =
        FirebaseFirestore.instance.collection('artworks');
    final snapshot = await artworksCollection.get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('category')) {
        await artworksCollection.doc(doc.id).update(
            {'category': 'Uncategorized'});
      }
      if (!data.containsKey('style')) {
        await artworksCollection.doc(doc.id)
            .update({'style': 'Unknown'});
      }
    }
  }
}
