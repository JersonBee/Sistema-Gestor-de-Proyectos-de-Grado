<sql:query var="tokenFormulario" dataSource="${bd}">SELECT encode(extensions.gen_random_bytes(32), 'hex') AS valor</sql:query>
