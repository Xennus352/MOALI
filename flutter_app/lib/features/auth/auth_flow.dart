import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

/// Hosts the sign-in and create-account screens and swaps between them with a
/// soft cross-fade. Language changes re-render in place (the child widget keeps
/// its position and key), so anything typed is preserved.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key, required this.onSignedIn});

  final ValueChanged<SessionUser> onSignedIn;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final child = _showRegister
        ? RegisterScreen(
            key: const ValueKey('register'),
            onSignedIn: widget.onSignedIn,
            onSwitchToLogin: () => setState(() => _showRegister = false),
          )
        : LoginScreen(
            key: const ValueKey('login'),
            onSignedIn: widget.onSignedIn,
            onSwitchToRegister: () => setState(() => _showRegister = true),
          );

    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
