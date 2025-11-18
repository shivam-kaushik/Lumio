import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// Modern page transitions for smooth navigation
class PageTransitions {
  /// Shared axis transition (Material You style)
  static PageRouteBuilder<T> sharedAxis<T>({
    required Widget page,
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Fade through transition
  static PageRouteBuilder<T> fadeThrough<T>({
    required Widget page,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Open container (morph transition)
  static PageRouteBuilder<T> openContainer<T>({
    required Widget page,
    required Widget closedBuilder,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return OpenContainer(
          closedBuilder: closedBuilder,
          openBuilder: (context, _) => page,
          transitionDuration: const Duration(milliseconds: 400),
          closedElevation: 0,
          openElevation: 0,
        ).buildTransitions(
          page,
          context,
          animation,
          secondaryAnimation,
          child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Slide transition with custom direction
  static PageRouteBuilder<T> slide<T>({
    required Widget page,
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));
        
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }
}

