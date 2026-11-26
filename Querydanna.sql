
/* 
   1. CREACIÓN DE LA BASE DE DATOS
*/
USE master;
GO

IF OBJECT_ID(N'master.dbo.sp_RestaurarGestorDJ', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RestaurarGestorDJ;
GO
IF DB_ID(N'GESTOR_DJ') IS NOT NULL
BEGIN
    ALTER DATABASE GESTOR_DJ SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE GESTOR_DJ;
END
GO
CREATE DATABASE GESTOR_DJ;
GO
USE GESTOR_DJ;
GO

/* 
   2. TABLAS
*/

-- ROLES
CREATE TABLE dbo.Roles (
    id_rol      INT IDENTITY(1,1) NOT NULL,
    nombre_rol  VARCHAR(50)       NOT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (id_rol),
    CONSTRAINT UQ_Roles_nombre UNIQUE (nombre_rol)
);
GO

-- EMPLEADOS
CREATE TABLE dbo.Empleados (
    id_empleado INT IDENTITY(1,1) NOT NULL,
    nombre      VARCHAR(50)       NOT NULL,
    apellido    VARCHAR(50)       NOT NULL,
    telefono    VARCHAR(15)       NULL,
    id_rol      INT               NOT NULL,
    estado      BIT               NOT NULL CONSTRAINT DF_Empleados_estado DEFAULT 1,
    CONSTRAINT PK_Empleados PRIMARY KEY (id_empleado),
    CONSTRAINT FK_Empleados_Roles FOREIGN KEY (id_rol) REFERENCES dbo.Roles(id_rol)
);
GO

-- USUARIOS 
CREATE TABLE dbo.Usuarios (
    id_usuario    INT IDENTITY(1,1) NOT NULL,
    id_empleado   INT               NOT NULL,
    usuario       VARCHAR(30)       NOT NULL,
    contrasena    VARCHAR(15)       NOT NULL,
    ultimo_acceso DATETIME          NOT NULL CONSTRAINT DF_Usuarios_acceso DEFAULT GETDATE(),
    CONSTRAINT PK_Usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_Usuarios_empleado UNIQUE (id_empleado),
    CONSTRAINT UQ_Usuarios_usuario  UNIQUE (usuario),
    CONSTRAINT FK_Usuarios_Empleados FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados(id_empleado)
);
GO

-- CATEGORIA
CREATE TABLE dbo.Categoria (
    id_categoria INT IDENTITY(1,1) NOT NULL,
    nombre       VARCHAR(50)       NOT NULL,
    descripcion  VARCHAR(100)      NULL,
    estado       BIT               NOT NULL CONSTRAINT DF_Categoria_estado DEFAULT 1,
    CONSTRAINT PK_Categoria PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_Categoria_nombre UNIQUE (nombre)
);
GO

-- PRODUCTOS
CREATE TABLE dbo.Productos (
    id_producto   INT IDENTITY(1,1) NOT NULL,
    codigo_barras VARCHAR(30)       NULL,
    nombre        VARCHAR(100)      NOT NULL,
    id_categoria  INT               NOT NULL,
    precio        DECIMAL(10,2)     NOT NULL,
    stock         INT               NOT NULL CONSTRAINT DF_Productos_stock DEFAULT 0,
    stock_minimo  INT               NOT NULL CONSTRAINT DF_Productos_stockmin DEFAULT 0,
    estado        BIT               NOT NULL CONSTRAINT DF_Productos_estado DEFAULT 1,
    CONSTRAINT PK_Productos PRIMARY KEY (id_producto),
    CONSTRAINT FK_Productos_Categoria FOREIGN KEY (id_categoria) REFERENCES dbo.Categoria(id_categoria),
    CONSTRAINT CK_Productos_precio    CHECK (precio > 0),
    CONSTRAINT CK_Productos_stock     CHECK (stock >= 0),     
    CONSTRAINT CK_Productos_stockmin  CHECK (stock_minimo >= 0)
);
GO
-- Código de barras único cuando existe 
CREATE UNIQUE NONCLUSTERED INDEX UX_Productos_codigo_barras
    ON dbo.Productos(codigo_barras) WHERE codigo_barras IS NOT NULL;
CREATE NONCLUSTERED INDEX IX_Productos_nombre ON dbo.Productos(nombre);
GO

-- TIPO_MOVIMIENTO
CREATE TABLE dbo.Tipo_Movimiento (
    id_tipo    INT IDENTITY(1,1) NOT NULL,
    nombre     VARCHAR(30)       NOT NULL,
    afectacion SMALLINT          NOT NULL,
    CONSTRAINT PK_Tipo_Movimiento PRIMARY KEY (id_tipo),
    CONSTRAINT UQ_Tipo_Movimiento_nombre UNIQUE (nombre),
    CONSTRAINT CK_Tipo_Movimiento_afect CHECK (afectacion IN (1, -1))
);
GO

-- AJUSTES_INVENTARIO
CREATE TABLE dbo.Ajustes_Inventario (
    id_ajuste   INT IDENTITY(1,1) NOT NULL,
    id_producto INT               NOT NULL,
    id_empleado INT               NOT NULL,
    id_tipo     INT               NOT NULL,
    cantidad    INT               NOT NULL,
    motivo      VARCHAR(100)      NOT NULL,
    fecha       DATETIME          NOT NULL CONSTRAINT DF_Ajustes_fecha DEFAULT GETDATE(),
    CONSTRAINT PK_Ajustes_Inventario PRIMARY KEY (id_ajuste),
    CONSTRAINT FK_Ajustes_Productos FOREIGN KEY (id_producto) REFERENCES dbo.Productos(id_producto),
    CONSTRAINT FK_Ajustes_Empleados FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados(id_empleado),
    CONSTRAINT FK_Ajustes_Tipo      FOREIGN KEY (id_tipo)     REFERENCES dbo.Tipo_Movimiento(id_tipo),
    CONSTRAINT CK_Ajustes_cantidad  CHECK (cantidad > 0)     
);
GO

-- VENTAS (maestro)
CREATE TABLE dbo.Ventas (
    id_venta    INT IDENTITY(1,1) NOT NULL,
    id_empleado INT               NOT NULL,
    fecha       DATETIME          NOT NULL CONSTRAINT DF_Ventas_fecha DEFAULT GETDATE(),
    total       DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Ventas_total DEFAULT 0,
    CONSTRAINT PK_Ventas PRIMARY KEY (id_venta),
    CONSTRAINT FK_Ventas_Empleados FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados(id_empleado),
    CONSTRAINT CK_Ventas_total CHECK (total >= 0)
);
GO
CREATE NONCLUSTERED INDEX IX_Ventas_fecha ON dbo.Ventas(fecha);
GO

-- VENTAS_DETALLE (detalle)
CREATE TABLE dbo.Ventas_Detalle (
    id_detalle      INT IDENTITY(1,1) NOT NULL,
    id_venta        INT               NOT NULL,
    id_producto     INT               NOT NULL,
    cantidad        INT               NOT NULL,
    precio_unitario DECIMAL(10,2)     NOT NULL,
    CONSTRAINT PK_Ventas_Detalle PRIMARY KEY (id_detalle),
    CONSTRAINT FK_VD_Ventas    FOREIGN KEY (id_venta)    REFERENCES dbo.Ventas(id_venta),
    CONSTRAINT FK_VD_Productos FOREIGN KEY (id_producto) REFERENCES dbo.Productos(id_producto),
    CONSTRAINT UQ_VD_venta_producto UNIQUE (id_venta, id_producto),   -- RN-05
    CONSTRAINT CK_VD_cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_VD_precio   CHECK (precio_unitario > 0)
);
GO

/* 
   2.1 TABLA AUDITORIA 
*/
IF OBJECT_ID(N'dbo.Auditoria', N'U') IS NULL
CREATE TABLE dbo.Auditoria (
    id_auditoria   INT IDENTITY(1,1) NOT NULL,
    tabla          VARCHAR(30)       NOT NULL,
    operacion      VARCHAR(10)       NOT NULL,
    id_registro    INT               NOT NULL,
    campo          VARCHAR(30)       NULL,
    valor_anterior NVARCHAR(100)     NULL,
    valor_nuevo    NVARCHAR(100)     NULL,
    usuario_sql    NVARCHAR(128)     NOT NULL CONSTRAINT DF_Auditoria_usuario DEFAULT SUSER_SNAME(),
    id_empleado_app INT              NULL,   
    fecha          DATETIME          NOT NULL CONSTRAINT DF_Auditoria_fecha DEFAULT GETDATE(),
    CONSTRAINT PK_Auditoria PRIMARY KEY (id_auditoria),
    CONSTRAINT CK_Auditoria_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Auditoria_tabla_fecha')
    CREATE NONCLUSTERED INDEX IX_Auditoria_tabla_fecha ON dbo.Auditoria(tabla, fecha);
GO

/* 
   3. FUNCIONES
*/

-- 3.1 Subtotal de un renglón
CREATE FUNCTION dbo.fn_CalcularSubtotal (@cantidad INT, @precio DECIMAL(10,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN CAST(@cantidad AS DECIMAL(12,2)) * @precio;
END;
GO

-- 3.2 Total de una venta 
CREATE FUNCTION dbo.fn_TotalVenta (@id_venta INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);
    SELECT @total = ISNULL(SUM(dbo.fn_CalcularSubtotal(cantidad, precio_unitario)), 0)
    FROM dbo.Ventas_Detalle
    WHERE id_venta = @id_venta;
    RETURN @total;
END;
GO

-- 3.3 Nivel de stock de un producto: 'CRITICO' / 'NORMAL' / 'NO EXISTE'
CREATE FUNCTION dbo.fn_NivelStock (@id_producto INT)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @r VARCHAR(10) = 'NO EXISTE';
    SELECT @r = CASE WHEN stock <= stock_minimo THEN 'CRITICO' ELSE 'NORMAL' END
    FROM dbo.Productos WHERE id_producto = @id_producto;
    RETURN @r;
END;
GO

-- 3.4 Estadísticas de ventas por cajero en un rango de fechas 
CREATE FUNCTION dbo.fn_VentasPorEmpleado (@desde DATE, @hasta DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT e.id_empleado,
           e.nombre + ' ' + e.apellido AS cajero,
           COUNT(v.id_venta)           AS num_tickets,
           ISNULL(SUM(v.total), 0)     AS total_vendido,
           ISNULL(AVG(v.total), 0)     AS ticket_promedio
    FROM dbo.Empleados e
    LEFT JOIN dbo.Ventas v
           ON v.id_empleado = e.id_empleado
          AND CAST(v.fecha AS DATE) BETWEEN @desde AND @hasta
    GROUP BY e.id_empleado, e.nombre, e.apellido
);
GO

/* 
   A. CÁLCULO DE IMPUESTOS (IVA)
*/

-- A.1 Tasa de IVA vigente
CREATE OR ALTER FUNCTION dbo.fn_TasaIVA ()
RETURNS DECIMAL(5,4)
AS
BEGIN
    RETURN 0.1600;     
END;
GO

-- A.2 Monto de IVA sobre una base gravable
CREATE OR ALTER FUNCTION dbo.fn_CalcularIVA (@base DECIMAL(12,2), @tasa DECIMAL(5,4))
RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @base IS NULL OR @tasa IS NULL OR @base <= 0 OR @tasa < 0
        RETURN 0;
    RETURN ROUND(@base * @tasa, 2);
END;
GO

-- A.3 Precio final = precio sin IVA + IVA
CREATE OR ALTER FUNCTION dbo.fn_PrecioConIVA (@precio DECIMAL(12,2), @tasa DECIMAL(5,4))
RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @precio IS NULL OR @precio < 0 RETURN 0;
    RETURN ROUND(@precio * (1 + ISNULL(@tasa, 0)), 2);
END;
GO

-- A.4 Precio SIN IVA a partir de un precio que ya lo incluye
CREATE OR ALTER FUNCTION dbo.fn_ExtraerBaseIVA (@precio_con_iva DECIMAL(12,2), @tasa DECIMAL(5,4))
RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @precio_con_iva IS NULL OR @precio_con_iva < 0 RETURN 0;
    RETURN ROUND(@precio_con_iva / (1 + ISNULL(@tasa, 0)), 2);
END;
GO

/* 
   B. CÁLCULO DE DESCUENTOS
*/

-- B.1 Monto de descuento para un porcentaje (se acota entre 0 y 100)
CREATE OR ALTER FUNCTION dbo.fn_CalcularDescuento (@monto DECIMAL(12,2), @porcentaje DECIMAL(5,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @monto IS NULL OR @porcentaje IS NULL OR @monto <= 0 OR @porcentaje <= 0
        RETURN 0;
    IF @porcentaje > 100 SET @porcentaje = 100;
    RETURN ROUND(@monto * @porcentaje / 100.0, 2);
END;
GO

-- B.2 Porcentaje de descuento por volumen (piezas de un mismo producto)

CREATE OR ALTER FUNCTION dbo.fn_PorcentajeDescuentoVolumen (@cantidad INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    RETURN CASE
              WHEN @cantidad >= 24 THEN 10.00
              WHEN @cantidad >= 12 THEN  5.00
              WHEN @cantidad >=  6 THEN  3.00
              ELSE 0.00
           END;
END;
GO

-- B.3 Porcentaje de descuento por monto de compra (subtotal del ticket)
CREATE OR ALTER FUNCTION dbo.fn_PorcentajeDescuentoTicket (@subtotal DECIMAL(12,2))
RETURNS DECIMAL(5,2)
AS
BEGIN
    RETURN CASE
              WHEN @subtotal >= 1000 THEN 10.00
              WHEN @subtotal >=  500 THEN  5.00
              WHEN @subtotal >=  250 THEN  2.00
              ELSE 0.00
           END;
END;
GO

-- B.4 Total de una venta ya con descuento aplicado (sin IVA)
CREATE OR ALTER FUNCTION dbo.fn_TotalConDescuento (@id_venta INT, @porcentaje DECIMAL(5,2))
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @subtotal DECIMAL(12,2) = dbo.fn_TotalVenta(@id_venta);
    RETURN @subtotal - dbo.fn_CalcularDescuento(@subtotal, @porcentaje);
END;
GO


-- C.1 Resumen general de ventas de un periodo (una sola fila)
CREATE OR ALTER FUNCTION dbo.fn_EstadisticasVentas (@desde DATE, @hasta DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT COUNT(v.id_venta)                           AS num_tickets,
           ISNULL(SUM(v.total), 0)                     AS total_vendido,
           CAST(ISNULL(AVG(v.total), 0) AS DECIMAL(12,2)) AS ticket_promedio,
           ISNULL(MAX(v.total), 0)                     AS ticket_maximo,
           ISNULL(MIN(v.total), 0)                     AS ticket_minimo,
           (SELECT ISNULL(SUM(d.cantidad), 0)
              FROM dbo.Ventas_Detalle d
              JOIN dbo.Ventas v2 ON v2.id_venta = d.id_venta
             WHERE v2.fecha >= @desde
               AND v2.fecha <  DATEADD(DAY, 1, @hasta)) AS piezas_vendidas
    FROM dbo.Ventas v
    WHERE v.fecha >= @desde
      AND v.fecha <  DATEADD(DAY, 1, @hasta)
);
GO

-- C.2 Productos más vendidos del periodo
CREATE OR ALTER FUNCTION dbo.fn_TopProductosVendidos (@desde DATE, @hasta DATE, @top INT)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@top)
           p.id_producto,
           p.nombre                                   AS producto,
           c.nombre                                   AS categoria,
           SUM(d.cantidad)                            AS piezas_vendidas,
           SUM(dbo.fn_CalcularSubtotal(d.cantidad, d.precio_unitario)) AS importe
    FROM dbo.Ventas_Detalle d
    JOIN dbo.Ventas v     ON v.id_venta = d.id_venta
    JOIN dbo.Productos p  ON p.id_producto = d.id_producto
    JOIN dbo.Categoria c  ON c.id_categoria = p.id_categoria
    WHERE v.fecha >= @desde
      AND v.fecha <  DATEADD(DAY, 1, @hasta)
    GROUP BY p.id_producto, p.nombre, c.nombre
    ORDER BY SUM(d.cantidad) DESC, p.nombre
);
GO

-- C.3 Ventas día por día (para gráficas de tendencia)
CREATE OR ALTER FUNCTION dbo.fn_VentasPorDia (@desde DATE, @hasta DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(v.fecha AS DATE)  AS fecha,
           COUNT(v.id_venta)      AS num_tickets,
           SUM(v.total)           AS total_vendido
    FROM dbo.Ventas v
    WHERE v.fecha >= @desde
      AND v.fecha <  DATEADD(DAY, 1, @hasta)
    GROUP BY CAST(v.fecha AS DATE)
);
GO

-- C.4 Ticket promedio del periodo (valor escalar)
CREATE OR ALTER FUNCTION dbo.fn_PromedioTicket (@desde DATE, @hasta DATE)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @prom DECIMAL(12,2);
    SELECT @prom = CAST(AVG(total) AS DECIMAL(12,2))
    FROM dbo.Ventas
    WHERE fecha >= @desde
      AND fecha <  DATEADD(DAY, 1, @hasta);
    RETURN ISNULL(@prom, 0);
END;
GO

/* 
   D. CÁLCULO DE TOTALES
   (fn_CalcularSubtotal y fn_TotalVenta ya existen en el script base)
*/

-- D.1 Desglose completo de un ticket: subtotal, descuento, IVA y total
CREATE OR ALTER FUNCTION dbo.fn_ResumenTicket
    (@id_venta INT, @porc_descuento DECIMAL(5,2), @tasa_iva DECIMAL(5,4))
RETURNS TABLE
AS
RETURN
(
    SELECT s.id_venta,
           s.subtotal,
           d.descuento,
           s.subtotal - d.descuento                  AS base_gravable,
           i.iva,
           s.subtotal - d.descuento + i.iva          AS total_final
    FROM (SELECT @id_venta AS id_venta,
                 dbo.fn_TotalVenta(@id_venta) AS subtotal) s
    CROSS APPLY (SELECT dbo.fn_CalcularDescuento(s.subtotal, @porc_descuento) AS descuento) d
    CROSS APPLY (SELECT dbo.fn_CalcularIVA(s.subtotal - d.descuento, @tasa_iva) AS iva) i
);
GO

-- D.2 Total vendido en un periodo
CREATE OR ALTER FUNCTION dbo.fn_TotalVentasPeriodo (@desde DATE, @hasta DATE)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @t DECIMAL(14,2);
    SELECT @t = SUM(total)
    FROM dbo.Ventas
    WHERE fecha >= @desde
      AND fecha <  DATEADD(DAY, 1, @hasta);
    RETURN ISNULL(@t, 0);
END;
GO

-- D.3 Total cobrado por un cajero en un día (corte de caja)
CREATE OR ALTER FUNCTION dbo.fn_TotalCajeroDia (@id_empleado INT, @fecha DATE)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @t DECIMAL(14,2);
    SELECT @t = SUM(total)
    FROM dbo.Ventas
    WHERE id_empleado = @id_empleado
      AND fecha >= @fecha
      AND fecha <  DATEADD(DAY, 1, @fecha);
    RETURN ISNULL(@t, 0);
END;
GO

-- D.4 Valor total del inventario a precio de venta (solo productos activos)
CREATE OR ALTER FUNCTION dbo.fn_ValorInventario ()
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @t DECIMAL(14,2);
    SELECT @t = SUM(dbo.fn_CalcularSubtotal(stock, precio))
    FROM dbo.Productos
    WHERE estado = 1;
    RETURN ISNULL(@t, 0);
END;
GO

/* 
   4. VISTAS
*/

CREATE VIEW dbo.vw_ProductosStockCritico
AS
SELECT p.id_producto,
       p.codigo_barras,
       p.nombre            AS producto,
       c.nombre            AS categoria,
       p.stock,
       p.stock_minimo,
       p.stock_minimo - p.stock AS faltante,      
       dbo.fn_NivelStock(p.id_producto) AS nivel
FROM dbo.Productos p
JOIN dbo.Categoria c ON c.id_categoria = p.id_categoria
WHERE p.estado = 1
  AND p.stock <= p.stock_minimo;
GO


CREATE VIEW dbo.vw_CorteCajaDiario
AS
SELECT CAST(v.fecha AS DATE)         AS fecha,
       e.id_empleado,
       e.nombre + ' ' + e.apellido   AS cajero,
       COUNT(v.id_venta)             AS num_tickets,
       SUM(v.total)                  AS total_cobrado,
       AVG(v.total)                  AS ticket_promedio
FROM dbo.Ventas v
JOIN dbo.Empleados e ON e.id_empleado = v.id_empleado
GROUP BY CAST(v.fecha AS DATE), e.id_empleado, e.nombre, e.apellido;
GO

-- Detalle de tickets (maestro-detalle con subtotal calculado)
CREATE VIEW dbo.vw_DetalleVentas
AS
SELECT v.id_venta                    AS folio,
       v.fecha,
       e.nombre + ' ' + e.apellido   AS cajero,
       p.codigo_barras,
       p.nombre                      AS producto,
       c.nombre                      AS categoria,
       d.cantidad,
       d.precio_unitario,
       dbo.fn_CalcularSubtotal(d.cantidad, d.precio_unitario) AS subtotal,
       v.total                       AS total_ticket
FROM dbo.Ventas v
JOIN dbo.Ventas_Detalle d ON d.id_venta = v.id_venta
JOIN dbo.Productos p      ON p.id_producto = d.id_producto
JOIN dbo.Categoria c      ON c.id_categoria = p.id_categoria
JOIN dbo.Empleados e      ON e.id_empleado = v.id_empleado;
GO

-- Historial de ajustes de inventario
CREATE VIEW dbo.vw_HistorialAjustes
AS
SELECT a.fecha,
       p.nombre                      AS producto,
       t.nombre                      AS tipo_movimiento,
       t.afectacion,
       a.cantidad,
       a.cantidad * t.afectacion     AS efecto_stock,
       a.motivo,
       e.nombre + ' ' + e.apellido   AS empleado
FROM dbo.Ajustes_Inventario a
JOIN dbo.Productos p        ON p.id_producto = a.id_producto
JOIN dbo.Tipo_Movimiento t  ON t.id_tipo = a.id_tipo
JOIN dbo.Empleados e        ON e.id_empleado = a.id_empleado;
GO

-- Ventas por categoría (reportes estadísticos, filtrable por fecha/categoría)
CREATE VIEW dbo.vw_VentasPorCategoria
AS
SELECT CAST(v.fecha AS DATE)  AS fecha,
       c.id_categoria,
       c.nombre               AS categoria,
       SUM(d.cantidad)        AS piezas_vendidas,
       SUM(dbo.fn_CalcularSubtotal(d.cantidad, d.precio_unitario)) AS importe
FROM dbo.Ventas v
JOIN dbo.Ventas_Detalle d ON d.id_venta = v.id_venta
JOIN dbo.Productos p      ON p.id_producto = d.id_producto
JOIN dbo.Categoria c      ON c.id_categoria = p.id_categoria
GROUP BY CAST(v.fecha AS DATE), c.id_categoria, c.nombre;
GO

/*
   4.1 VISTA DE CONSULTA DE LA BITÁCORA
*/
CREATE OR ALTER VIEW dbo.vw_Auditoria
AS
SELECT a.id_auditoria,
       a.fecha,
       a.tabla,
       a.operacion,
       a.id_registro,
       a.campo,
       a.valor_anterior,
       a.valor_nuevo,
       a.usuario_sql,
       e.nombre + ' ' + e.apellido AS empleado_app
FROM dbo.Auditoria a
LEFT JOIN dbo.Empleados e ON e.id_empleado = a.id_empleado_app;
GO

/* 
   5. TRIGGERS
*/


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

        THROW 50001, @msg, 1;   
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
END;
GO


-- 2.1 PRODUCTOS: altas, bajas y cambios de nombre, categoría, precio, stock mínimo, estado, código
CREATE OR ALTER TRIGGER dbo.trg_Productos_Auditoria
ON dbo.Productos
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @emp INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_empleado'));

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN 
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
    BEGIN   
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
    BEGIN   
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

/* 
   6. PROCEDIMIENTOS ALMACENADOS
*/

CREATE TYPE dbo.TipoDetalleVenta AS TABLE (
    id_producto INT NOT NULL,
    cantidad    INT NOT NULL
);
GO

CREATE PROCEDURE dbo.sp_ProcesarVenta
    @id_empleado INT,
    @detalle     dbo.TipoDetalleVenta READONLY,
    @id_venta    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Empleados WHERE id_empleado = @id_empleado AND estado = 1)
            THROW 50010, 'El empleado no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM @detalle)
            THROW 50011, 'El ticket debe contener al menos un artículo.', 1;
        IF EXISTS (SELECT 1 FROM @detalle WHERE cantidad <= 0)
            THROW 50012, 'Todas las cantidades deben ser mayores a cero.', 1;
        IF EXISTS (SELECT 1 FROM @detalle GROUP BY id_producto HAVING COUNT(*) > 1)
            THROW 50013, 'Un producto no puede repetirse en el mismo ticket.', 1;

        IF EXISTS (SELECT 1
                   FROM @detalle d
                   LEFT JOIN dbo.Productos p
                          ON p.id_producto = d.id_producto AND p.estado = 1
                   WHERE p.id_producto IS NULL)
            THROW 50014, 'Uno o más productos no existen o están inactivos.', 1;

        BEGIN TRANSACTION;

        INSERT INTO dbo.Ventas (id_empleado) VALUES (@id_empleado);
        SET @id_venta = SCOPE_IDENTITY();

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
        THROW;  
    END CATCH
END;
GO

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

/* 
   7. RESPALDO Y RESTAURACIÓN (invocables desde la aplicación)
*/

CREATE PROCEDURE dbo.sp_RespaldarGestorDJ
    @ruta NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BACKUP DATABASE GESTOR_DJ
        TO DISK = @ruta
        WITH INIT, FORMAT, CHECKSUM, STATS = 10,
             NAME = N'GESTOR_DJ - Respaldo completo';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

USE master;
GO
CREATE PROCEDURE dbo.sp_RestaurarGestorDJ
    @ruta NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        ALTER DATABASE GESTOR_DJ SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        RESTORE DATABASE GESTOR_DJ
        FROM DISK = @ruta
        WITH REPLACE, RECOVERY, STATS = 10;
        ALTER DATABASE GESTOR_DJ SET MULTI_USER;
    END TRY
    BEGIN CATCH
        IF DB_ID('GESTOR_DJ') IS NOT NULL
            ALTER DATABASE GESTOR_DJ SET MULTI_USER;
        THROW;
    END CATCH
END;
GO

USE GESTOR_DJ;
GO

/*
   8. DATOS DE EJEMPLO
*/
INSERT INTO dbo.Roles (nombre_rol) VALUES ('Administrador'), ('Cajero');

INSERT INTO dbo.Empleados (nombre, apellido, telefono, id_rol, estado) VALUES
 ('Juana',  'Pérez',     '6871234567', 1, 1),
 ('Gerson', 'Camacho',   '6877654321', 2, 1),
 ('Danna',  'Rosales',   NULL,         2, 1);

INSERT INTO dbo.Usuarios (id_empleado, usuario, contrasena) VALUES
 (1, 'admin',  'admin123'),
 (2, 'gerson', 'caja123'),
 (3, 'danna',  'caja456');

INSERT INTO dbo.Categoria (nombre, descripcion) VALUES
 ('Abarrotes', 'Productos básicos de despensa'),
 ('Bebidas',   'Refrescos, jugos y agua'),
 ('Lácteos',   'Leche, queso y derivados'),
 ('Botanas',   'Frituras y dulces'),
 ('Limpieza',  'Artículos de limpieza del hogar');

INSERT INTO dbo.Tipo_Movimiento (nombre, afectacion) VALUES
 ('Entrada',             1),
 ('Corrección positiva', 1),
 ('Merma',              -1),
 ('Corrección negativa',-1),
 ('Salida',             -1);

INSERT INTO dbo.Productos (codigo_barras, nombre, id_categoria, precio, stock, stock_minimo) VALUES
 ('7501000100011', 'Arroz 1 kg',            1, 28.50, 40, 10),
 ('7501000100028', 'Frijol negro 1 kg',     1, 36.00, 35, 10),
 ('7501000200010', 'Refresco cola 600 ml',  2, 18.00, 60, 20),
 ('7501000200027', 'Agua natural 1 L',      2, 12.00, 50, 20),
 ('7501000300019', 'Leche entera 1 L',      3, 27.50, 25, 10),
 ('7501000400016', 'Papas fritas 45 g',     4, 17.00, 8,  10),
 ('7501000500013', 'Cloro 950 ml',          5, 22.00, 15, 5);

-- Prueba rápida de una venta con el procedimiento (opcional)
DECLARE @det dbo.TipoDetalleVenta, @folio INT;
INSERT INTO @det (id_producto, cantidad) VALUES (1, 2), (3, 3), (5, 1);
EXEC dbo.sp_ProcesarVenta @id_empleado = 2, @detalle = @det, @id_venta = @folio OUTPUT;
SELECT @folio AS folio_generado;

EXEC dbo.sp_RegistrarAjuste @id_producto = 6, @id_empleado = 1, @id_tipo = 1,
                            @cantidad = 20, @motivo = 'Reabastecimiento proveedor';

-- Consultas de verificación
SELECT * FROM dbo.vw_DetalleVentas;
SELECT * FROM dbo.vw_CorteCajaDiario;
SELECT * FROM dbo.vw_ProductosStockCritico;
SELECT * FROM dbo.vw_HistorialAjustes;
SELECT * FROM dbo.fn_VentasPorEmpleado(CAST(GETDATE() AS DATE), CAST(GETDATE() AS DATE));
GO

/* =====================================================================
   PRUEBAS (evidencias para el documento técnico)
   Suponen que existe la venta con folio 1 creada por el script base.
   ===================================================================== */
-- A. Impuestos
SELECT dbo.fn_TasaIVA()                                   AS tasa_iva,
       dbo.fn_CalcularIVA(100, dbo.fn_TasaIVA())          AS iva_sobre_100,
       dbo.fn_PrecioConIVA(100, dbo.fn_TasaIVA())         AS precio_con_iva,
       dbo.fn_ExtraerBaseIVA(116, dbo.fn_TasaIVA())       AS base_de_116;

-- B. Descuentos
SELECT dbo.fn_CalcularDescuento(500, 10)                  AS descuento_10_de_500,
       dbo.fn_PorcentajeDescuentoVolumen(12)              AS pct_por_12_piezas,
       dbo.fn_PorcentajeDescuentoTicket(600)              AS pct_ticket_600,
       dbo.fn_TotalConDescuento(1, 5)                     AS ticket1_con_5pct;

-- C. Estadísticas
DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
SELECT * FROM dbo.fn_EstadisticasVentas(@hoy, @hoy);
SELECT * FROM dbo.fn_TopProductosVendidos(@hoy, @hoy, 5);
SELECT * FROM dbo.fn_VentasPorDia(DATEADD(DAY, -7, @hoy), @hoy);
SELECT dbo.fn_PromedioTicket(DATEADD(DAY, -7, @hoy), @hoy) AS ticket_promedio_semana;

-- D. Totales
SELECT * FROM dbo.fn_ResumenTicket(1, 5, dbo.fn_TasaIVA());
SELECT dbo.fn_TotalVentasPeriodo(@hoy, @hoy)   AS total_hoy,
       dbo.fn_TotalCajeroDia(2, @hoy)          AS total_cajero2_hoy,
       dbo.fn_ValorInventario()                AS valor_inventario;
GO

-- Los INSERT de datos de ejemplo disparan los triggers de auditoría;
-- se limpia la bitácora para que las pruebas de auditoría empiecen vacías.
TRUNCATE TABLE dbo.Auditoria;
GO

/* ---------------------------------------------------------------------
   PRUEBAS DE AUDITORÍA (evidencias para el documento técnico)
   --------------------------------------------------------------------- */
-- Simula que el empleado 1 (administrador) está logueado en la app
EXEC sp_set_session_context @key = N'id_empleado', @value = 1;

UPDATE dbo.Productos SET precio = 30.00 WHERE id_producto = 1;           -- cambio de precio
UPDATE dbo.Productos SET stock_minimo = 12, estado = 1 WHERE id_producto = 2;
UPDATE dbo.Empleados SET telefono = '6879999999' WHERE id_empleado = 3;   -- cambio de teléfono
UPDATE dbo.Usuarios  SET contrasena = 'nueva123' WHERE id_usuario = 3;    -- cambio de contraseña

SELECT * FROM dbo.vw_Auditoria ORDER BY id_auditoria DESC;

-- Restaurar el precio original del producto 1 (también queda registrado)
UPDATE dbo.Productos SET precio = 28.50 WHERE id_producto = 1;
GO

/* NOTA PARA LA APLICACIÓN (C#):
   Para que la bitácora sepa qué empleado hizo el cambio, después del login
   ejecuta en la misma conexión abierta:
       EXEC sp_set_session_context @key = N'id_empleado', @value = <id_empleado>;
   Si no se ejecuta, id_empleado_app queda en NULL y solo se registra usuario_sql. */