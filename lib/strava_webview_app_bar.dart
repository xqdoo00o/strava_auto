import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'swipe_hint_animation.dart';

class StravaWebViewAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  const StravaWebViewAppBar({
    super.key,
    this.onReturnHome,
    this.enableSwipeReturn = false,
  });

  static const double height = 90;

  final VoidCallback? onReturnHome;
  final bool enableSwipeReturn;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<StravaWebViewAppBar> createState() => _StravaWebViewAppBarState();
}

class _StravaWebViewAppBarState extends State<StravaWebViewAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swipeHintController;
  late final Animation<double> _swipeHintAnimation;
  bool _hasPlayedSwipeHint = false;
  double _dragDx = 0;

  double get _visualDx {
    final dragOffset = _dragDx.clamp(-28.0, 8.0);
    return dragOffset + _swipeHintAnimation.value;
  }

  @override
  void initState() {
    super.initState();
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _swipeHintAnimation = buildSwipeHintAnimation(
      _swipeHintController,
      direction: -1,
    );
    _maybePlaySwipeHint();
  }

  @override
  void didUpdateWidget(covariant StravaWebViewAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enableSwipeReturn && widget.enableSwipeReturn) {
      _maybePlaySwipeHint();
    }
  }

  @override
  void dispose() {
    _swipeHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleTextStyle =
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    final title = SizedBox(
      height: StravaWebViewAppBar.height,
      child: Align(
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context)!.stravaWebViewTitle,
          style: titleTextStyle,
        ),
      ),
    );

    return AppBar(
      toolbarHeight: StravaWebViewAppBar.height,
      title: null,
      flexibleSpace: SafeArea(
        bottom: false,
        child: _buildHoverCursor(
          AnimatedBuilder(
            animation: _swipeHintAnimation,
            child: title,
            builder: (context, child) {
              final shiftedTitle = Transform.translate(
                offset: Offset(_visualDx, 0),
                child: child,
              );

              if (!widget.enableSwipeReturn) {
                return shiftedTitle;
              }

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _swipeHintController.stop();
                  _swipeHintController.reset();
                  setState(() {
                    _dragDx = 0;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dragDx += details.primaryDelta ?? 0;
                  });
                },
                onHorizontalDragEnd: _handleDragEnd,
                child: shiftedTitle,
              );
            },
          ),
        ),
      ),
      actions: [
        AnimatedBuilder(
          animation: _swipeHintAnimation,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              iconSize: 36,
              icon: const Icon(Icons.keyboard_double_arrow_right),
              onPressed: widget.onReturnHome,
            ),
          ),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_visualDx, 0),
              child: child,
            );
          },
        ),
      ],
    );
  }

  Widget _buildHoverCursor(Widget child) {
    return MouseRegion(cursor: SystemMouseCursors.resizeRight, child: child);
  }

  void _maybePlaySwipeHint() {
    if (!widget.enableSwipeReturn || _hasPlayedSwipeHint) return;
    _hasPlayedSwipeHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enableSwipeReturn) return;
      _swipeHintController.forward(from: 0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReturnHome = velocity < -250 || _dragDx < -36;
    setState(() {
      _dragDx = 0;
    });
    if (shouldReturnHome) {
      widget.onReturnHome?.call();
    }
  }
}
