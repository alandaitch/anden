# Consultas públicas seguras

Usá siempre el portal documentado por cada organismo.

Respetá licencias, términos y límites publicados.

No automatices páginas sin documentación de acceso.

## Catálogo nacional

CKAN permite consultar metadatos públicos sin credenciales.

```bash
curl --fail --silent --show-error \
  'https://datos.transporte.gob.ar/api/3/action/package_show?id=estaciones-de-trenes-y-servicios-activos-a-2022'
```

Esta consulta obtiene metadatos, no operación ferroviaria actual.

## USIG

Consultá primero la [documentación OpenAPI][usig].

Usá ejemplos públicos con baja frecuencia.

Evitá direcciones personales o historiales de ubicación.

## Transporte BA

El acceso documentado requiere registro y credenciales propias.

Guardá cada token fuera del repositorio.

```bash
export BA_TRANSPORT_TOKEN='reemplazar-localmente'
```

Consultá luego la [documentación oficial][ba-api].

Nunca envíes tokens en Issues, logs o capturas.

## SUBE / OneBusAway

Cuándo SUBO ofrece información al pasajero.

No documenta allí acceso general para terceros.

No extraigas ni compartas credenciales de aplicaciones oficiales.

OneBusAway publica solamente el contrato tecnológico general.

## EcoBici

GBFS define feeds públicos, actuales y de solo lectura.

Validá la versión declarada por cada productor.

La especificación no concede licencia sobre cada feed.

## Mapas

IGN documenta geoservicios OGC y ejemplos Leaflet.

OpenStreetMap publica una política separada para mosaicos.

Conservá ambas atribuciones visibles.

No hagas descargas masivas desde servidores de mosaicos.

[ba-api]: https://api-transporte.buenosaires.gob.ar/
[usig]: https://usig.buenosaires.gob.ar/apis/
