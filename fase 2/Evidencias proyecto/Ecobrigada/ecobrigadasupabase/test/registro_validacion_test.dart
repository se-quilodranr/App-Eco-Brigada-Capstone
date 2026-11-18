import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/core/registro_validacion.dart';

void main() {
  test('Normaliza RUT con puntos', () {
    expect(RegistroValidacion.normalizarRut('12.345.678-5'), '12345678-5');
  });
  test('Acepta RUT válido con dígito K', () {
    expect(RegistroValidacion.rut('6.123.456-K'), isNull);
  });
  test('Rechaza formato o dígito verificador incorrecto', () {
    expect(RegistroValidacion.rut('12.345.678-9'), isNotNull);
    expect(RegistroValidacion.rut('abc'), isNotNull);
  });
  test('Contraseña exige mínimo seis caracteres', () {
    expect(RegistroValidacion.contrasena('12345'), isNotNull);
    expect(RegistroValidacion.contrasena('123456'), isNull);
  });
  test('Nombre, apellido y comuna obligatorios', () {
    expect(RegistroValidacion.obligatorio(' ', 'tu comuna'), isNotNull);
    expect(RegistroValidacion.obligatorio('Concepción', 'tu comuna'), isNull);
  });
}
