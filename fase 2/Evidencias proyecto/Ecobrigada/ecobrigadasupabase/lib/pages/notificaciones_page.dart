import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/design.dart';
import '../widgets/common.dart';

class NotificacionesPage extends StatelessWidget {
  const NotificacionesPage({super.key,required this.store});
  final EcoStore store;
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Notificaciones'),actions:[
      IconButton(tooltip:'Actualizar',onPressed:()=>store.refrescar(),
        icon:const Icon(Icons.refresh_rounded))]),
    body:AnimatedBuilder(animation:store,builder:(context,_)=>
      store.notificaciones.isEmpty
      ?const EmptyEco(titulo:'Sin notificaciones',
        descripcion:'Aquí recibirás las novedades de tus reportes y brigadas.')
      :ListView.builder(padding:const EdgeInsets.all(18),
        itemCount:store.notificaciones.length,
        itemBuilder:(context,i){
          final n=store.notificaciones[i];
          final leida=n['leida_en']!=null;
          return Card(color:leida?null:EcoColors.mint,child:ListTile(
            leading:Icon(leida?Icons.notifications_none:Icons.notifications_active,
              color:EcoColors.green),
            title:Text('${n['titulo']??'Aviso'}'),
            subtitle:Text('${n['cuerpo']??''}'),
            trailing:leida?null:const Icon(Icons.circle,size:10,color:EcoColors.green),
            onTap:() async{
              if(!leida){try{await store.marcarNotificacion('${n['id']}');}
                catch(e){if(context.mounted)mostrarError(context,e);}}
            }));
        })));
}
