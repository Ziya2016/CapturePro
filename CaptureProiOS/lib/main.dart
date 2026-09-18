import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CaptureProApp());
}

class CaptureProApp extends StatelessWidget {
  const CaptureProApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capture Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFFFF6D00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6D00),
          secondary: Color(0xFF7B1FA2),
          surface: Color(0xFF161B26),
          background: Color(0xFF0D1117),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
