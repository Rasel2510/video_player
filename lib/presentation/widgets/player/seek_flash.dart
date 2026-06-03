import 'package:flutter/material.dart';

class SeekFlash extends StatelessWidget {
  final Animation<double> animation;
  final bool isForward;
  
  const SeekFlash({super.key, required this.animation, required this.isForward});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final opacity = (1.0 - animation.value).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity * 0.15),
              borderRadius: BorderRadius.horizontal(
                left: isForward ? Radius.zero : const Radius.circular(999),
                right: isForward ? const Radius.circular(999) : Radius.zero,
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward
                          ? Icons.forward_10_rounded
                          : Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isForward ? '+10s' : '-10s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
