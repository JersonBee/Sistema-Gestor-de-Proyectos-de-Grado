# Acceso e inicio privado

La aplicación abre directamente el login: `/` → `/ingresar.jsp`. El formulario ofrece el enlace de registro estudiantil/docente. El registro correcto devuelve al login con el aviso de cuenta activa; iniciar sesión abre `/panel.jsp`. Cerrar sesión regresa al login.

El inicio privado utiliza una composición propia: navegación lateral y cabecera en gris oscuro, indicadores integrados, accesos numerados y distinto peso visual para Proyectos y Banco de ideas. La identidad se define en `assets/css/inicio-identidad.css` y se aplica únicamente al inicio privado; mantiene la paleta institucional y se adapta a móviles. Debajo de los accesos se mantiene el seguimiento general de proyectos y avisos. Las capturas actualizadas son `inicio-identidad.png` e `inicio-identidad-movil.png`.

Todas las cuentas tienen accesos a proyectos, banco de ideas, avisos y perfil. Estudiantes y directores pueden proponer ideas. El Comité tiene acceso a administrar cuentas. Mis tareas aparece como tarjeta para los roles que pueden tener acciones; Secretaría dispone de accesos de consulta. Las tarjetas no sustituyen las comprobaciones de permisos en cada destino.

Se incorporan únicamente módulos ya implementados: la imagen no implica añadir calendario académico, base documental u otros módulos fuera del alcance acordado. Se verificaron redirecciones, formularios de registro y enlaces de tarjetas para los cinco roles en la base local de pruebas. No se requieren migraciones.
