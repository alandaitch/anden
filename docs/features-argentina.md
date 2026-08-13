# Ecosistema de apps de trenes en Argentina

Investigación para Andén, app iOS de arribos en tiempo real del AMBA.
Fecha: agosto 2026.

## 1. App oficial: Trenes Argentinos (SOFSE)

La app oficial no es una sola app. Es un ecosistema de cuatro apps separadas.
Cada una cubre una función distinta. Ninguna las une.

### 1.1 Trenes en Directo (iOS)

Es la app principal en iPhone. La publica SOFSE, gratis.
Rating: 1.7 a 1.8 de 5 estrellas. Base: 43 a 1.600 calificaciones según la fuente.
Es la app peor calificada de todo el ecosistema.

Features que ofrece:
- Próximos trenes por estación de origen.
- Seguimiento en mapa online del tren en viaje.
- Estado del servicio y alertas de contingencia.
- Guardar viajes y estaciones favoritas, sin registro obligatorio.
- Widget de acceso rápido al viaje frecuente.
- Info de estación: dirección, horario de boletería, conexiones, wifi, rampas.
- Chat con un operador del Contact Center.
- Canal de sugerencias y quejas.

Qué odian las reviews:
- La app se cierra sola al abrir o al loguearse.
- Actualizaciones rompen la app en vez de mejorarla. Usuarios piden volver a la versión anterior.
- El login por Facebook falla y tira la app.
- No hay adaptación al tamaño de pantalla del iPhone.
- Reviews de 2024 repiten la misma queja que reviews de 2019. La app no mejoró en cinco años.
- Cita textual de un usuario: "Es más útil memorizar los horarios que usar esta App."

Qué está roto: la app depende de login. El login falla. Ese único punto de falla tira toda la experiencia.

### 1.2 Trenes Argentinos / Trenes en Vivo (Android)

Package: `com.mininterior.trenesenvivo`. Es la contraparte Android de Trenes en Directo.
Rating: 3.38 de 5 sobre 18.000 calificaciones. Muy por encima de la versión iOS.
40.000 descargas en los últimos 30 días. Última actualización: febrero 2025.

La brecha entre Android (3.38) e iOS (1.8) es el hallazgo más claro de esta investigación.
SOFSE mantiene mejor su app Android. La app iOS quedó abandonada en calidad.

### 1.3 App Trenes Seguros

Package: `ar.gob.sofse.alertaenmoviento`. No es una app de horarios.
Es un botón de pánico para el pasajero.

Cubre cuatro tipos de emergencia: incendio, médica, seguridad, violencia de género.
Envía la ubicación GPS del celular a Centros de Monitoreo de la red ferroviaria.
Requiere registro previo con DNI y teléfono, verificado por llamada.

### 1.4 Reservá tu tren / Confirmá tu viaje

"Reservá tu tren" nació en la pandemia para limitar el aforo por distanciamiento.
Cubrió Roca, Mitre, Sarmiento, San Martín y Belgrano Sur.
Dejó de ser obligatoria en octubre de 2021. Hoy es opcional, casi sin uso.

"Confirmá tu viaje" es otra app. Sirve para larga distancia, no para AMBA.
Confirma el pasaje de tren de media o larga distancia con 24 a 72 horas de anticipación.

### 1.5 Venta de pasajes

No hay venta de pasaje AMBA en ninguna app. El viaje diario se paga con tarjeta SUBE.
La venta de pasajes por app existe solo para servicios de larga distancia y regionales.

## 2. Apps de terceros

### 2.1 TuTren: arribos del tren

Developer: Martín Leopoldo Torrez Peña, independiente. Lanzamiento reciente, id de App Store de 2025.
Cubre Roca, Mitre, Sarmiento, San Martín, Belgrano Sur, Belgrano Norte y Tren de la Costa.

Features:
- Selección de línea, ramal y estación para ver el próximo arribo en minutos.
- Mapa interactivo con la posición de todos los trenes en circulación.
- Estado del servicio: normal, demorado, interrumpido.
- Estaciones cercanas por GPS.

Aclara en su ficha: "Esta aplicación no es oficial. No representa ni está afiliada con Trenes Argentinos, Ferrovías, ni con ninguna entidad gubernamental."
Sin reviews suficientes todavía para mostrar rating. Es un jugador nuevo, sin tracción probada aún.

El mismo developer publicó "Línea Belgrano Norte" como app separada, línea por línea.
Estrategia: una app por línea en vez de una app para todo el sistema.

### 2.2 AlertasTransito

