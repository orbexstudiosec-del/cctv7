import 'dart:async';

import 'package:flutter/material.dart';

import 'schedule_slot.dart';

/// Parrilla de programación que el canal carga desde el panel, para ir
/// debajo del video (pestaña "Programación" de la pantalla del canal): así
/// se consulta sin dejar de ver la señal. Chips de día (hoy primero) y
/// los programas de ese día; resalta el que está al aire.
class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key, required this.tenantId, required this.accent});

  final String tenantId;
  final Color accent;

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  late final Stream<List<ScheduleSlot>> _stream =
      ScheduleSlot.watch(widget.tenantId);
  DateTime _now = DateTime.now();
  late int _day = _now.weekday;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Para que el "AL AIRE" cambie solo cuando empieza otro programa.
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
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<ScheduleSlot>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _Empty(text: 'No se pudo cargar la programación.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final slots =
            snapshot.data!.where((s) => s.days.contains(_day)).toList();
        // La semana empieza en hoy: con LUN primero, "HOY" (sábado, domingo)
        // quedaba al final de la fila, cortado fuera de la pantalla.
        final days = [
          for (var i = 0; i < 7; i++) (_now.weekday - 1 + i) % 7 + 1,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (i, d) in days.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                          d == _now.weekday ? 'HOY' : kWeekdaysShort[d - 1]),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _day == d ? Colors.white : scheme.onSurface,
                      ),
                      selected: _day == d,
                      selectedColor: widget.accent,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (slots.isEmpty)
              _Empty(
                  text: 'Todavía no hay programación cargada para el '
                      '${kWeekdays[_day - 1].toLowerCase()}.')
            else
              for (final (i, slot) in slots.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                _SlotCard(
                  slot: slot,
                  onAir: slot.isOnAir(_now),
                  accent: widget.accent,
                ),
              ],
          ],
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onAir,
    required this.accent,
  });

  final ScheduleSlot slot;
  final bool onAir;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: onAir ? accent.withValues(alpha: 0.12) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onAir ? accent : scheme.outlineVariant.withValues(alpha: 0.5),
          width: onAir ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.start,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                Text(slot.end,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onAir) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('AL AIRE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(slot.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                if (slot.host.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(slot.host,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
                if (slot.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(slot.description,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
