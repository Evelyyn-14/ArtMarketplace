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
            .collection('collections')
            .snapshots(),
        builder: (context, collectionSnapshot) {
          if (collectionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final collections = collectionSnapshot.data?.docs ?? [];
          final collectionArtworkIds = collections
              .expand((collection) => (collection['artworkIds'] as List<dynamic>))
              .toSet();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('favorites')
                .snapshots(),
            builder: (context, favoritesSnapshot) {
              if (favoritesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final favorites = favoritesSnapshot.data?.docs ?? [];
              final ungroupedFavorites = favorites
                  .where((artwork) => !collectionArtworkIds.contains(artwork.id))
                  .toList();

              return ListView(
                children: [
                  // Display Collections
                  if (collections.isNotEmpty)
                    ...collections.map((collection) {
                      final artworkIds = collection['artworkIds'] as List<dynamic>;

                      return ExpansionTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(collection['name']),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _confirmDeleteCollection(context, userId, collection.id, collection['name']);
                              },
                            ),
                          ],
                        ),
                        children: artworkIds.map((artworkId) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('favorites')
                                .doc(artworkId)
                                .get(),
                            builder: (context, artworkSnapshot) {
                              if (artworkSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final artwork = artworkSnapshot.data;
                              if (artwork == null || !artwork.exists) {
                                return const SizedBox.shrink();
                              }

                              final title = artwork['title'] ?? 'Untitled';
                              final imageBase64 = artwork['imageBase64'] ?? '';
                              final imageBytes = imageBase64.isNotEmpty
                                  ? base64Decode(imageBase64)
                                  : null;

                              return ListTile(
                                leading: imageBytes != null
                                    ? Image.memory(imageBytes, width: 50, height: 50, fit: BoxFit.cover)
                                    : const Icon(Icons.image, size: 50, color: Colors.grey),
                                title: Text(title),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
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

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(content: Text('Added to favorites!')),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),

                  // Display Ungrouped Favorites
                  if (ungroupedFavorites.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        'Ungrouped Favorites',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (ungroupedFavorites.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: ungroupedFavorites.length,
                      itemBuilder: (context, index) {
                        final artwork = ungroupedFavorites[index];
                        final title = artwork['title'] ?? 'Untitled';
                        final imageBase64 = artwork['imageBase64'] ?? '';
                        final imageBytes = imageBase64.isNotEmpty
                            ? base64Decode(imageBase64)
                            : null;

                        return Card(
                          elevation: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: imageBytes != null
                                    ? Image.memory(imageBytes,
                                        fit: BoxFit.cover, width: double.infinity)
                                    : const Icon(Icons.image,
                                        size: 50, color: Colors.grey),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () {
                                      _showArtworkOptions(context, userId,
                                          artwork.id, artwork);
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
                                      final isFavorite =
                                          favoriteSnapshot.data?.exists ??
                                              false;

                                      return IconButton(
                                        icon: Icon(
                                          isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFavorite
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () async {
                                          if (isFavorite) {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(userId)
                                                .collection('favorites')
                                                .doc(artwork.id)
                                                .delete();

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Removed from favorites!')),
                                            );
                                          } else {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(userId)
                                                .collection('favorites')
                                                .doc(artwork.id)
                                                .set({
                                              'title': artwork['title'],
                                              'description':
                                                  artwork['description'],
                                              'price': artwork['price'],
                                              'imageBase64':
                                                  artwork['imageBase64'],
                                              'artistId': artwork['artistId'],
                                            });

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Added to favorites!')),
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
                    ),
                ],
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return StreamBuilder<QuerySnapshot>(
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No collections found.\nCreate one to get started!'),
                ),
              );
            }
            return ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: collections.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final coll = collections[index];
                return ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(coll['name']),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('collections')
                        .doc(coll.id)
                        .update({
                      'artworkIds': FieldValue.arrayUnion([artworkId]),
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${coll['name']}')),
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


  void _confirmDeleteCollection(BuildContext context, String userId, String collectionId, String collectionName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Collection'),
          content: Text('Are you sure you want to delete the collection "$collectionName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Delete the collection from Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('collections')
                    .doc(collectionId)
                    .delete();

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Collection "$collectionName" deleted successfully!')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}