import 'package:flutter/material.dart';
import '../../viewmodels/pet_viewmodel.dart';

class AnimatedPet extends StatefulWidget {
  final String imagePath;
  final PetMood mood;

  const AnimatedPet({
    super.key,
    required this.imagePath,
    required this.mood,
  });

  @override
  State<AnimatedPet> createState() => _AnimatedPetState();
}

class _AnimatedPetState extends State<AnimatedPet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> floatAnimation;
  late Animation<double> shakeAnimation;
  late Animation<double> scaleAnimation;

  // ✅ Dynamic speed based on mood
  Duration _getDuration() {
    switch (widget.mood) {
      case PetMood.happy:
        return const Duration(milliseconds: 1000);
      case PetMood.neutral:
        return const Duration(milliseconds: 1000);
      case PetMood.sad:
        return const Duration(milliseconds: 1000);
      case PetMood.angry:
        return const Duration(milliseconds: 500);
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _getDuration(),
    );

    floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );

    scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AnimatedPet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.mood != widget.mood) {
      // ✅ Update animation speed
      _controller.duration = _getDuration();

      // ✅ Bounce once + continue loop
      _controller.stop();
      _controller.forward(from: 0).then((_) {
        _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 🔥 Bonus: tap to animate
        _controller.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          double dx = 0;
          double dy = floatAnimation.value;
          double scale = 1.0;

          switch (widget.mood) {
            case PetMood.happy:
              scale = scaleAnimation.value; // bounce
              break;

            case PetMood.neutral:
              dy = floatAnimation.value / 2; // calm float
              break;

            case PetMood.sad:
              dy = floatAnimation.value / 3; // slow float
              break;

            case PetMood.angry:
              dx = shakeAnimation.value; // shake
              break;
          }

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          );
        },

        // 🔥 Smooth transition between images
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: ClipRRect(
            key: ValueKey(widget.imagePath),
            borderRadius: BorderRadius.circular(30),
            child: Image.asset(
              widget.imagePath,
              height: 240,
              width: 240,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}