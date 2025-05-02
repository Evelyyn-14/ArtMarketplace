import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

class FavoritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'My Collections',
          style: GoogleFonts.bebasNeue(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _createCollection(context, userId);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('collections')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No collections yet. Start creating your collections!'),
            );
          }

          final collections = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              final collectionName = collection['name'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollectionDetailsScreen(
                        collectionId: collection.id,
                        collectionName: collectionName,
                        userId: userId,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 5,
                  child: Center(
                    child: Text(
                      collectionName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _createCollection(BuildContext context, String userId) {
    final _formKey = GlobalKey<FormState>();
    String? _collectionName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Collection'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              decoration: const InputDecoration(labelText: 'Collection Name'),
              validator: (value) => value!.isEmpty ? 'Enter a collection name' : null,
              onSaved: (value) => _collectionName = value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('collections')
                      .add({
                    'name': _collectionName,
                    'artworkIds': [],
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collection created successfully!')),
                  );
                }
              },
              child: const Text('Create'),
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
}

class CollectionDetailsScreen extends StatelessWidget {
  final String collectionId;
  final String collectionName;
  final String userId;

  CollectionDetailsScreen({
    required this.collectionId,
    required this.collectionName,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collectionName),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('collections')
            .doc(collectionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Collection not found.'),
            );
          }

          final collection = snapshot.data!;
          final artworkIds = List<String>.from(collection['artworkIds'] ?? []);

          if (artworkIds.isEmpty) {
            return const Center(
              child: Text('No artworks in this collection.'),
            );
          }

          return ListView.builder(
            itemCount: artworkIds.length,
            itemBuilder: (context, index) {
              final artworkId = artworkIds[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('artworks').doc(artworkId).get(),
                builder: (context, artworkSnapshot) {
                  if (artworkSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!artworkSnapshot.hasData || !artworkSnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('Artwork Not Found'),
                    );
                  }

                  final artwork = artworkSnapshot.data!;
                  final title = artwork['title'] ?? 'Untitled';
                  final imageBase64 = artwork['imageBase64'] ?? '';
                  final imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('favorites')
                        .doc(artworkId)
                        .snapshots(),
                    builder: (context, favoriteSnapshot) {
                      final isFavorite = favoriteSnapshot.data?.exists ?? false;

                      return ListTile(
                        leading: imageBytes != null
                            ? Image.memory(imageBytes, width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 50, color: Colors.grey),
                        title: Text(title),
                        trailing: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            if (isFavorite) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('favorites')
                                  .doc(artworkId)
                                  .delete();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Removed from favorites!')),
                              );
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('favorites')
                                  .doc(artworkId)
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
                        ),
                      );
                    },
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