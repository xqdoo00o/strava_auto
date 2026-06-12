import 'package:flutter/animation.dart';

Animation<double> buildSwipeHintAnimation(
  AnimationController controller, {
  required double direction,
}) {
  return TweenSequence<double>([
    _swipeStep(direction * 12, 30),
    _swipeStep(0, 30, begin: direction * 12),
    _swipeStep(direction * 9, 24),
    _swipeStep(0, 24, begin: direction * 9),
    _swipeStep(direction * 7, 20),
    _swipeStep(0, 20, begin: direction * 7),
    _swipeStep(direction * 5, 16),
    _swipeStep(0, 16, begin: direction * 5),
  ]).animate(controller);
}

TweenSequenceItem<double> _swipeStep(
  double end,
  double weight, {
  double begin = 0,
}) {
  final curve = end == 0 ? Curves.easeInOutCubic : Curves.easeOutCubic;
  return TweenSequenceItem(
    tween: Tween(begin: begin, end: end).chain(CurveTween(curve: curve)),
    weight: weight,
  );
}
