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
          'Favorites',
          style: GoogleFonts.bebasNeue(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No favorites yet. Start adding your favorite artworks!'),
            );
          }

          final favorites = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final artwork = favorites[index];
              final title = artwork['title'] ?? 'Untitled';
              final imageBase64 = artwork['imageBase64'] ?? '';
              final imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

              return Card(
                elevation: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: imageBytes != null
                          ? Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity)
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            _showArtworkOptions(context, userId, artwork.id, artwork);
                          },
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
              );
            },
          );
        },
      ),
    );
  }

  void _showArtworkOptions(BuildContext context, String userId, String artworkId, DocumentSnapshot artwork) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create New Collection'),
            onTap: () {
              Navigator.of(context).pop();
              _createCollection(context, userId, artworkId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.collections),
            title: const Text('Add to Existing Collection'),
            onTap: () {
              Navigator.of(context).pop();
              _addToExistingCollection(context, userId, artworkId);
            },
          ),
        ],
      ),
    );
  }

  void _showArtworkDetails(BuildContext context, DocumentSnapshot? artwork, String artworkId) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (artwork == null || !artwork.exists) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Artwork Not Found'),
            content: const Text('This artwork is no longer available.'),
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
      return;
    }

    final imageBase64 = artwork['imageBase64'] ?? '';
    final imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(artwork['title'] ?? 'Untitled'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageBytes != null)
                Image.memory(imageBytes, fit: BoxFit.cover, width: double.infinity),
              const SizedBox(height: 10),
              Text(artwork['description'] ?? 'No description available.'),
              const SizedBox(height: 10),
              Text('Price: \$${artwork['price'] ?? 'N/A'}'),
            ],
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

  void _createCollection(BuildContext context, String userId, String artworkId) {
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
                    'artworkIds': [artworkId],
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

  void _addToExistingCollection(BuildContext context, String userId, String artworkId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add to Collection'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('collections')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final collections = snapshot.data?.docs ?? [];

            if (collections.isEmpty) {
              return const Text('No collections found. Create a new collection first.');
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return ListTile(
                  title: Text(collection['name']),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('collections')
                        .doc(collection.id)
                        .update({
                      'artworkIds': FieldValue.arrayUnion([artworkId]),
                    });

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${collection['name']}')),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}