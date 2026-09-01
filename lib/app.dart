import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth_screen.dart';
class App extends StatelessWidget{
  const App({super.key});
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Kelola Harian',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const DashboardScreen(),
      routes: {'/auth': (_)=> const AuthScreen()},
    );
  }
}
