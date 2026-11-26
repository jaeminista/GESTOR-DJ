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

-- B.3 Porcentaje de descuento por monto de compra
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

/*
   C. OBTENCIÓN DE ESTADÍSTICAS
   (los rangos de fecha son inclusivos: @desde y @hasta)
*/

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