import 'package:flutter/material.dart';
import 'package:alzitrans/l10n/app_localizations.dart';

import 'line_filter.dart';

/// Parte superior del mapa: barra de búsqueda (con el aviso de lluvia o
/// tráfico debajo) y filtro de líneas a la derecha.
///
/// Van en la misma fila: la barra ocupa lo que deja el filtro, así no se
/// pisan aunque el filtro cambie de ancho (idioma, tamaño de letra).
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.selectedLines,
    required this.onLineToggle,
    required this.onSearchTap,
    this.belowSearch,
  });

  final Set<String> selectedLines;
  final Function(String) onLineToggle;
  final VoidCallback onSearchTap;

  /// Lo que va bajo la búsqueda (el aviso de lluvia / tráfico).
  final Widget? belowSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const Key('map_search_bar'),
                onTap: onSearchTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).searchStopByName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (belowSearch != null) belowSearch!,
            ],
          ),
        ),
        const SizedBox(width: 12),
        LineFilter(
          key: const Key('map_line_filter'),
          selectedLines: selectedLines,
          onLineToggle: onLineToggle,
        ),
      ],
    );
  }
}
