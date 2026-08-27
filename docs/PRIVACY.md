# Política de privacidad — Andén

Última actualización: 27 de agosto de 2026.

Andén es una app no oficial de información de transporte del AMBA (Buenos Aires), hecha por Alan Daitch. Esta política explica qué hace la app con tus datos. En resumen: **Andén no pide cuentas ni guarda perfiles personales.**

## Datos que NO recopilamos

- No pedimos ni creamos cuentas.
- No usamos publicidad ni vendemos datos.
- No tenemos una base de datos con información personal.

## Ubicación

- Andén pide permiso de ubicación **solo** para ordenar las estaciones y paradas más cercanas a vos y centrar el mapa.
- Tu ubicación ordena estaciones y centra el mapa.
- El permiso del navegador es opcional.
- Si lo rechazás, podés escribir una dirección manualmente.
- También podés cambiar después entre GPS y dirección manual.
- La dirección escrita se consulta mediante Georef Argentina.
- Una búsqueda de lugares llega a OpenStreetMap sólo tras una acción explícita.
- Esa búsqueda puede permanecer 24 horas en memoria temporal.
- Las búsquedas de direcciones no tienen caché persistente en Andén.
- La dirección elegida y sus coordenadas quedan en tu dispositivo.
- Para colectivos cercanos, puede enviarse a OneBusAway/SUBE.
- La PWA reduce su precisión antes de enviarla al proxy.
- Una referencia redondeada del área puede permanecer hasta 30 minutos.
- Cómo llegar envía origen y destino al ruteador oficial USIG.
- Una clave derivada del recorrido puede permanecer hasta 15 minutos.
- Andén no mantiene perfiles ni historiales personales de recorridos.
- Podés usar la PWA sin dar el permiso mediante una dirección manual.

## Analítica de la PWA

- La PWA usa Google Analytics 4 para contar visitas y categorías generales de uso.
- Andén envía `page_view` y categorías funcionales fijas.
- GA4 también registra `first_visit`, `session_start` y `user_engagement`.
- Esos eventos técnicos permiten medir visitantes y sesiones.
- No enviamos coordenadas, destinos, recorridos, favoritos ni búsquedas.
- La dirección enviada contiene solamente el dominio principal.
- El conteo está activado inicialmente mediante `analytics_storage: granted`.
- Google Analytics usa cookies para distinguir navegadores y sesiones.
- Google recibe la conexión, incluyendo IP, y puede derivar una ciudad.
- Google puede conservar datos de usuario y eventos hasta 14 meses.
- Los informes agregados pueden persistir después de ese plazo.
- Publicidad, Google Signals y personalización permanecen siempre desactivados.
- La medición mejorada debe permanecer desactivada en la propiedad.
- La recopilación granular debe permanecer desactivada en la propiedad.
- Podés desactivarla desde Ajustes o "Seguridad y privacidad".
- Al desactivarla, borramos sus cookies y bloqueamos futuras mediciones.
- El opt-out no borra datos anteriores ni informes agregados.

## Conexiones de red

Para mostrar arribos en vivo, Andén consulta APIs públicas de transporte:

- Trenes Argentinos (SOFSE): `api-servicios.sofse.gob.ar`
- Transporte de la Ciudad de Buenos Aires: `apitransporte.buenosaires.gob.ar`
- Direcciones: Georef Argentina (`apis.datos.gob.ar`)
- Lugares: OpenStreetMap Nominatim (`nominatim.openstreetmap.org`)
- Colectivos: OneBusAway/SUBE (`cuandosubo.sube.gob.ar`)
- Mapas: teselas de Argenmap u OpenStreetMap.

La PWA usa funciones serverless en Vercel para proteger credenciales.

Los proveedores pueden recibir IP y registros técnicos.

Argenmap u OpenStreetMap reciben el área visible del mapa.

El código de Andén no registra cuerpos con direcciones, ubicaciones o recorridos.

La app Android comparte con el navegador las URLs de Andén que maneja.

Andén no accede al historial general del navegador.

## Almacenamiento en el dispositivo

La app guarda localmente tus **favoritos**, **preferencias** y la **ubicación manual elegida**. Esa información queda en tu dispositivo.

## Chicos

Andén no está dirigida a menores de 13 años.

## Cambios

Si esta política cambia, se actualizará este documento.

## Contacto

Alan Daitch — alandaitch@gmail.com
