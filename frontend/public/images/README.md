Carpeta de imágenes públicas
============================

Coloca aquí las imágenes que se mostrarán en el frontend.

Cómo referenciar desde la app
- Usa rutas públicas a partir de `/images`. Ejemplos:
  - `/images/reloj-oro.jpg`
  - `/images/camiseta-negra.png`

Base de datos / seed
- En el campo `image` de cada producto, guarda la ruta pública, por ejemplo:
  - `/images/reloj-oro.jpg`
- Si el campo `image` está vacío o no existe, el frontend mostrará un marcador con la inicial del producto.

Buenas prácticas
- Nombra archivos en minúsculas y sin espacios (usa guiones `-`).
- Optimiza las imágenes (resolución razonable y compresión) para mejorar tiempos de carga.
- Formatos recomendados: `.jpg` para fotos y `.png`/`.webp` para gráficos con transparencia.

