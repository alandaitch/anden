# Features del mundo: apps de trenes y transporte

Investigación para Andén (arribos de trenes urbanos en Buenos Aires, iOS, SwiftUI).

Objetivo: robar ideas de features. Foco en el commuter diario, no en el turista.

---

## Transit (transitapp.com)

Referente directo de la categoría. Cubre 180+ agencias de transporte.

- Feature GO: modo "acompañante de viaje" puerta a puerta.
- GO usa GPS y sensor de movimiento. Detecta si caminás, esperás o viajás.
- GO manda alertas por etapa: "Salí ya", "Apurate", "Tu parada está a X paradas".
- GO avisa "Podrías perder la combinación" si el tramo previo se atrasa.
- GO avisa "Bajate ahora" en la parada de destino o de trasbordo.
- GO funciona con audio. Sirve con música puesta o con el teléfono guardado.
- Muestra datos crowdsourced: nivel de ocupación, puntualidad, mejor salida de estación.
- Tuvo widget de pantalla de inicio. Lo discontinuó por límites técnicos de iOS.
- El widget sigue en el radar de Transit. Busca alternativa técnica.
- Sin Live Activity propia confirmada al momento de esta investigación.
- Apps satélite como "Transit Glance" (Chicago, no oficial) sí ofrecen Live Activity y Dynamic Island sobre datos de Transit/CTA.

**Killer feature para robar:** el modo GO. Convierte un horario estático en un compañero de viaje activo con alertas por etapa.

---

## Citymapper

Foco en la experiencia de viaje completo, no solo en el horario.

- Lock Screen Navigation: seguís el viaje sin desbloquear el teléfono.
- Usa Live Activity. En iPhone 14 Pro en adelante, aparece en la Dynamic Island.
- Por etapa muestra información distinta y relevante.
- Caminando al origen: distancia, próximo giro, instrucciones de voz.
- Yendo a la estación: salidas en vivo. Referencia textual: "para saber si llegás a tomar un café".
- En la estación: hora de salida, vagón recomendado, alertas de retraso.
- Viajando: paradas restantes y aviso antes de la parada final.
- En NYC y Londres: recomienda el vagón según la salida más rápida en destino.
- Lock screen navigation es gratis desde la adquisición por Via.

**Killer feature para robar:** el contenido del Live Activity cambia según la etapa del viaje. No es un contador fijo, es contextual.

---

## Moovit

Foco en cobertura masiva de agencias y en señal crowdsourced.

- Arribos en tiempo real desde GPS de buses y trenes.
- Combina GTFS estático (horarios) con GTFS-Realtime (posición y demora).
- Guía turn-by-turn: cuándo caminar, qué entrada de estación usar, qué tren tomar.
- "Get Off Alert": avisa cuando te acercás a tu parada, con tracking de progreso en vivo.
- Alertas instantáneas de cambios de servicio, demoras e incidentes de tránsito.
- Accesibilidad: pantallas optimizadas para VoiceOver y TalkBack.
- Muestra accesibilidad para sillas de ruedas en paradas y vehículos.

**Killer feature para robar:** Get Off Alert. Simple, sin fricción, resuelve el miedo real de pasarse de parada.

---

## DB Navigator (Deutsche Bahn, Alemania)

Foco en el commuter de cercanías con trayecto fijo.

- Cuatro widgets en iOS: Pendler (commuter), Reisebegleitung, Favoriten, Abfahrten.
- El widget Pendler guarda un trayecto origen-destino fijo.
- Muestra conexiones en tiempo real para ese trayecto sin abrir la app.
- Push notifications de demoras y cambios de horario.
- Muestra la composición del tren (orden de coches) para ubicar el andén correcto.
- No tiene Live Activity ni lock screen widget documentado en fuentes oficiales.

**Killer feature para robar:** el widget "Pendler" es un trayecto guardado, no una búsqueda. Cero fricción para el uso diario.

---

## Trainline

Foco en gestión de disrupciones y en Live Activity de alta fidelidad.

- Diciembre 2025: mayor actualización de su historia.
- "Travel forecast": predice si tu tren va a demorarse o cancelarse, antes de que pase.
- "Delay repay notifications": avisa si tenés derecho a reembolso por demora.
- Chatbot de IA como asistente de viaje en vivo.
- "Train swap": cambiás de tren y seguís recibiendo tracking del nuevo viaje.
- Live Activity en lock screen y Dynamic Island.
- El Live Activity muestra: plataforma, barra de progreso animada, hora de llegada actualizada, y acceso directo a la app.
- Ante demora, el Live Activity ofrece "reconocer la demora" o "reservar otro tren" sin abrir la app.
- Principio de diseño declarado: primero función, después estética. "Qué necesita saber el usuario de un vistazo."

