# Arquitectura pública

Esta vista omite detalles operativos sensibles.

```text
Fuentes oficiales
      │
      ▼
Validación de contratos públicos
      │
      ▼
Representación segura para la interfaz
      │
      ▼
Aplicación web de Andén
```

## Principios

- La fuente conserva autoridad sobre el dato.
- La interfaz distingue en vivo, programado y desconocido.
- Los contratos públicos usan campos mínimos.
- Los ejemplos nunca contienen credenciales.
- Las respuestas vacías mantienen incertidumbre explícita.
- La aplicación no funciona como API pública general.

## Límites de esta documentación

No documentamos proxies, rutas internas ni credenciales.

Tampoco documentamos ranking, normalización o caché.

Quedan privados batching, importadores, tareas periódicas y defensas.

Los datasets derivados tampoco se publican.
