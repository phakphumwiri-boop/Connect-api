import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() => runApp(const IshApp());

class IshApp extends StatelessWidget {
  const IshApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ISH Assistant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      );
}