**Killer feature para robar:** el Live Activity no es solo informativo. Tiene una acción (rebooking) resuelta ahí mismo.

---

## SNCF Connect (Francia)

Foco en el widget de horarios de estación.

- Widget "Horaires en gare": horarios de salida y llegada de una estación guardada.
- El widget muestra plataforma y estado del tráfico sin abrir la app.
- Alertas activables por trayecto guardado: demoras, incidentes, obras.
- Búsqueda de tren en vivo por número de tren desde el buscador principal.
- Sección "Info Trafic" centraliza el estado de todas las líneas en tiempo real.

**Killer feature para robar:** widget de estación (no de línea). Sirve para cualquiera que pase por ahí, no solo para un trayecto fijo.

---

## Renfe Cercanías (España, relanzada 2026)

La más nueva de la lista. Rediseño completo con foco en el commuter de cercanías.

- Widget de estación principal en pantalla de inicio, sin abrir la app.
- IA cruza circulación, señalización y ocupación para estimar la espera.
- Buscador con lenguaje natural: origen, destino, fecha, hora.
- Detecta la estación más cercana por geolocalización, en home y en mapa.
- Mapa interactivo: estaciones, líneas, parkings de bicicletas cercanos.
- Favoritos de estaciones y trayectos, accesibles desde la pantalla de inicio.
- Seguimiento en tiempo real del trayecto planificado por el usuario.
- Alertas personalizadas cuando el tren habitual del usuario se demora.
- Prensa la describe como "no parece de Renfe": diseño moderno, no burocrático.

**Killer feature para robar:** "tren habitual del usuario". La app infiere el trayecto recurrente y alerta solo sobre ese.

---

## Yahoo!乗換案内 (Japón)

La app de rutina diaria más madura del mundo. Cultura de commuting en tren muy exigente.

- "Mi horario" (マイ時刻表): guardás un horario de salida específico.
- Widget de lock screen con countdown de salida, en dos formas.
- Forma circular: estación, countdown, estado del tráfico. Mínimo.
- Forma rectangular: estación, destino, si es cabecera, tipo de tren, countdown, tráfico.
- El widget de lock screen solo puede mostrar "Mi horario". No admite otros widgets ahí.
- Feature "TrainCast": mapa con íconos de trenes en movimiento en tiempo real sobre la red.
- Widget adicional: saldo de tarjeta IC (Suica/Pasmo) y último tren de la noche.
- El "último tren" (終電) es una categoría de búsqueda propia. Crítico en Japón por el cierre del servicio nocturno.

**Killer feature para robar:** dos densidades de widget (circular mínimo vs. rectangular completo) para el mismo dato. El usuario elige cuánta información quiere ver.

---

## Japan Travel / NAVITIME

Foco en navegación multimodal con datos de demora accionables.

- Notificaciones de demora en tiempo real por línea.
- Ante demora, ofrece re-routear evitando el tramo afectado, desde la misma pantalla.
- Guía de plataforma: qué andén y qué extremo del andén conviene pisar.
- Funciona offline para rutas ya calculadas.
- Integra JR Pass y buscador de wifi como capas turísticas (no aplica a un commuter local).

**Killer feature para robar:** re-routeo con un tap ante demora, sin recalcular todo desde cero.

---

## CityTrain / TrainTime (MTA, Nueva York)

TrainTime es la app oficial de MTA para LIRR y Metro-North (trenes de cercanías, no subte).

- Comprás y usás boletos desde la app.
- Tracking del tren en el mapa.
- Datos en vivo desde el feed GTFS-Realtime oficial de MTA.

Apps de terceros sobre el mismo feed muestran mejor qué es posible sin backend propio:

- **Subway Time NYC**: widgets de home y lock screen, favoritos, estaciones cercanas, alertas de servicio, tracking en vivo, mapa offline.
- **NYC Subway Widget**: el widget detecta si estás en casa (muestra la estación favorita) o afuera (muestra estaciones cercanas), sin abrir la app.
- **trainETA.com**: mapa en vivo. Poll al feed GTFS-RT cada ~12 segundos. Mismos datos que los relojes de andén oficiales.
- **RideOnTime**: pensada para pantalla fija (kiosco de cocina/escritorio), no solo para el teléfono.

**Killer feature para robar:** el widget que detecta ubicación y cambia solo entre "modo casa" y "modo afuera". Es la versión automática del favorito con contexto.

---

## Amtrak (oficial) y trackers de terceros

La app oficial de Amtrak es conservadora. Los trackers de terceros muestran el techo de lo posible con un solo dev.

