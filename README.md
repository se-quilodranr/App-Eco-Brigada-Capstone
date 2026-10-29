#  Plataforma Comunitaria para la Recuperación de Espacios Públicos

Aplicación móvil orientada a conectar a personas y comunidades que quieran participar en la limpieza, recuperación y cuidado de espacios públicos. La plataforma busca facilitar el reporte de zonas con basura, la coordinación de brigadas de limpieza y el seguimiento de las acciones realizadas.

> **Estado del proyecto:** propuesta en desarrollo. Las funcionalidades descritas representan el alcance planificado y pueden estar sujetas a cambios durante la implementación.

##  Problema que aborda

En distintas comunidades existen espacios públicos con acumulación de basura y puntos de reciclaje que no siempre son conocidos por los vecinos. Además, puede ser difícil coordinar a las personas interesadas en colaborar o hacer seguimiento de las acciones que se realizan.

La aplicación propone centralizar esta información en un mapa colaborativo y ofrecer herramientas para organizar actividades, registrar resultados e incentivar la participación comunitaria.

##  Funcionalidades propuestas

###  Mapa colaborativo
- Registrar lugares que necesitan limpieza o recuperación.
- Visualizar zonas que ya fueron limpiadas.
- Identificar contenedores y puntos de reciclaje.
- Actualizar y validar información con ayuda de la comunidad.
- Consultar actividades de limpieza asociadas a distintas ubicaciones.

###  Brigadas de limpieza
- Crear actividades comunitarias de limpieza.
- Indicar la ubicación y el horario de cada actividad.
- Invitar a otras personas a participar.
- Facilitar que usuarios cercanos encuentren actividades a las que puedan unirse.

###  Trazabilidad de las intervenciones
- Mantener el historial de cada zona reportada.
- Registrar cuándo se informó sobre un lugar.
- Documentar quiénes participaron en la limpieza.
- Incorporar fotografías del antes y después.
- Registrar cuándo un espacio se marca como recuperado.

###  Puntos, rankings y desafíos
- Incentivar la participación mediante puntos.
- Reconocer a usuarios y comunidades mediante rankings.
- Proponer desafíos relacionados con la limpieza y el reciclaje.
- Considerar acciones como reportar lugares, verificar información y completar actividades.

###  Reciclaje y reutilización
- Compartir ideas para reutilizar materiales del hogar.
- Publicar fotografías de proyectos de reutilización.
- Mostrar los materiales necesarios y un paso a paso.
- Promover la educación ambiental y la creatividad.

##  Tecnologías

| Tecnología | Uso previsto |
|---|---|
| **Flutter** | Desarrollo de la aplicación móvil multiplataforma. |
| **Firebase** | Servicios de backend para las funciones que se definan, como autenticación y almacenamiento de información. |
| **Google Maps Platform API** | Integración de mapas y visualización de ubicaciones geográficas. |

> Los servicios específicos de Firebase y las APIs de Google Maps que se habiliten dependerán de la implementación final.

##  Requisitos previos

Para preparar el entorno de desarrollo, se necesitará:

- [Flutter SDK](https://docs.flutter.dev/get-started/install).
- [Dart](https://dart.dev/get-dart), incluido normalmente con Flutter.
- [Android Studio](https://developer.android.com/studio) o [Visual Studio Code](https://code.visualstudio.com/) con las extensiones correspondientes.
- Un proyecto configurado en [Firebase Console](https://console.firebase.google.com/).
- Una clave de API de Google Maps y los servicios necesarios habilitados en [Google Cloud Console](https://console.cloud.google.com/).

##  Instalación y ejecución

1. Clona este repositorio:

   ```bash
   git clone <URL-DEL-REPOSITORIO>
   ```

2. Ingresa a la carpeta del proyecto Flutter:

   ```bash
   cd <CARPETA-DEL-PROYECTO>
   ```

3. Instala las dependencias:

   ```bash
   flutter pub get
   ```

4. Configura la conexión con Firebase para las plataformas que utilizará la aplicación. La configuración debe corresponder al proyecto creado en Firebase.

5. Configura la clave de Google Maps siguiendo la documentación oficial para la plataforma de destino. **No publiques claves privadas ni archivos con credenciales sensibles en el repositorio.**

6. Comprueba los dispositivos disponibles y ejecuta la aplicación:

   ```bash
   flutter devices
   flutter run
   ```

> **Importante:** los pasos de configuración de Firebase y Google Maps pueden variar según la estructura del proyecto y las plataformas objetivo. Este README es una guía inicial; debe ajustarse a los archivos y dependencias reales del repositorio.

##  Objetivo del proyecto

Promover la participación ciudadana en la recuperación de espacios públicos mediante herramientas digitales que permitan identificar problemas, organizar iniciativas colaborativas, registrar los resultados e impulsar hábitos de limpieza, reciclaje y reutilización.

##  Próximos pasos sugeridos

- Definir los tipos de usuario y sus permisos.
- Diseñar el modelo de datos para reportes, ubicaciones, actividades e historiales.
- Implementar la autenticación y la persistencia de información.
- Integrar el mapa y la visualización de puntos geográficos.
- Desarrollar el registro y seguimiento de brigadas de limpieza.
- Incorporar las evidencias fotográficas y el historial de intervenciones.
- Definir las reglas para puntos, rankings y desafíos.
- Realizar pruebas funcionales y de usabilidad.

##  Contribuciones

Las sugerencias y mejoras son bienvenidas. Para contribuir, crea una rama para tus cambios y abre un *pull request* explicando qué modificaste y por qué.

##  Licencia

La licencia del proyecto está pendiente de definición. No se debe asumir una licencia de uso o distribución hasta que se incorpore una al repositorio.
