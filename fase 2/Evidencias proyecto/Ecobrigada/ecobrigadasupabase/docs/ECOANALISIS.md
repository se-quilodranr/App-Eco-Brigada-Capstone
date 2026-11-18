# EcoAnálisis — EcoBrigada 2.0

Versión: 1.0 | Fecha: 13-11-2026

## Objetivo

Añadir **cuatro análisis determinísticos** sin necesidad de entrenar Machine Learning ni agregar servicios externos. Se usan las incidencias ya almacenadas en memoria por `EcoStore`.

## Funciones implementadas

| Componente | Archivo | Método | Resultado |
|---|---|---|---|
| EcoZonas | `lib/core/eco_analisis.dart` | `detectarEcoZonas` | Conjuntos de 3 o más incidencias abiertas conectadas a 250 m; centro, radio e índice orientativo |
| EcoReincidencia | mismo | `detectarEcoReincidencia` | Nuevos reportes abiertos del mismo tipo posteriores a un cierre y a menos de 150 m (máximo 180 días) |
| EcoTendencias | mismo | `calcularEcoTendencias` | Reportados y resueltos durante 8 semanas, promedio móvil de 3 períodos y variación semanal |
| EcoAlerta | mismo | `calcularEcoAlertas` | Casos vencidos o que vencen dentro de 24 h según plazos orientativos: prioridad alta 2 d, media 5 d, baja 10 d |

La agrupación de EcoZonas es un **grafo de proximidad**, no DBSCAN. No necesita datos etiquetados ni entrenamiento. Usa distancias en metros sobre coordenadas. Su coste es O(n²), aceptable para un MVP de hasta 400 reportes.

**Los resultados NO prueban contaminación real, ni corresponden a predicciones futuras.** Un nuevo reporte cercano a un caso resuelto es una *posible reincidencia* que requiere revisión humana; no una reincidencia confirmada.

## Integración visual

- `EcoImpacto`: sección **EcoAnálisis** con cuatro bloques, gráfico de barras semanales, resumen territorial, reincidencia y alertas.
- `EcoMapa`: icono de capas sobre el mapa. Actívalo/desactívalo para dibujar zonas calculadas a partir de los marcadores actualmente filtrados (por GPS/estado).
- Vista pública: información agregada. Vista admin: detalle de casos, coordenadas del centro aproximado y alertas.
- **No se añade una sexta pestaña**. La navegación y los roles anteriores permanecen intactos.


## Validación en entorno real
Los algoritmos operan sobre los reportes obtenidos desde Supabase PostgreSQL.
No crean ni cargan datos ficticios. La paginación actual carga hasta 1500 reportes y
los resultados no representan una medición ambiental independiente.

Pruebas: `flutter test test/eco_analisis_test.dart`.

## Integración con la estructura Supabase antigua

La versión anterior ya tenía puntos `lugares` con estados `sucio` y `limpio`, y su tabla `lugar_historial`. El archivo `lib/core/reincidencia_lugares.dart` analiza los cambios **limpio → sucio** y calcula el intervalo entre ambas fechas registradas. Se muestra en EcoImpacto además de la comparación entre `incidencias` nuevas. No corresponde a una medición directa de contaminación ni a una predicción de su reaparición.
