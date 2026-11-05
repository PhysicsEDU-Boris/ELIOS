import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:elio/l10n/l10n.dart';

const _learningGreen = Color(0xFF00694C);
const _learningBackground = Color(0xFFF8FAF9);

class ElioLearningAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final Widget? action;
  final Color backgroundColor;

  const ElioLearningAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.action,
    this.backgroundColor = _learningBackground,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: preferredSize.height,
      leadingWidth: 64,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _learningGreen,
                tooltip: l10n.lnBackToHub,
              ),
            )
          : const SizedBox(width: 64),
      centerTitle: true,
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: _learningGreen,
          fontSize: title == 'ELIOS' ? 22 : 18,
          fontWeight: FontWeight.w800,
          letterSpacing: title == 'ELIOS' ? -0.5 : -0.2,
        ),
      ),
      actions: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: action),
          ),
        ),
      ],
    );
  }
}
