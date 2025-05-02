import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/buyermarketplace.dart';
import 'screens/login.dart';
import 'screens/chatScreen.dart';
import 'screens/favoritesScreen.dart';
import 'services/apiServices.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MultiProvider(
    providers: [
      Provider(create: (_) => Apiservices()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Art Marketplace',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/buyermarketplace': (context) => BuyerMarketplace(),
        '/chat': (context) => ChatScreen(
              chatId: ModalRoute.of(context)!.settings.arguments as String,
              userName: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/favorites': (context) => FavoritesScreen(),
      },
    );
  }
}