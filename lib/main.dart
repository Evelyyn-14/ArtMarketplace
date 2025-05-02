import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login.dart';
import 'screens/favoritesScreen.dart';
import 'screens/chatScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/favorites': (context) => FavoritesScreen(),
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

          if (args == null || args['chatId'] == null || args['userName'] == null) {
            throw Exception('Missing required arguments: chatId and userName');
          }

          return ChatScreen(
            chatId: args['chatId'] as String,
            userName: args['userName'] as String,
          );
        },
      },
    );
  }
}