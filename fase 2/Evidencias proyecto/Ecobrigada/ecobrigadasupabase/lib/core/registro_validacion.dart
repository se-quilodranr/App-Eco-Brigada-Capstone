/// Validaciones utilizadas por el formulario de registro de EcoBrigada.
/// La base de datos también verifica el RUT y aplica una restricción UNIQUE.
class RegistroValidacion {
  static String normalizarRut(String valor) =>
      valor.trim().toUpperCase().replaceAll('.', '').replaceAll(' ', '');

  static String? rut(String? texto) {
    final rut = normalizarRut(texto ?? '');
    if (!RegExp(r'^\d{7,8}-[\dK]$').hasMatch(rut)) {
      return 'Ingresa un RUT válido, por ejemplo 12.345.678-5.';
    }
    final partes = rut.split('-');
    final numero = partes.first;
    var suma = 0;
    var multiplicador = 2;
    for (var i = numero.length - 1; i >= 0; i--) {
      suma += int.parse(numero[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }
    final resto = 11 - (suma % 11);
    final dv = resto == 11 ? '0' : resto == 10 ? 'K' : '$resto';
    if (dv != partes.last) return 'El dígito verificador del RUT no coincide.';
    return null;
  }

  static String? obligatorio(String? value, String etiqueta, {int minimo = 2}) {
    if ((value ?? '').trim().length < minimo) {
      return 'Ingresa $etiqueta ($minimo caracteres como mínimo).';
    }
    return null;
  }

  static String? correo(String? texto) {
    final value = (texto ?? '').trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)
        ? null : 'Ingresa un correo electrónico válido.';
  }

  static String? contrasena(String? value) =>
      (value ?? '').length >= 6 ? null : 'La contraseña debe tener al menos 6 caracteres.';
}
