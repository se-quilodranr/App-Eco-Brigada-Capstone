import 'package:flutter_test/flutter_test.dart';
import 'package:ecobrigadasupabase/core/models.dart';
import 'package:ecobrigadasupabase/core/chat_permissions.dart';

void main(){
  const brigada=Brigada(id:'b',nombre:'Brigada ambiental',descripcion:'',
    comuna:'Concepción',liderUid:'lider',lat:-36.8,lng:-73.0,miembros:1,disponible:true);
  final miembros=[IntegranteBrigada(uid:'miembro',brigadaId:'b',
    nombre:'Integrante',fechaIngreso:DateTime.utc(2026,11,16))];
  test('Ciudadano ajeno no entra al chat',(){
    expect(puedeLeerChatBrigada(uid:'externo',administrador:false,
      brigada:brigada,integrantes:miembros),false);
  });
  test('Integrante aprobado puede entrar',(){
    expect(puedeLeerChatBrigada(uid:'miembro',administrador:false,
      brigada:brigada,integrantes:miembros),true);
  });
  test('Líder puede entrar sin pertenencia adicional',(){
    expect(puedeLeerChatBrigada(uid:'lider',administrador:false,
      brigada:brigada,integrantes:miembros),true);
  });
  test('Administrador puede entrar a otra brigada',(){
    expect(puedeLeerChatBrigada(uid:'admin',administrador:true,
      brigada:brigada,integrantes:miembros),true);
  });
}