No es una app. Es un blog más un servicio de alertas por WhatsApp, email y Telegram.
Se define como "el blog más popular de tránsito y transporte de Argentina".
Cubre las ocho líneas del AMBA: Roca, Sarmiento, Mitre, San Martín, Belgrano Sur, Belgrano Norte, Urquiza y Tren de la Costa.
Manda estado operacional, obras programadas y demoras. No da arribo en minutos por estación.

### 2.3 Moovit

Cubre trenes de Buenos Aires dentro de su app genérica de transporte público.
Seis líneas, 283 estaciones. Rutas, horarios y alertas de servicio.
No está especializado en tren. Compite en cobertura, no en precisión para el pasajero de tren.

### 2.4 Canales informales

Existen grupos de WhatsApp por línea, por ejemplo "Tren Sarmiento" y "El tren Roca".
Existe un canal de Telegram: "Pasajeros del Tren Sarmiento".
Son comunidades armadas por usuarios, sin curaduría oficial. Circulan rumores junto con datos reales.

## 3. Contexto del servicio

### 3.1 Líneas del AMBA

Siete líneas cubren el AMBA: Roca, Sarmiento, Mitre, San Martín, Belgrano Sur, Belgrano Norte y Tren de la Costa.
Urquiza también opera en el AMBA como octava línea en los listados de alertas.
El sistema completo mueve 1,3 millones de pasajeros por día.

Roca es la línea más usada: unos 8 millones de pasajeros por mes, cuatro ramales más el tramo Temperley-Haedo.
Sarmiento mueve unos 250.000 pasajeros por día hábil. Es el segundo servicio más usado.
Los pasajeros anuales en trenes urbanos bajaron de 330 millones en 2015 a 301 millones en 2025.

### 3.2 Frecuencias típicas

Sarmiento: cada 10 a 20 minutos, cada 14 minutos en hora pico.
Mitre: entre 21 y 39 minutos según ramal. Ramal José León Suárez, cada 16 minutos. Ramal Mitre, cada 30 minutos.
Roca ramal Ezeiza: cada 12 minutos aproximadamente. Varía fuerte por ramal.

### 3.3 Problemas crónicos

Demoras y cancelaciones por fallas técnicas encadenadas. Ejemplo, abril 2026: problema eléctrico varó formaciones entre Constitución y Temperley en la línea Roca.
Causa raíz citada por la prensa: falta de mantenimiento acumulada y escasez de repuestos para unidades viejas.

Obras de infraestructura cortan ramales por meses. El ramal Temperley-Haedo del Roca arrastra demoras largas por obra de puente.
Paros gremiales de La Fraternidad frenan las siete líneas del AMBA a la vez, sin aviso previo suficiente.

Enero 2026 vs enero 2025: la línea Mitre perdió 63,1% de pasajeros por obras en Retiro.
Sarmiento perdió 20,6%, Roca perdió 2,8% en la misma comparación interanual.

Hay anuncio de compra de 43 trenes nuevos para Sarmiento, San Martín, Roca, Mitre y Belgrano, de noviembre 2025.
Renovación de flota en curso, sin fecha de impacto real confirmada en el servicio diario.

### 3.4 Cómo se informa el pasajero hoy

Twitter/X, cuenta @TrenesArg: canal oficial de avisos de demora, paro y cambio de recorrido.
Es reactivo. El aviso llega después de que el pasajero ya está parado en el andén.

Prensa: La Nación, Infobae, Clarín y otros publican notas diarias tipo "cómo funcionan los trenes hoy".
Es información genérica por línea, no por estación ni por horario del pasajero.

WhatsApp y Telegram: grupos y canales armados por usuarios, por línea.
AlertasTransito ofrece alertas por WhatsApp, email y Telegram con curaduría de un tercero.

Ninguno de estos canales responde la pregunta puntual: "¿en cuántos minutos llega mi tren, a mi estación, ahora?"

## 4. El gap técnico detrás del gap de producto

No existe API pública y documentada de Trenes Argentinos para desarrolladores externos.
El acceso a datos requiere OAuth2 más un convenio firmado con el Ministerio de Transporte.

No existe una versión pública de GTFS-RT (tiempo real) de SOFSE.
Sí existe GTFS estático en datos.gob.ar: horarios programados, paradas y recorridos. No posiciones en vivo.

Un desarrollador independiente que investigó esto en detalle (proyecto de sonificación de trenes) documentó tres caminos, los tres cerrados: API oficial con convenio, GTFS-RT inexistente, y scraping de apps oficiales en zona legal ambigua.
Su conclusión: sin acuerdo con el Ministerio, hoy no hay tiempo real confiable y abierto.

