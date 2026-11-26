/*
   6. PROCEDIMIENTOS ALMACENADOS
*/

-- Tipo de tabla para enviar los renglones del ticket desde C#
CREATE TYPE dbo.TipoDetalleVenta AS TABLE (
    id_producto INT NOT NULL,
    cantidad    INT NOT NULL
);
GO

-- RF-02: procesar venta (Maestro-Detalle) con transacción
CREATE PROCEDURE dbo.sp_ProcesarVenta
    @id_empleado INT,
    @detalle     dbo.TipoDetalleVenta READONLY,
    @id_venta    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- RN-03 / RNF-04: cajero válido y activo
        IF NOT EXISTS (SELECT 1 FROM dbo.Empleados WHERE id_empleado = @id_empleado AND estado = 1)
            THROW 50010, 'El empleado no existe o está inactivo.', 1;

        -- RN-05: al menos un artículo, sin repetidos y con cantidad > 0
        IF NOT EXISTS (SELECT 1 FROM @detalle)
            THROW 50011, 'El ticket debe contener al menos un artículo.', 1;
        IF EXISTS (SELECT 1 FROM @detalle WHERE cantidad <= 0)
            THROW 50012, 'Todas las cantidades deben ser mayores a cero.', 1;
        IF EXISTS (SELECT 1 FROM @detalle GROUP BY id_producto HAVING COUNT(*) > 1)
            THROW 50013, 'Un producto no puede repetirse en el mismo ticket.', 1;

        -- Todos los productos deben existir y estar activos
        IF EXISTS (SELECT 1
                   FROM @detalle d
                   LEFT JOIN dbo.Productos p
                          ON p.id_producto = d.id_producto AND p.estado = 1
                   WHERE p.id_producto IS NULL)
            THROW 50014, 'Uno o más productos no existen o están inactivos.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.Ventas (id_empleado) VALUES (@id_empleado);
        SET @id_venta = SCOPE_IDENTITY();

        -- RN-02: se guarda el precio vigente al momento del cobro
        INSERT INTO dbo.Ventas_Detalle (id_venta, id_producto, cantidad, precio_unitario)
        SELECT @id_venta, d.id_producto, d.cantidad, p.precio
        FROM @detalle d
        JOIN dbo.Productos p ON p.id_producto = d.id_producto
        WHERE p.estado = 1;


        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @id_venta = NULL;
        THROW;   -- re-lanza el error original a la aplicación
    END CATCH
END;
GO

-- RF-05: registrar ajuste de inventario
CREATE PROCEDURE dbo.sp_RegistrarAjuste
    @id_producto INT,
    @id_empleado INT,
    @id_tipo     INT,
    @cantidad    INT,
    @motivo      VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Empleados WHERE id_empleado = @id_empleado AND estado = 1)
            THROW 50020, 'El empleado no existe o está inactivo.', 1;
        IF LTRIM(RTRIM(ISNULL(@motivo, ''))) = ''
            THROW 50021, 'El motivo del ajuste es obligatorio.', 1;

        BEGIN TRANSACTION;
        INSERT INTO dbo.Ajustes_Inventario (id_producto, id_empleado, id_tipo, cantidad, motivo)
        VALUES (@id_producto, @id_empleado, @id_tipo, @cantidad, @motivo);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Proceso 1: validar inicio de sesión (devuelve 1 fila si es válido)
CREATE PROCEDURE dbo.sp_ValidarLogin
    @usuario    VARCHAR(30),
    @contrasena VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_usuario INT;

    SELECT @id_usuario = u.id_usuario
    FROM dbo.Usuarios u
    JOIN dbo.Empleados e ON e.id_empleado = u.id_empleado
    WHERE u.usuario = @usuario
      AND u.contrasena = @contrasena
      AND e.estado = 1;

    IF @id_usuario IS NULL
    BEGIN
        -- Acceso denegado: devuelve conjunto vacío
        SELECT CAST(NULL AS INT) AS id_usuario WHERE 1 = 0;
        RETURN;
    END

    UPDATE dbo.Usuarios SET ultimo_acceso = GETDATE() WHERE id_usuario = @id_usuario;

    SELECT u.id_usuario, e.id_empleado, e.nombre, e.apellido, r.nombre_rol
    FROM dbo.Usuarios u
    JOIN dbo.Empleados e ON e.id_empleado = u.id_empleado
    JOIN dbo.Roles r     ON r.id_rol = e.id_rol
    WHERE u.id_usuario = @id_usuario;
END;
GO