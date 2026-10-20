import 'package:flutter/material.dart';

import '../schedule_repository.dart';
import '../schedule_slot.dart';

/// Alta / edición de un programa de la parrilla: nombre, conductor,
/// descripción, días y horario.
class ScheduleFormDialog extends StatefulWidget {
  const ScheduleFormDialog({
    super.key,
    required this.tenantId,
    required this.repository,
    this.existing,
    this.initialDay,
  });

  final String tenantId;
  final ScheduleRepository repository;
  final ScheduleSlot? existing;

  /// Día preseleccionado al crear desde la columna de un día.
  final int? initialDay;

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _host = TextEditingController(text: widget.existing?.host);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final Set<int> _days = {
    ...?widget.existing?.days,
    if (widget.existing == null && widget.initialDay != null) widget.initialDay!,
  };
  late TimeOfDay _start = _parse(widget.existing?.start ?? '06:00');
  late TimeOfDay _end = _parse(widget.existing?.end ?? '07:00');
  bool _saving = false;
  String? _error;

  static TimeOfDay _parse(String hhmm) {
    final m = ScheduleSlot.toMinutes(hhmm);
    return TimeOfDay(hour: m ~/ 60 % 24, minute: m % 60);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _title.dispose();
    _host.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Hora de inicio' : 'Hora de fin',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final start = _start.hour * 60 + _start.minute;
    final endRaw = _end.hour * 60 + _end.minute;
    final end = endRaw == 0 ? 24 * 60 : endRaw;
    String? error;
    if (_days.isEmpty) {
      error = 'Elegí al menos un día.';
    } else if (end <= start) {
      error = 'La hora de fin tiene que ser después del inicio '
          '(para terminar a medianoche usá 00:00).';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        widget.tenantId,
        existing: widget.existing,
        title: _title.text.trim(),
        host: _host.text.trim(),
        description: _description.text.trim(),
        days: _days.toList(),
        start: _fmt(_start),
        end: _fmt(_end),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo programa' : 'Editar programa'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: widget.existing == null,
                  decoration: const InputDecoration(labelText: 'Nombre del programa'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Poné un nombre' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: 'Conductor / presentador (opcional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Descripción (opcional)'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Días', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _days
                        ..clear()
                        ..addAll([1, 2, 3, 4, 5])),
                      child: const Text('Lun a Vie'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _days
                        ..clear()
                        ..addAll([1, 2, 3, 4, 5, 6, 7])),
                      child: const Text('Todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(kWeekdaysShort[d - 1]),
                        selected: _days.contains(d),
                        onSelected: (sel) => setState(
                            () => sel ? _days.add(d) : _days.remove(d)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Inicio',
                        value: _fmt(_start),
                        onTap: () => _pick(true),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _TimeField(
                        label: 'Fin',
                        value: _fmt(_end),
                        onTap: () => _pick(false),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