Esto explica por qué TuTren y otras apps de terceros existen hace poco y sin tracción aún.
El dato de posición en vivo es escaso y disputado, no solo un problema de diseño de producto.

## 5. Qué pediría un pasajero diario, que hoy nadie le da

- Una sola app, sin login, que abra directo en "próximo tren a mi estación".
- Arribo en minutos por andén, no solo horario de grilla teórica.
- Alerta push cuando SU tren específico se demora o cancela, no un aviso genérico de línea.
- Predicción confiable en hora pico, cuando más se necesita y menos se cumple la grilla.
- Widget de lock screen o Live Activity con la cuenta regresiva del próximo tren.
- Historial de puntualidad real por línea y horario, para elegir cuándo salir de casa.
- Una app que no se caiga. El piso mínimo, hoy incumplido por la app oficial de iOS.
- Info de anden/vía correcto, hoy ausente en toda la oferta relevada.

## Oportunidades

Lista de features diferenciales para ganarle a la app oficial.

1. **Sin login, sin fricción.** Abrí la app y mostrá el próximo tren a la estación guardada. Cero clics.
2. **Live Activity en el lock screen.** Mostrá la cuenta regresiva del tren sin abrir la app.
3. **Alertas por tren específico, no por línea entera.** Avisá solo cuando el tren del pasajero se demora.
4. **Estabilidad como feature de marketing.** Usá "la app que no se cierra sola" contra el 1.8 estrellas de la oficial.
5. **Puntualidad histórica por horario.** Mostrá el % de cumplimiento real de cada franja horaria, por línea.
6. **Modo hora pico.** Priorizá la información que más falla hoy: frecuencia real vs. frecuencia teórica.
7. **Multi-línea con vista unificada.** Combiná las ocho líneas en una sola pantalla, a diferencia de TuTren (una app por línea del mismo dev).
8. **Reporte comunitario verificado.** Dejá que el pasajero reporte demora en el momento, con verificación cruzada entre reportes.
9. **Widget de escritorio y Live Activity combinados.** Ningún competidor releva esto hoy.
10. **Transparencia de fuente de datos.** Si el dato es horario programado y no posición en vivo, decilo. La app oficial no distingue esto y genera desconfianza.
11. **Diseño para una sola mano, en el andén, con apuro.** Los competidores relevados no priorizan este contexto de uso.
12. **Sin dependencia de convenio ministerial para arrancar.** Lanzar sobre GTFS estático más reportes comunitarios, con arquitectura lista para sumar tiempo real oficial si se abre en el futuro.

## Fuentes principales

- [Trenes en Directo — App Store](https://apps.apple.com/ar/app/trenes-en-directo/id1169529009)
- [Trenes Argentinos — Google Play](https://play.google.com/store/apps/details?id=com.mininterior.trenesenvivo)
- [App Trenes Seguros — Google Play](https://play.google.com/store/apps/details?id=ar.gob.sofse.alertaenmoviento)
- [TuTren: arribos del tren — App Store](https://apps.apple.com/es/app/tutren-arribos-del-tren/id6756921040)
- [TuTren — Google Play](https://play.google.com/store/apps/details?id=torrezmartin.tutren)
- [AlertasTransito — Trenes](https://www.alertastransito.com/p/trenes.html)
- [Datos Argentina — dataset trenes GTFS](https://datos.gob.ar/dataset?tags=trenes)
- [Le di un instrumento a cada tren de Buenos Aires (dev.to)](https://dev.to/jtorchia/le-di-un-instrumento-a-cada-tren-de-buenos-aires-lo-que-aprendi-del-proyecto-de-ny-y-por-que-aca-34k7)
- [Trenes en el AMBA: interrupciones, complicaciones y demoras (Infobae)](https://www.infobae.com/sociedad/2026/04/13/trenes-en-el-amba-interrupciones-complicaciones-y-demoras-en-varias-lineas/)
- [Colectivos y trenes del AMBA: pasajeros 2025-2026 (iProfesional)](https://www.iprofesional.com/actualidad/450346-colectivos-y-trenes-amba-cuantos-pasajeros-perdieron-en-2025-y-como-arrancaron-este-ano)
- [43 trenes nuevos para el AMBA (InfoRegión)](https://www.inforegion.com.ar/2025/11/20/el-gobierno-anuncio-la-compra-directa-de-43-trenes-nuevos-para-renovar-la-flota-del-amba/)