- Amtrak oficial: notificación push de andén y puerta de embarque en estaciones seleccionadas.
- **Tracky**: estado del tren en lock screen y Dynamic Island.
- **Train Tracker Pro**: ubicación en vivo, clima en la ubicación del tren, Siri, Live Activity en lock screen y en el Smart Stack del Apple Watch.
- **RailTrak**: Live Activity iniciable desde la propia app, con updates en Dynamic Island en iPhone 14 Pro en adelante.

**Killer feature para robar:** estas son apps de un solo desarrollador, sin backend propio, consumiendo un feed público. Es la prueba de que el approach de Andén (GPS del tren + API pública, sin servidor propio) alcanza para Live Activity de calidad.

---

## Categoría "next train countdown" en general

Patrón técnico común en toda la categoría, no de una app puntual.

- GTFS-Realtime es el estándar de facto para posición de vehículo y demora.
- GTFS estático (horario programado) es el fallback cuando no hay señal en vivo.
- El patrón correcto: cargar GTFS estático local u offline, superponer GTFS-RT cuando hay red.
- Polling típico de apps con mapa en vivo: cada 10-15 segundos.
- Viudez de datos: cuando el feed en vivo cae, la app debe caer a horario programado, nunca a pantalla vacía.
- El widget más valorado en reviews es el que no requiere abrir la app para decidir "¿salgo ahora?".

---

# Top 15 features candidatas

Rankeadas por impacto para el commuter × factibilidad sin backend propio (solo API de arribos + GPS de trenes).

| # | Feature | Impacto | Factibilidad | Por qué |
|---|---|---|---|---|
| 1 | Widget de lock screen con countdown de la estación de casa | Alto | Alta | Dato único (arribo de una estación). WidgetKit + timeline nativo. Sin servidor propio. |
| 2 | Live Activity con Dynamic Island: tren viniendo | Alto | Alta | Mismo dato que el widget, ActivityKit lo empuja. Apple da el mecanismo entero. |
| 3 | Favorito con contexto casa/trabajo (mañana≠tarde) | Alto | Alta | Lógica local: hora del día + ubicación GPS. Cero backend. |
| 4 | Fallback a horario programado sin señal en vivo | Alto | Alta | Requiere solo el GTFS estático de la línea, empaquetado en la app. |
| 5 | Notificación de demora solo en horario de commute | Alto | Media | Filtrar por línea + franja horaria es local. Requiere polling en background (BGTaskScheduler). |
| 6 | Get Off Alert (aviso al acercarte a tu parada) | Alto | Media | Necesita GPS del usuario + posición del tren. Sin mapa complejo, solo distancia. |
| 7 | Detección automática casa/afuera para el widget | Medio-alto | Media | CoreLocation + geofence simple sobre 2 puntos guardados. |
| 8 | Widget con dos densidades (mínimo vs. completo) | Medio | Alta | Dos familias de WidgetKit sobre el mismo dato. Sin costo de backend. |
| 9 | Compartir "llego a las X" (mensaje/iMessage) | Medio | Alta | Share sheet nativo de iOS con un string armado. Sin servidor. |
| 10 | Modo GO: acompañante activo de viaje con alertas por etapa | Alto | Baja-media | Requiere motion detection + estado de viaje persistente. Más lógica, no más backend. |
| 11 | Historial de puntualidad por línea (visual, no oficial) | Medio | Media | Se construye guardando localmente el delta real vs. programado, con el tiempo. |
| 12 | Accesibilidad completa (VoiceOver, Dynamic Type) | Alto | Alta | Nativo de SwiftUI si se etiqueta bien desde el diseño. Costo bajo, impacto alto en usuarios que dependen de esto. |
| 13 | Widget de Apple Watch / Smart Stack | Medio | Media | WidgetKit corre también en watchOS con el mismo dato. Requiere target adicional. |
| 14 | Selección de vagón recomendado según salida | Bajo (BA) | Baja | Requiere dato de layout de estación que la API de arribos no da. Poco aplicable a BA hoy. |
| 15 | Mapa con trenes moviéndose en vivo sobre la línea completa | Medio | Media-baja | Factible si la API expone posición GPS del tren. Más costo de UI (MapKit + animación) que de datos. |

## Lectura del ranking

- Los primeros 4 puestos son el corazón de Andén. Sin ellos, no compite con nada de esta lista.
- El "modo GO" (puesto 10) es la feature más diferencial de todo el mercado. Pero pide más ingeniería de estado, no más backend: vale la pena para una v2.
- El vagón recomendado (puesto 14) depende de datos que hoy no están disponibles para trenes de Buenos Aires. Se descarta para v1.
- La detección casa/afuera (puesto 7) es la evolución natural del favorito con contexto (puesto 3). Conviene secuenciarlas: primero manual, después automática.
