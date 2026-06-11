import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';

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

class _StravaWebViewAppBarState extends State<StravaWebViewAppBar> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    final title = SizedBox(
      height: StravaWebViewAppBar.height,
      child: Align(
        alignment: Alignment.center,
        child: Text(AppLocalizations.of(context)!.stravaWebViewTitle),
      ),
    );

    return AppBar(
      toolbarHeight: StravaWebViewAppBar.height,
      centerTitle: true,
      title: widget.enableSwipeReturn
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) {
                _dragDx = 0;
              },
              onHorizontalDragUpdate: (details) {
                _dragDx += details.primaryDelta ?? 0;
              },
              onHorizontalDragEnd: _handleDragEnd,
              child: title,
            )
          : title,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: widget.onReturnHome,
        ),
      ],
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReturnHome = velocity < -250 || _dragDx < -36;
    _dragDx = 0;
    if (shouldReturnHome) {
      widget.onReturnHome?.call();
    }
  }
}
