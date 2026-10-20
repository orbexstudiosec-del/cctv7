import 'dart:async';

import 'package:flutter/material.dart';

import 'schedule_slot.dart';

/// Badge "programa al aire ahora", al lado del chip EN VIVO. Sale de la
/// parrilla que el canal carga en el panel; si a esta hora no hay ningún
/// programa cargado, no se muestra.
class NowOnAirBadge extends StatefulWidget {
  const NowOnAirBadge({super.key, required this.tenantId, required this.accent});

  final String tenantId;
  final Color accent;

  @override
  State<NowOnAirBadge> createState() => _NowOnAirBadgeState();
}

class _NowOnAirBadgeState extends State<NowOnAirBadge> {
  late final Stream<List<ScheduleSlot>> _stream =
      ScheduleSlot.watch(widget.tenantId);
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Cambia solo cuando empieza el siguiente programa.
    _ticker = Timer.periodic(const Duration(minutes: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleSlot>>(
      stream: _stream,
      builder: (context, snapshot) {
        final current =
            snapshot.data?.where((s) => s.isOnAir(_now)).firstOrNull;
        if (current == null) return const SizedBox.shrink();

        // El verde de la marca es claro: sobre fondo blanco el texto se
        // oscurece para que se lea.
        final dark = Theme.of(context).brightness == Brightness.dark;
        final fg = dark
            ? widget.accent
            : Color.alphaBlend(
                Colors.black.withValues(alpha: 0.35), widget.accent);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: widget.accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 13, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
