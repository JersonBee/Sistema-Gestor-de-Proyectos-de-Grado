# MVC con JSP/JSTL y PostgreSQL

Requisito confirmado por el usuario: estructura Modelo–Vista–Controlador manteniendo la prohibición de servlets, DAOs y scriptlets propios. La implementación usa controladores de página escritos en JSP/JSTL, modelos de acceso a datos con JSTL SQL y las reglas de negocio transaccionales en PostgreSQL. No se adopta un framework Java ni se escriben clases Java de aplicación.

```text
src/main/webapp/
  panel.jsp                         Entrada pública de una sola línea
  acciones/ingresar.jsp              Entrada pública para el POST
  WEB-INF/
    controladores/
      panel.jsp                     Autenticación, modelo y selección de vista
      acciones/ingresar.jsp          Validación, operación y redirección
      comun/                        Sesión, permisos, CSRF y preparación de avisos
    modelo/
      panel/proyectos.jsp           Consulta parametrizada
      acciones/ingresar/ingreso.jsp  Llamada a la función de autenticación
      comun/                        DataSource, token CSRF y validación de sesión
    vistas/
      panel.jsp                     HTML y presentación con JSTL/EL
      comun/                        Cabecera, navegación, avisos y pie
  assets/                           CSS e imágenes
database/                           Esquema, reglas de negocio y migraciones
```

## Responsabilidades

**Modelo.** `database/` conserva entidades, restricciones y funciones de negocio, incluidos permisos de escritura, estados, plazos y transacciones. `WEB-INF/modelo/` contiene exclusivamente las operaciones JSTL SQL con parámetros y el recurso JNDI. El modelo no genera HTML ni redirige al navegador.

**Controlador.** `WEB-INF/controladores/` comprueba método, sesión, rol, CSRF y parámetros; invoca las operaciones necesarias del modelo; interpreta sus resultados; gestiona mensajes de sesión y elige una vista o una redirección. También fija los códigos/cabeceras HTTP. No contiene consultas SQL ni HTML de presentación.

**Vista.** `WEB-INF/vistas/` contiene HTML, formularios y JSTL/EL de presentación: condiciones, bucles, URLs y salida escapada. No consulta la base, invoca controladores/modelos, redirige, modifica la sesión ni fija códigos HTTP. Recibe los resultados preparados por el controlador.

Las entradas públicas mantienen sus rutas anteriores y contienen solamente un include estático de su controlador. Los includes internos son rutas constantes, nunca nombres recibidos por parámetro. El controlador incluye estáticamente su modelo y la vista elegida; comparten el contexto de página JSTL de esa petición. Esta técnica conserva las variables sin añadir clases Java, DAOs, scriptlets ni un servlet propio.

`WEB-INF` impide abrir directamente modelos, vistas y controladores desde el navegador. Las peticiones entran por las rutas públicas y pasan por el control de sesión/permiso antes de ejecutar la consulta o mostrar datos. Las funciones PostgreSQL vuelven a comprobar las reglas al escribir.

## Ejemplo: entrada al panel

1. El navegador solicita `/panel.jsp`.
2. La ruta incluye `WEB-INF/controladores/panel.jsp`.
3. El controlador inicializa el contexto, valida la sesión y solicita proyectos/avisos/resumen al modelo.
4. El modelo usa consultas con parámetros y las funciones de autorización de PostgreSQL.
5. El controlador incluye `WEB-INF/vistas/panel.jsp`, que presenta los resultados escapados.

Los POST siguen el mismo esquema y terminan con redirección, conservando la protección CSRF y la prevención de reenvíos al recargar.

## Comprobaciones

`python scripts/verificar_mvc.py` comprueba que todas las rutas sean entradas simples, que el SQL esté únicamente en el modelo, que las vistas no contengan flujo/estado y que los controladores no contengan HTML. También verifica los destinos de includes. La comprobación PowerShell `scripts/verificar.ps1` revisa las capas y las restricciones de JSP al comprobar el WAR.

La suite funcional se ejecuta con `python scripts/pruebas_final_solicitudes.py` en PostgreSQL local aislado. Incluye comprobaciones de que los modelos, controladores y vistas bajo `WEB-INF` respondan 404 al intentar abrirlos directamente, incluso con sesión válida.

La reorganización conserva las rutas y las operaciones de datos existentes. El respaldo previo de archivos está en `.tools/antes-mvc`, excluido de Git y del contexto Docker. Los módulos de actas, mensajería, administración y filtros también siguen esta estructura; sus operaciones se verifican en `scripts/pruebas_comunicacion.py`. El resumen y la bandeja de tareas siguen las mismas capas y se verifican durante las transiciones en `scripts/pruebas_resumen.py` y `scripts/pruebas_tareas.py`. Actualmente el verificador reconoce 51 rutas públicas.
