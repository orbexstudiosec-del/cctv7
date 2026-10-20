import 'package:flutter/material.dart';

import '../shared/theme.dart';
import 'schedule_repository.dart';
import 'schedule_slot.dart';
import 'widgets/schedule_form_dialog.dart';

/// Parrilla de programación: se elige un día y se ven sus programas en
/// orden de hora. Lo que se cambie acá lo ve la app al instante (menú
/// "Programación").
class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.tenantId,
    required this.repository,
    required this.canManage,
  });

  final String tenantId;
  final ScheduleRepository repository;
  final bool canManage;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  int _day = DateTime.now().weekday;

  void _openForm({ScheduleSlot? existing}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScheduleFormDialog(
        tenantId: widget.tenantId,
        repository: widget.repository,
        existing: existing,
        initialDay: _day,
      ),
    );
  }

  Future<void> _confirmDelete(ScheduleSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar programa'),
        content: Text(
          '¿Eliminar "${slot.title}" de la parrilla? Se quita de todos sus '
          'días (${slot.days.map((d) => kWeekdaysShort[d - 1]).join(', ')}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.repository.delete(widget.tenantId, slot.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<ScheduleSlot>>(
      stream: widget.repository.watch(widget.tenantId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final slots = all.where((s) => s.days.contains(_day)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        ChoiceChip(
                          label: Text(
                            '${kWeekdays[d - 1]}'
                            ' (${all.where((s) => s.days.contains(d)).length})',
                          ),
                          selected: _day == d,
                          onSelected: (_) => setState(() => _day = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6)),
                      boxShadow: floatingShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  kWeekdays[_day - 1],
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              if (widget.canManage)
                                TextButton.icon(
                                  onPressed: () => _openForm(),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Agregar a este día'),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (slots.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No hay programas cargados para este día.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          )
                        else
                          for (final (i, slot) in slots.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 24),
                            _SlotRow(
                              slot: slot,
                              canManage: widget.canManage,
                              onEdit: () => _openForm(existing: slot),
                              onDelete: () => _confirmDelete(slot),
                            ),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Los cambios se ven al instante en la app, en el '
                          'menú "Programación". Un programa puede repetirse '
                          'varios días: se edita una sola vez.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleSlot slot;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = slot.days.length == 7
        ? 'Todos los días'
        : slot.days.length == 5 && slot.days.every((d) => d <= 5)
            ? 'Lunes a viernes'
            : slot.days.map((d) => kWeekdaysShort[d - 1]).join(', ');

    return InkWell(
      onTap: canManage ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 112,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${slot.start} – ${slot.end}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    [if (slot.host.isNotEmpty) slot.host, days].join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (canManage) ...[
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Eliminar',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
