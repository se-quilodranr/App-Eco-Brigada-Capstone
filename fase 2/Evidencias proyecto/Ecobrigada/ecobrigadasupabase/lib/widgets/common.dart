import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/models.dart';

class EcoSection extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const EcoSection({super.key, required this.title, this.subtitle = '', this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: EcoColors.forest)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: EcoColors.muted)),
        ],
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class EcoPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const EcoPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: EcoColors.line)), child: child,
  );
}

class Indicador extends StatelessWidget {
  final String titulo, valor;
  final IconData icono;
  final Color acento;
  const Indicador({super.key, required this.titulo, required this.valor,
    required this.icono, this.acento = EcoColors.green});
  @override
  Widget build(BuildContext context) => EcoPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 43, height: 43, decoration: BoxDecoration(
        color: acento.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
        child: Icon(icono, color: acento, size: 23)),
      const SizedBox(height: 18),
      Text(valor, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
        color: EcoColors.forest)),
      const SizedBox(height: 4),
      Text(titulo, style: const TextStyle(fontSize: 12.5, color: EcoColors.muted,
        fontWeight: FontWeight.w600)),
    ]),
  );
}

Color colorEstado(String estado) => switch (estado) {
  'pendiente' => const Color(0xFFAD7526),
  'validado' => const Color(0xFF5871B5),
  'asignado' => const Color(0xFF3978A7),
  'en_proceso' => const Color(0xFF946E20),
  'en_revision' => const Color(0xFF895EA3),
  'cerrado' => EcoColors.green,
  _ => EcoColors.muted,
};

class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip({super.key, required this.estado});
  @override
  Widget build(BuildContext context) {
    final c = colorEstado(estado);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20)),
      child: Text(estadoNombre(estado), style: TextStyle(fontWeight: FontWeight.w700,
        color: c, fontSize: 11)));
  }
}

class ReporteTile extends StatelessWidget {
  final Reporte reporte;
  final VoidCallback? onTap;
  const ReporteTile({super.key, required this.reporte, this.onTap});
  @override
  Widget build(BuildContext context) => EcoPanel(
    padding: EdgeInsets.zero,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: EcoColors.pale,
            borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.location_on_rounded, color: EcoColors.green)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reporte.titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800,
              color: EcoColors.text, fontSize: 14)),
          const SizedBox(height: 5),
          Text('${reporte.comuna} · ${reporte.tipo}', maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: EcoColors.muted)),
          const SizedBox(height: 8),
          EstadoChip(estado: reporte.estado),
        ])),
        const SizedBox(width: 6),
        Text('${reporte.prioridad}', style: const TextStyle(
          color: EcoColors.forest, fontWeight: FontWeight.w800)),
        const Icon(Icons.chevron_right_rounded, color: EcoColors.muted),
      ]))),
  );
}

Future<void> mostrarError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error.toString().replaceAll('Bad state: ', '').replaceAll('Invalid argument(s): ', '')),
    behavior: SnackBarBehavior.floating,
  ));
}

class EmptyEco extends StatelessWidget {
  final String titulo, descripcion;
  final IconData icono;
  const EmptyEco({super.key, required this.titulo, required this.descripcion,
    this.icono = Icons.search_off_rounded});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(30),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, color: EcoColors.muted, size: 52),
      const SizedBox(height: 12),
      Text(titulo, textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 8),
      Text(descripcion, textAlign: TextAlign.center,
        style: const TextStyle(color: EcoColors.muted)),
    ]),
  ));
}

Widget responsiveWrap(List<Widget> children, {double width = 225, double spacing = 12}) =>
  LayoutBuilder(builder: (context, constraints) {
    final cols = constraints.maxWidth < 530 ? 2 : (constraints.maxWidth / width).floor().clamp(2, 4);
    final itemWidth = (constraints.maxWidth - (cols - 1) * spacing) / cols;
    return Wrap(spacing: spacing, runSpacing: spacing,
      children: children.map((w) => SizedBox(width: itemWidth, child: w)).toList());
  });
