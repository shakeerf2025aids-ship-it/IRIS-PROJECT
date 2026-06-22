import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/iris_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // Check if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          // User is logged in, go to dashboard
          context.go('/dashboard');
        } else {
          // User is not logged in, go to welcome
          context.go('/welcome');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Hero(
          tag: 'app_logo',
          child: IrisLogo(size: 150),
        ),
      ),
    );
  }
}
