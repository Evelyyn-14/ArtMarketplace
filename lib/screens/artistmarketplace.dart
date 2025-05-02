import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
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
            SnackBar(content: Text('Artwork Uploaded.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload artwork: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields and select an image.')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Upload Artwork'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a title' : null,
                    onSaved: (value) => _title = value,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a description' : null,
                    onSaved: (value) => _description = value,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter a price' : null,
                    onSaved: (value) => _price = double.tryParse(value!),
                  ),
                  SizedBox(height: 16),
                  _image == null
                      ? TextButton.icon(
                          icon: Icon(Icons.image),
                          label: Text('Select Image'),
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
              child: Text('Upload'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showArtworkDetails(BuildContext context, DocumentSnapshot artwork) {
    final imageBase64 = artwork['imageBase64'] as String;
    final imageBytes = base64Decode(imageBase64);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final isOwner = artwork['artistId'] == currentUserId;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
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
                  '\$${artwork['price']?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isOwner)
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          _editArtwork(context, artwork);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    if (isOwner)
                      ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('artworks')
                              .doc(artwork.id)
                              .delete();

                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Artwork deleted successfully!')),
                          );
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    if (!isOwner)
                      const Text(
                        'You do not have permission to edit this artwork.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
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

  void _editArtwork(BuildContext context, DocumentSnapshot artwork) {
    final _formKey = GlobalKey<FormState>();
    String? _title = artwork['title'];
    String? _description = artwork['description'];
    double? _price = artwork['price']?.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Artwork'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a title' : null,
                    onSaved: (value) => _title = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: _description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Enter a description' : null,
                    onSaved: (value) => _description = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: _price?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Enter a price' : null,
                    onSaved: (value) => _price = double.tryParse(value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  await FirebaseFirestore.instance.collection('artworks').doc(artwork.id).update({
                    'title': _title,
                    'description': _description,
                    'price': _price,
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Artwork updated successfully!')),
                  );
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
            icon: Icon(Icons.upload),
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
                              ElevatedButton(
                                onPressed: () => _showArtworkDetails(context, artwork),
                                child: Text('View Details'),
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