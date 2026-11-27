/*
   5. TRIGGERS
*/

-- RF-03: validación previa de existencias
CREATE TRIGGER dbo.trg_VentasDetalle_ValidarStock
ON dbo.Ventas_Detalle
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Productos p ON p.id_producto = i.id_producto
        GROUP BY i.id_producto, p.stock
        HAVING SUM(i.cantidad) > p.stock
    )
    BEGIN
        DECLARE @msg NVARCHAR(400);
        SELECT TOP 1
               @msg = CONCAT(N'Stock insuficiente para "', p.nombre,
                             N'". Disponible: ', p.stock,
                             N', solicitado: ', s.solicitado)
        FROM (SELECT id_producto, SUM(cantidad) AS solicitado
              FROM inserted GROUP BY id_producto) s
        JOIN dbo.Productos p ON p.id_producto = s.id_producto
        WHERE s.solicitado > p.stock;

        THROW 50001, @msg, 1;      -- alerta al cajero; no se inserta nada
    END

    INSERT INTO dbo.Ventas_Detalle (id_venta, id_producto, cantidad, precio_unitario)
    SELECT id_venta, id_producto, cantidad, precio_unitario
    FROM inserted;
END;
GO

-- RF-04: descuenta inventario y actualiza el total de la venta
CREATE TRIGGER dbo.trg_VentasDetalle_ActualizarInventarioTotal
ON dbo.Ventas_Detalle
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
       SET p.stock = p.stock - x.cant
    FROM dbo.Productos p
    JOIN (SELECT id_producto, SUM(cantidad) AS cant
          FROM inserted GROUP BY id_producto) x
      ON x.id_producto = p.id_producto;

    UPDATE v
       SET v.total = v.total + x.importe
    FROM dbo.Ventas v
    JOIN (SELECT id_venta,
                 SUM(dbo.fn_CalcularSubtotal(cantidad, precio_unitario)) AS importe
          FROM inserted GROUP BY id_venta) x
      ON x.id_venta = v.id_venta;
END;
GO

-- RF-05: ajuste de inventario según la afectación del tipo de movimiento
CREATE TRIGGER dbo.trg_Ajustes_ActualizarStock
ON dbo.Ajustes_Inventario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
       SET p.stock = p.stock + x.delta
    FROM dbo.Productos p
    JOIN (SELECT i.id_producto, SUM(i.cantidad * t.afectacion) AS delta
          FROM inserted i
          JOIN dbo.Tipo_Movimiento t ON t.id_tipo = i.id_tipo
          GROUP BY i.id_producto) x
      ON x.id_producto = p.id_producto;
    -- Si el resultado fuera negativo, CK_Productos_stock aborta la operación.
END;
GO

/* 
   5.1 TRIGGERS DE AUDITORÍA
*/

-- 2.1 PRODUCTOS: altas, bajas y cambios de nombre, categoría, precio, stock mínimo, estado, código
CREATE OR ALTER TRIGGER dbo.trg_Productos_Auditoria
ON dbo.Productos
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @emp INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_empleado'));

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN   -- UPDATE
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, valor_nuevo, id_empleado_app)
        SELECT 'Productos', 'UPDATE', i.id_producto, v.campo, v.anterior, v.nuevo, @emp
        FROM inserted i
        JOIN deleted d ON d.id_producto = i.id_producto
        CROSS APPLY (VALUES
            (N'codigo_barras', CONVERT(NVARCHAR(100), d.codigo_barras), CONVERT(NVARCHAR(100), i.codigo_barras)),
            (N'nombre',        CONVERT(NVARCHAR(100), d.nombre),        CONVERT(NVARCHAR(100), i.nombre)),
            (N'id_categoria',  CONVERT(NVARCHAR(100), d.id_categoria),  CONVERT(NVARCHAR(100), i.id_categoria)),
            (N'precio',        CONVERT(NVARCHAR(100), d.precio),        CONVERT(NVARCHAR(100), i.precio)),
            (N'stock_minimo',  CONVERT(NVARCHAR(100), d.stock_minimo),  CONVERT(NVARCHAR(100), i.stock_minimo)),
            (N'estado',        CONVERT(NVARCHAR(100), d.estado),        CONVERT(NVARCHAR(100), i.estado))
        ) v(campo, anterior, nuevo)
        WHERE ISNULL(v.anterior, N'') <> ISNULL(v.nuevo, N'');
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_nuevo, id_empleado_app)
        SELECT 'Productos', 'INSERT', id_producto, 'nombre', nombre, @emp FROM inserted;
    ELSE IF EXISTS (SELECT 1 FROM deleted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, id_empleado_app)
        SELECT 'Productos', 'DELETE', id_producto, 'nombre', nombre, @emp FROM deleted;
