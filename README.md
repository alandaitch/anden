<div align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Andén" />
  <h1>Andén</h1>
  <p><b>Tu tren, en vivo.</b> Arribos en tiempo real de los trenes del AMBA (Buenos Aires).</p>
  <p>App iOS nativa · SwiftUI · iOS 17+</p>
</div>

---

Andén responde la única pregunta del pasajero: **cuántos minutos falta tu tren en tu estación**. Demora real, andén, GPS del tren en vivo y alertas de la línea, en un toque.

![Pantallas de Andén](docs/screenshots.png)

## Funciones

- **Cercanas**: ordena las estaciones por tu ubicación y muestra el próximo tren de cada una.
- **Tablero de estación**: countdown grande, andén, demora con color (en horario / leve / fuerte / sin dato), destino y ramal.
- **Favoritos con contexto**: marcá una estación; prioriza "casa" a la mañana y "trabajo" a la tarde.
- **Detalle + mapa en vivo**: recorrido completo y el tren moviéndose por GPS en MapKit.
- **Mapa de red**: todos los trenes de una línea en vivo.
- **Alertas**: por línea y por ramal, ordenadas por criticidad, deduplicadas.
- **Widget + Live Activity + Dynamic Island**: próximo tren en la pantalla de inicio y bloqueada.
- **Notificaciones de demora** (mejor esfuerzo, sin servidor propio).

## Fuente de datos

Andén usa la API pública de **Trenes Argentinos (SOFSE)**: `https://api-servicios.sofse.gob.ar/v1`.

- Arribos en vivo sin token: `GET /arribos/estacion/{id}`.
- Catálogo de **360 estaciones con coordenadas** embebido (`Anden/Resources/estaciones.json`).
- Alertas e infraestructura con un token que se genera con el algoritmo del cliente oficial.

La documentación completa de la API, verificada, está en [`docs/api-reference.md`](docs/api-reference.md).

> **No oficial.** Andén no está afiliada a SOFSE ni a Trenes Argentinos. Belgrano Norte y Urquiza no están en esta API (las operan Ferrovías y Metrovías).

## Arquitectura

SwiftUI + Observation, iOS 17+. Dos targets que comparten `Shared/`:

```
Anden/     app (App, Features, Components, Onboarding, Resources)
Shared/    modelos, cliente API, catálogo, lógica, store, tema, Live Activity  (app + widget)
Widget/    widget de home/lock + Live Activity (Dynamic Island)
docs/      referencia de la API, plan, research
```

## Compilar

Requisitos: macOS con Xcode 17+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/alandaitch/anden.git
cd anden
xcodegen generate
open Anden.xcodeproj
```

En Xcode, elegí tu equipo de firma en **Signing & Capabilities** (cambiá `DEVELOPMENT_TEAM` en `project.yml` por el tuyo) y corré en el simulador o en tu iPhone.

> Con una cuenta de Apple gratuita (Personal Team) la app se instala en tu propio iPhone, pero el perfil dura 7 días y hay que reinstalar. Las notificaciones push en tiempo real no son posibles sin un servidor propio; ver [`docs/ios-tech.md`](docs/ios-tech.md).

## Créditos

Hecho por **Alan Daitch** + **Claude** (Anthropic).

Algoritmo de autenticación de la API documentado por la comunidad en [ariedro/api-trenes](https://github.com/ariedro/api-trenes). Datos de Trenes Argentinos (SOFSE).

## Licencia

MIT — ver [LICENSE](LICENSE).
