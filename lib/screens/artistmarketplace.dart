import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../services/apiServices.dart';
import 'login.dart';
import 'artistdashboard.dart';

class ArtistMarketPlace extends StatelessWidget {
  final GlobalKey<ScaffoldState> _menuKey = GlobalKey<ScaffoldState>();

  void _uploadForm(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String? _title, _description;
    double? _price;
    File? _image;

    Future<void> _pickImage() async {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    }

    Future<void> _uploadArt() async {
      if (_formKey.currentState!.validate() && _image != null) {
        _formKey.currentState!.save();

        try {
          final bytes = await _image!.readAsBytes();
          final base64Image = base64Encode(bytes);

          final userId = FirebaseAuth.instance.currentUser!.uid;
          await FirebaseFirestore.instance.collection('artworks').add({
            'artistId': userId,
            'title': _title,
            'description': _description,
            'price': _price,
            'imageBase64': base64Image,
            'sold': false,
            'buyerId': null,
          });

          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artwork Uploaded.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload artwork: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields and select an image.')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Upload Artwork'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a title' : null,
                    onSaved: (value) => _title = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a description' : null,
                    onSaved: (value) => _description = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter a price' : null,
                    onSaved: (value) => _price = double.tryParse(value!),
                  ),
                  const SizedBox(height: 16),
                  _image == null
                      ? TextButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text('Select Image'),
                          onPressed: _pickImage,
                        )
                      : Image.file(_image!, height: 100),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _uploadArt,
              child: const Text('Upload'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showArtworkDetails(BuildContext context, DocumentSnapshot artwork) {
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
                  'Status: ${artwork['sold'] == true ? 'Sold' : 'Available'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          actions: [
            if (artwork['sold'] == true)
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/chat', arguments: {
                    'chatId': '${artwork['artistId']}_${artwork['buyerId']}', 
                    'buyerId': artwork['buyerId'],
                    'buyerName': 'Buyer Name', 
                  });
                },
                child: const Text('Chat with Buyer'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () => _uploadForm(context),
          ),
        ],
      ),
      drawer: Drawer(
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
                Navigator.pushNamed(context,'/chat', arguments: {
                  'chatId': 'unique_chat_id', 
                  'userName': 'User Name',
                });
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
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchArtworks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No artworks found.'));
          }

          final artworks = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: artworks.length,
            itemBuilder: (context, index) {
              final artwork = artworks[index];
              final imageBytes = base64Decode(artwork['imageBase64']);
              return GestureDetector(
                onTap: () => _showArtworkDetails(context, artwork), // Show details on tap
                child: Card(
                  elevation: 5,
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          artwork['title'] ?? 'Untitled',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot>> _fetchArtworks() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('artworks')
        .where('artistId', isEqualTo: userId) 
        .get();

    return querySnapshot.docs;
  }
}