import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class FavoritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        centerTitle: true,
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

          final favoriteDocs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3 / 4, 
            ),
            itemCount: favoriteDocs.length,
            itemBuilder: (context, index) {
              final favorite = favoriteDocs[index];
              final artworkId = favorite.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('artworks').doc(artworkId).get(),
                builder: (context, artworkSnapshot) {
                  if (artworkSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!artworkSnapshot.hasData || !artworkSnapshot.data!.exists) {
                    return const Center(
                      child: Text('Artwork Not Found'),
                    );
                  }

                  final artwork = artworkSnapshot.data!;
                  final title = artwork['title'] ?? 'Untitled';
                  final imageBase64 = artwork['imageBase64'] ?? '';
                  final imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

                  return GestureDetector(
                    onTap: () {
                      _showArtworkDetails(context, artwork, artworkId);
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: imageBytes != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                    child: Image.memory(
                                      imageBytes,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : const Icon(Icons.image, size: 100, color: Colors.grey),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('favorites')
                                      .doc(artworkId)
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
                                              .doc(artworkId)
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
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  void _showArtworkDetails(BuildContext context, DocumentSnapshot? artwork, String artworkId) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (artwork == null || !artwork.exists) {
      // Handle missing or invalid artwork
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
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, 
              children: [
                if (imageBytes != null)
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
                  )
                else
                  const Icon(Icons.image, size: 100, color: Colors.grey),
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
}