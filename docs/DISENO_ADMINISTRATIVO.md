# Presentación administrativa

El tema compartido `src/main/webapp/assets/css/administracion.css` se carga después de los estilos base para unificar portada, acceso, registro y pantallas internas. Mantiene las clases de presentación existentes y la arquitectura MVC.

- Paleta blanca y gris neutro con verde institucional `#C7D309` como acento.
- Navegación lateral con iconos vectoriales consistentes, selección discreta y datos de la sesión separados.
- Barra superior compacta, encabezados de página y títulos de sección con jerarquía uniforme.
- Paneles con bordes finos y radios de cuatro a seis píxeles; filas con separación y acciones alineadas.
- Botones de tamaño consistente, acciones principales destacadas, foco visible y estado deshabilitado.
- Formularios con controles compactos, etiquetas, espaciado y límites visuales coherentes.
- Adaptación móvil con navegación que se distribuye en varias líneas sin requerir JavaScript.

`assets/img/marca-uts.svg` reemplaza la captura del logo en todas las pantallas. Es una recreación vectorial del identificador UTS, el nombre de la institución y el lema a partir de la referencia del usuario; no es un archivo oficial obtenido de la universidad. No utiliza imágenes incrustadas ni depende de la captura para dibujarse. `assets/img/iconos.svg` contiene los símbolos de navegación, también locales y sin scripts.

Los cambios son de presentación y texto de interfaz. No cambian roles, etapas, plazos, enlaces registrados ni decisiones del proceso. No se modificó la base de Supabase. La validación funcional se realizó con la suite integral y la revisión visual incluye escritorio y un ancho móvil de 390 píxeles.
