import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

InlineSpan buildTitleBadge(String? title, {double fontSize = 10, double rightMargin = 6}) {
  if (title == null || title.trim().isEmpty) {
    return const WidgetSpan(child: SizedBox.shrink());
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
      margin: EdgeInsets.only(right: rightMargin),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700), // Pure Gold
            Color(0xFFFFA500), // Orange Gold
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: const Color(0xFFB8860B), // Dark Goldenrod
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        title.trim().toUpperCase(),
        style: GoogleFonts.inter(
          color: const Color(0xFF1A1A2E), // Premium dark background contrast
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

Widget buildFullTitleBadge(String? title, {double fontSize = 9}) {
  if (title == null || title.trim().isEmpty) {
    return const SizedBox.shrink();
  }
  
  String fullTitle = title;
  switch (title.trim().toUpperCase()) {
    case 'GM': fullTitle = 'Grandmaster'; break;
    case 'IM': fullTitle = 'International Master'; break;
    case 'FM': fullTitle = 'FIDE Master'; break;
    case 'CM': fullTitle = 'Candidate Master'; break;
    case 'WGM': fullTitle = 'Woman Grandmaster'; break;
    case 'WIM': fullTitle = 'Woman International Master'; break;
    case 'WFM': fullTitle = 'Woman FIDE Master'; break;
    case 'WCM': fullTitle = 'Woman Candidate Master'; break;
  }

  return Container(
    margin: const EdgeInsets.only(top: 4, bottom: 2),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFFD700), // Pure Gold
          Color(0xFFFFA500), // Orange Gold
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: const Color(0xFFB8860B), // Dark Goldenrod
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 1.5,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Text(
      fullTitle.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF1A1A2E),
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        height: 1.0,
        letterSpacing: 0.4,
      ),
    ),
  );
}