END;
GO

-- 2.2 EMPLEADOS: altas, bajas y cambios de datos, rol o estado
CREATE OR ALTER TRIGGER dbo.trg_Empleados_Auditoria
ON dbo.Empleados
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @emp INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_empleado'));

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN   -- UPDATE
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, valor_nuevo, id_empleado_app)
        SELECT 'Empleados', 'UPDATE', i.id_empleado, v.campo, v.anterior, v.nuevo, @emp
        FROM inserted i
        JOIN deleted d ON d.id_empleado = i.id_empleado
        CROSS APPLY (VALUES
            (N'nombre',   CONVERT(NVARCHAR(100), d.nombre),   CONVERT(NVARCHAR(100), i.nombre)),
            (N'apellido', CONVERT(NVARCHAR(100), d.apellido), CONVERT(NVARCHAR(100), i.apellido)),
            (N'telefono', CONVERT(NVARCHAR(100), d.telefono), CONVERT(NVARCHAR(100), i.telefono)),
            (N'id_rol',   CONVERT(NVARCHAR(100), d.id_rol),   CONVERT(NVARCHAR(100), i.id_rol)),
            (N'estado',   CONVERT(NVARCHAR(100), d.estado),   CONVERT(NVARCHAR(100), i.estado))
        ) v(campo, anterior, nuevo)
        WHERE ISNULL(v.anterior, N'') <> ISNULL(v.nuevo, N'');
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_nuevo, id_empleado_app)
        SELECT 'Empleados', 'INSERT', id_empleado, 'nombre', nombre + ' ' + apellido, @emp FROM inserted;
    ELSE IF EXISTS (SELECT 1 FROM deleted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, id_empleado_app)
        SELECT 'Empleados', 'DELETE', id_empleado, 'nombre', nombre + ' ' + apellido, @emp FROM deleted;
END;
GO

-- 2.3 USUARIOS: altas, bajas, cambios de nombre de usuario y de contraseña
CREATE OR ALTER TRIGGER dbo.trg_Usuarios_Auditoria
ON dbo.Usuarios
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @emp INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_empleado'));

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN   -- UPDATE
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, valor_nuevo, id_empleado_app)
        SELECT 'Usuarios', 'UPDATE', i.id_usuario, 'usuario', d.usuario, i.usuario, @emp
        FROM inserted i JOIN deleted d ON d.id_usuario = i.id_usuario
        WHERE d.usuario COLLATE Latin1_General_CS_AS <> i.usuario COLLATE Latin1_General_CS_AS;

        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, valor_nuevo, id_empleado_app)
        SELECT 'Usuarios', 'UPDATE', i.id_usuario, 'contrasena', N'***', N'***', @emp
        FROM inserted i JOIN deleted d ON d.id_usuario = i.id_usuario
        WHERE d.contrasena COLLATE Latin1_General_CS_AS <> i.contrasena COLLATE Latin1_General_CS_AS;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_nuevo, id_empleado_app)
        SELECT 'Usuarios', 'INSERT', id_usuario, 'usuario', usuario, @emp FROM inserted;
    ELSE IF EXISTS (SELECT 1 FROM deleted)
        INSERT INTO dbo.Auditoria (tabla, operacion, id_registro, campo, valor_anterior, id_empleado_app)
        SELECT 'Usuarios', 'DELETE', id_usuario, 'usuario', usuario, @emp FROM deleted;
END;
GO