import 'package:flutter/material.dart';

class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SmoothPageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Enter transition: Slide in from the right edge (Offset(1.0, 0.0)) to center
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 0.8, 0.2, 1.0), // Fast start, gentle ease-out deceleration
              reverseCurve: const Cubic(0.2, 0.8, 0.2, 1.0).flipped,
            ));

            // Exit transition: Slide out slightly to the left (Offset(-0.25, 0.0)) for parallax depth
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: const Cubic(0.2, 0.8, 0.2, 1.0),
              reverseCurve: const Cubic(0.2, 0.8, 0.2, 1.0).flipped,
            ));

            // A darkening overlay for the exiting page under the entering page
            final overlayFade = Tween<double>(
              begin: 0.0,
              end: 0.4,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.linear,
            ));

            return SlideTransition(
              position: slideOut,
              child: Stack(
                children: [
                  child,
                  // Custom shadow on the left edge of the entering screen to give it depth
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SlideTransition(
                      position: slideIn,
                      child: Container(
                        width: 20,
                        transform: Matrix4.translationValues(-20, 0, 0),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x05000000),
                              Color(0x18000000),
                              Color(0x35000000),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dark overlay for parallax depth when a screen is pushed on top of this one
                  if (secondaryAnimation.value > 0)
                    AnimatedBuilder(
                      animation: overlayFade,
                      builder: (context, _) {
                        return Container(
                          color: Colors.black.withValues(alpha: overlayFade.value),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
}

