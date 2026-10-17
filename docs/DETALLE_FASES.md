# Ventanas de detalle de fase

En el detalle del proyecto, cada fase iniciada se puede pulsar para abrir una ventana superpuesta. Las fases futuras se mantienen como texto sin botón. La ventana utiliza `popover` nativo de HTML y CSS, sin JavaScript, servlets, DAOs ni scriptlets propios.

Muestra estado, inicio, último cierre, documentos de la última entrega, versiones y revisiones con responsable, reporte y fechas. Propuesta II e Informe II muestran el conjunto de la fase I correspondiente, con sus revisiones de evaluador/Comité; la fase I muestra las revisiones del director. Pago muestra sus revisiones del Comité. Final presenta los adicionales registrados, licencia y repositorio.

Los enlaces permiten previsualizar documentos en otra pestaña y abrir el seguimiento completo. La ventana es de consulta: no aprueba ni modifica el proyecto. Cierra mediante su botón, Escape o pulsando fuera; el navegador devuelve el foco al botón de apertura al usar Escape. Se requiere un navegador compatible con popovers HTML nativos.

Las consultas están en la capa modelo y se ejecutan después del control de acceso al proyecto. No se requieren migraciones. Se verificaron proyectos activos, cerrados, Final, ausencia de botones en fases no iniciadas y redirección sin sesión. Se comprobó apertura y cierre con Escape en el navegador local.
