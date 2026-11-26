/*
   4. VISTAS
*/

-- RF-06: productos en nivel crítico
CREATE VIEW dbo.vw_ProductosStockCritico
AS
SELECT p.id_producto,
       p.codigo_barras,
       p.nombre            AS producto,
       c.nombre            AS categoria,
       p.stock,
       p.stock_minimo,
       p.stock_minimo - p.stock AS faltante,          -- campo calculado
       dbo.fn_NivelStock(p.id_producto) AS nivel
FROM dbo.Productos p
JOIN dbo.Categoria c ON c.id_categoria = p.id_categoria
WHERE p.estado = 1
  AND p.stock <= p.stock_minimo;
GO

-- RF-07: corte de caja diario por cajero
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

-- Ventas por categoría 
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