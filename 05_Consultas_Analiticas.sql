/* ============================================================
CONSULTA 1
CLIENTES VIP
Clientes cuyo gasto acumulado es superior al promedio
general y tienen más de 30 días sin comprar.
============================================================ */

SELECT
u.id_usuario,
u.nombre,
u.correo,
COUNT(o.id_orden) AS total_ordenes,
SUM(o.total) AS gasto_acumulado,
MAX(o.fecha_orden) AS ultima_compra,
CURRENT_DATE - MAX(o.fecha_orden)::date AS dias_sin_comprar
FROM Usuarios u
JOIN Ordenes o
ON u.id_usuario = o.id_usuario
GROUP BY
u.id_usuario,
u.nombre,
u.correo
HAVING
SUM(o.total) >
(
SELECT AVG(gasto_cliente)
FROM (
SELECT
id_usuario,
SUM(total) AS gasto_cliente
FROM Ordenes
GROUP BY id_usuario
) promedio
)
AND CURRENT_DATE - MAX(o.fecha_orden)::date > 30
ORDER BY gasto_acumulado DESC;

/* ============================================================
CONSULTA 2
PRODUCTOS MÁS VENDIDOS POR CATEGORÍA
============================================================ */

SELECT
c.nombre AS categoria,
p.nombre AS producto,
SUM(d.cantidad) AS unidades_vendidas,
SUM(d.cantidad * d.precio_unitario) AS ventas_totales
FROM DetalleOrden d
JOIN VariantesProducto vp
ON d.id_variante = vp.id_variante
JOIN Productos p
ON vp.id_producto = p.id_producto
JOIN Categorias c
ON p.id_categoria = c.id_categoria
GROUP BY
c.nombre,
p.nombre
ORDER BY ventas_totales DESC;

/* ============================================================
CONSULTA 3
TOP 10 CLIENTES CON MAYOR GASTO
============================================================ */

SELECT
u.id_usuario,
u.nombre,
COUNT(o.id_orden) AS ordenes_realizadas,
SUM(o.total) AS gasto_total
FROM Usuarios u
JOIN Ordenes o
ON u.id_usuario = o.id_usuario
GROUP BY
u.id_usuario,
u.nombre
ORDER BY gasto_total DESC
LIMIT 10;

/* ============================================================
CONSULTA 4
VENTAS POR CATEGORÍA
============================================================ */

SELECT
c.nombre AS categoria,
COUNT(DISTINCT o.id_orden) AS total_ordenes,
SUM(d.cantidad) AS productos_vendidos,
SUM(d.cantidad * d.precio_unitario) AS ingresos
FROM Categorias c
JOIN Productos p
ON c.id_categoria = p.id_categoria
JOIN VariantesProducto vp
ON p.id_producto = vp.id_producto
JOIN DetalleOrden d
ON vp.id_variante = d.id_variante
JOIN Ordenes o
ON d.id_orden = o.id_orden
GROUP BY c.nombre
ORDER BY ingresos DESC;

/* ============================================================
CONSULTA 5
PRODUCTOS CON MENOR INVENTARIO
============================================================ */

SELECT
p.nombre,
vp.color,
vp.talla,
vp.stock
FROM VariantesProducto vp
JOIN Productos p
ON vp.id_producto = p.id_producto
ORDER BY vp.stock ASC
LIMIT 20;

/* ============================================================
CONSULTA 6
MÉTODOS DE PAGO MÁS UTILIZADOS
============================================================ */

SELECT
mp.nombre AS metodo_pago,
COUNT(*) AS cantidad_pagos,
SUM(pg.monto) AS monto_total
FROM Pagos pg
JOIN MetodosPago mp
ON pg.id_metodo = mp.id_metodo
GROUP BY mp.nombre
ORDER BY cantidad_pagos DESC;

/* ============================================================
CONSULTA 7
ÓRDENES POR MES
============================================================ */

SELECT
DATE_TRUNC('month', fecha_orden) AS mes,
COUNT(*) AS total_ordenes,
SUM(total) AS ventas
FROM Ordenes
GROUP BY DATE_TRUNC('month', fecha_orden)
ORDER BY mes;

/* ============================================================
CONSULTA 8
PRODUCTOS TOP DEL ÚLTIMO MES
============================================================ */

SELECT *
FROM vw_productos_top;

/* ============================================================
CONSULTA 9
EXPLAIN ANALYZE
PRODUCTOS MÁS VENDIDOS
============================================================ */

EXPLAIN ANALYZE
SELECT
c.nombre AS categoria,
p.nombre AS producto,
SUM(d.cantidad) AS total_vendido
FROM DetalleOrden d
JOIN VariantesProducto vp
ON d.id_variante = vp.id_variante
JOIN Productos p
ON vp.id_producto = p.id_producto
JOIN Categorias c
ON p.id_categoria = c.id_categoria
JOIN Ordenes o
ON d.id_orden = o.id_orden
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY
c.nombre,
p.nombre
ORDER BY total_vendido DESC;

/* ============================================================
CONSULTA 10
EXPLAIN ANALYZE
CLIENTES VIP
============================================================ */

EXPLAIN ANALYZE
SELECT
u.id_usuario,
u.nombre,
u.correo,
COUNT(o.id_orden) AS total_ordenes,
SUM(o.total) AS gasto_acumulado,
MAX(o.fecha_orden) AS ultima_compra
FROM Usuarios u
JOIN Ordenes o
ON u.id_usuario = o.id_usuario
GROUP BY
u.id_usuario,
u.nombre,
u.correo
HAVING
SUM(o.total) >
(
SELECT AVG(gasto_cliente)
FROM (
SELECT
id_usuario,
SUM(total) AS gasto_cliente
FROM Ordenes
GROUP BY id_usuario
) promedio
)
AND CURRENT_DATE - MAX(o.fecha_orden)::date > 30
ORDER BY gasto_acumulado DESC;

/* ============================================================
CONSULTA 11
VALIDACIÓN DE REGISTROS
============================================================ */

SELECT 'Usuarios' tabla, COUNT(*) registros FROM Usuarios
UNION ALL
SELECT 'Productos', COUNT(*) FROM Productos
UNION ALL
SELECT 'VariantesProducto', COUNT(*) FROM VariantesProducto
UNION ALL
SELECT 'Carritos', COUNT(*) FROM Carritos
UNION ALL
SELECT 'DetalleCarrito', COUNT(*) FROM DetalleCarrito
UNION ALL
SELECT 'Ordenes', COUNT(*) FROM Ordenes
UNION ALL
SELECT 'DetalleOrden', COUNT(*) FROM DetalleOrden
UNION ALL
SELECT 'Pagos', COUNT(*) FROM Pagos
UNION ALL
SELECT 'HistorialEstadoPedido', COUNT(*) FROM HistorialEstadoPedido
UNION ALL
SELECT 'HistorialPrecios', COUNT(*) FROM HistorialPrecios;
