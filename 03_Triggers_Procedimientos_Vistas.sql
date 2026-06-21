CREATE OR REPLACE FUNCTION fn_historial_precios()
RETURNS TRIGGER AS
$$
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO HistorialPrecios(
            id_variante,
            precio_anterior,
            precio_nuevo,
            fecha_cambio
        )
        VALUES(
            OLD.id_variante,
            OLD.precio,
            NEW.precio,
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_historial_precios ON VariantesProducto;

CREATE TRIGGER trg_historial_precios
BEFORE UPDATE ON VariantesProducto
FOR EACH ROW
EXECUTE FUNCTION fn_historial_precios();

CREATE OR REPLACE FUNCTION fn_validar_stock()
RETURNS TRIGGER AS
$$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock
    INTO v_stock
    FROM VariantesProducto
    WHERE id_variante = NEW.id_variante;

    IF v_stock IS NULL THEN
        RAISE EXCEPTION 'La variante del producto no existe';
    END IF;

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para la variante %', NEW.id_variante;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_stock ON DetalleOrden;

CREATE TRIGGER trg_validar_stock
BEFORE INSERT ON DetalleOrden
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock();

CREATE OR REPLACE FUNCTION fn_actualizar_stock()
RETURNS TRIGGER AS
$$
BEGIN
    UPDATE VariantesProducto
    SET stock = stock - NEW.cantidad
    WHERE id_variante = NEW.id_variante;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_actualizar_stock ON DetalleOrden;

CREATE TRIGGER trg_actualizar_stock
AFTER INSERT ON DetalleOrden
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_stock();

CREATE OR REPLACE PROCEDURE ProcesarPago(
    p_id_carrito BIGINT,
    p_id_metodo BIGINT
)
LANGUAGE plpgsql
AS
$$
DECLARE
    v_usuario BIGINT;
    v_orden BIGINT;
    v_total NUMERIC(12,2);
BEGIN
    SELECT id_usuario
    INTO v_usuario
    FROM Carritos
    WHERE id_carrito = p_id_carrito
      AND estado = 'ACTIVO';

    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'El carrito no existe o no está activo';
    END IF;

    SELECT SUM(dc.cantidad * vp.precio)
    INTO v_total
    FROM DetalleCarrito dc
    JOIN VariantesProducto vp
        ON dc.id_variante = vp.id_variante
    WHERE dc.id_carrito = p_id_carrito;

    IF v_total IS NULL OR v_total <= 0 THEN
        RAISE EXCEPTION 'El carrito no contiene productos';
    END IF;

    INSERT INTO Ordenes(
        id_usuario,
        fecha_orden,
        total,
        estado
    )
    VALUES(
        v_usuario,
        CURRENT_TIMESTAMP,
        v_total,
        'PAGADO'
    )
    RETURNING id_orden INTO v_orden;

    INSERT INTO DetalleOrden(
        id_orden,
        id_variante,
        cantidad,
        precio_unitario
    )
    SELECT
        v_orden,
        dc.id_variante,
        dc.cantidad,
        vp.precio
    FROM DetalleCarrito dc
    JOIN VariantesProducto vp
        ON dc.id_variante = vp.id_variante
    WHERE dc.id_carrito = p_id_carrito;

    INSERT INTO Pagos(
        id_orden,
        id_metodo,
        monto,
        fecha_pago
    )
    VALUES(
        v_orden,
        p_id_metodo,
        v_total,
        CURRENT_TIMESTAMP
    );

    INSERT INTO HistorialEstadoPedido(
        id_orden,
        estado,
        fecha
    )
    VALUES(
        v_orden,
        'PAGADO',
        CURRENT_TIMESTAMP
    );

    DELETE FROM DetalleCarrito
    WHERE id_carrito = p_id_carrito;

    UPDATE Carritos
    SET estado = 'CERRADO'
    WHERE id_carrito = p_id_carrito;
END;

CREATE OR REPLACE VIEW vw_productos_top AS
WITH ventas AS (
    SELECT
        c.id_categoria,
        c.nombre AS categoria,
        p.id_producto,
        p.nombre AS producto,
        SUM(d.cantidad) AS total_vendido,
        DENSE_RANK() OVER (
            PARTITION BY c.id_categoria
            ORDER BY SUM(d.cantidad) DESC
        ) AS ranking
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
        c.id_categoria,
        c.nombre,
        p.id_producto,
        p.nombre
)
SELECT
    categoria,
    producto,
    total_vendido
FROM ventas
WHERE ranking = 1;

CREATE OR REPLACE VIEW vw_dashboard_productos AS
SELECT
    p.id_producto,
    p.nombre AS producto,
    p.descripcion,
    c.nombre AS categoria,
    vp.id_variante,
    vp.color,
    vp.talla,
    vp.precio,
    vp.stock
FROM Productos p
JOIN Categorias c
    ON p.id_categoria = c.id_categoria
JOIN VariantesProducto vp
    ON p.id_producto = vp.id_producto;

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

-- Probar vista de productos top
SELECT *
FROM vw_productos_top;

-- Probar dashboard de productos
SELECT *
FROM vw_dashboard_productos
LIMIT 20;

-- Ver triggers existentes
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public';

-- Ver procedimiento ProcesarPago
SELECT
    proname AS procedimiento,
    pg_get_function_arguments(oid) AS parametros
FROM pg_proc
WHERE proname = 'procesarpago';

