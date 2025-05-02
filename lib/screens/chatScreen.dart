import 'package:flutter/material.dart';
 import 'package:cloud_firestore/cloud_firestore.dart';
 import 'package:firebase_auth/firebase_auth.dart';
 import 'package:google_fonts/google_fonts.dart';
 
 class ChatScreen extends StatefulWidget {
   const ChatScreen({super.key});
 
   @override
   _ChatScreenState createState() => _ChatScreenState();
  }
 
 class _ChatScreenState extends State<ChatScreen> {
   final FirebaseAuth _auth = FirebaseAuth.instance;
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
   String? _selectedChatRoomId;
 
   @override
   Widget build(BuildContext context) {
     final user = _auth.currentUser;
     final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
 
     if (user == null) {
       return const Center(child: Text('You must be logged in to use the chat.'));
     }
 
     if (args != null && args.containsKey('chatRoomId')) {
       _selectedChatRoomId = args['chatRoomId'];
     }
 
     return Scaffold(
       appBar: AppBar(
         title: Text(
           'Chat Rooms',
           style: GoogleFonts.bebasNeue(
             fontSize: 30,
             fontWeight: FontWeight.bold,
           ),
         ),
         centerTitle: true,
       ),
       body: Row(
         children: [
           Expanded(
             flex: 1,
             child: Container(
               color: Colors.orange.shade100,
               child: StreamBuilder<QuerySnapshot>(
                 stream: _firestore
                     .collection('chatRooms')
                     .where('participants', arrayContains: user.uid)
                     .snapshots(),
                 builder: (context, snapshot) {
                   if (snapshot.connectionState == ConnectionState.waiting) {
                     return const Center(child: CircularProgressIndicator());
                   }
 
                   final chatRooms = snapshot.data!.docs;
 
                   return ListView.builder(
                     itemCount: chatRooms.length,
                     itemBuilder: (context, index) {
                       final chatRoom = chatRooms[index];
                       final chatRoomId = chatRoom.id;
                       final participants = chatRoom['participants'] as List<dynamic>;
 
                       final otherParticipantId = participants.firstWhere((id) => id != user.uid);
 
                       return FutureBuilder<DocumentSnapshot>(
                         future: _firestore.collection('users').doc(otherParticipantId).get(),
                         builder: (context, userSnapshot) {
                           if (userSnapshot.connectionState == ConnectionState.waiting) {
                             return const ListTile(
                               title: Text('Loading...'),
                             );
                           }
 
                           final otherParticipantName = userSnapshot.data?['name'] ?? 'Unknown';
 
                           return ListTile(
                             title: Text(otherParticipantName),
                             onTap: () {
                               setState(() {
                                 _selectedChatRoomId = chatRoomId;
                               });
                             },
                           );
                         },
                       );
                     },
                   );
                 },
               ),
             ),
           ),
           Expanded(
             flex: 2,
              child: Container(
               color: Colors.white,
               child: _selectedChatRoomId == null
                   ? const Center(child: Text('Select a chat room to start chatting.'))
                   : ChatMessages(chatRoomId: _selectedChatRoomId!),
             ),
           ),
         ],
       ),
     );
   }
 }
 
 class ChatMessages extends StatefulWidget {
   final String chatRoomId;
 
   const ChatMessages({super.key, required this.chatRoomId});
 
   @override
   _ChatMessagesState createState() => _ChatMessagesState();
 }
 
 class _ChatMessagesState extends State<ChatMessages> {
   final TextEditingController _messageController = TextEditingController();
   final FirebaseAuth _auth = FirebaseAuth.instance;
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
   Future<void> _sendMessage() async {
     if (_messageController.text.trim().isEmpty) return;
 
     final user = _auth.currentUser;
     if (user == null) return;
 
     await _firestore
         .collection('chatRooms')
         .doc(widget.chatRoomId)
         .collection('messages')
         .add({
       'text': _messageController.text.trim(),
       'senderId': user.uid,
       'senderEmail': user.email,
       'timestamp': FieldValue.serverTimestamp(),
     });
 
     _messageController.clear();
   }
 
   @override
   Widget build(BuildContext context) {
     return Column(
       children: [
         Expanded(
           child: StreamBuilder<QuerySnapshot>(
             stream: _firestore
                 .collection('chatRooms')
                 .doc(widget.chatRoomId)
                 .collection('messages')
                 .orderBy('timestamp', descending: true)
                 .snapshots(),
             builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
               }
 
               if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                 return const Center(child: Text('No messages yet.'));
               }
 
               final messages = snapshot.data!.docs;
 
               return ListView.builder(
                 reverse: true,
                 itemCount: messages.length,
                 itemBuilder: (context, index) {
                   final message = messages[index];
                   final isMe = message['senderId'] == _auth.currentUser?.uid;
return FutureBuilder<DocumentSnapshot>(
                     future: _firestore.collection('users').doc(message['senderId']).get(),
                     builder: (context, userSnapshot) {
                       if (userSnapshot.connectionState == ConnectionState.waiting) {
                         return const SizedBox.shrink();
                       }
 
                       final senderName = userSnapshot.data?['name'] ?? 'Unknown';
 
                       return Align(
                         alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                         child: Container(
                           margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(
                             color: isMe ? Colors.blue[100] : Colors.grey[300],
                             borderRadius: BorderRadius.circular(10),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 senderName,
                                 style: const TextStyle(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 12,
                                 ),
                               ),
                               const SizedBox(height: 5),
                               Text(
                                 message['text'] ?? '',
                                 style: const TextStyle(fontSize: 16),
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
         ),
         Padding(
           padding: const EdgeInsets.all(8.0),
           child: Row(
             children: [
               Expanded(
                 child: TextField(
                   controller: _messageController,
                   decoration: const InputDecoration(
                     hintText: 'Type a message...',
                     border: OutlineInputBorder(),
                   ),
                 ),
               ),
               const SizedBox(width: 10),
               IconButton(
                 icon: const Icon(Icons.send),
                 onPressed: _sendMessage,
               ),
             ],
           ),
         ),
       ],
     );
    }
 }