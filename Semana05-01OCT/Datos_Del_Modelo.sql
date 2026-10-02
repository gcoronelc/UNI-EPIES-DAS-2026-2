/* =====================================================================
   SCRIPT DE CARGA DE DATOS DE PRUEBA - ULTIMOS 18 MESES
   Motor      : SQL Server 2016 o superior (usa DROP TABLE IF EXISTS)
   Modelo     : CLIENTE, EMPLEADO, CATEGORIA, PRODUCTO, TIPO_PAGO,
                VENTA, DETALLE_VENTA, PAGO

   OBSERVACION IMPORTANTE
   La tabla VENTA del modelo original NO tiene columna de fecha, por lo
   que el criterio "ultimos 18 meses" no se puede representar. El Paso 0
   agrega la columna FECHA (datetime NOT NULL, DEFAULT GETDATE()) solo si
   aun no existe.

   Reglas de negocio simuladas
   - IGV 18 %: IMPUESTO = ROUND(SUBTOTAL * 0.18, 2); TOTAL = SUBTOTAL + IMPUESTO
   - SUBTOTAL de VENTA = suma de SUBTOTAL de sus DETALLE_VENTA
   - Cada venta tiene entre 1 y 5 productos distintos (cantidad de 1 a 4)
   - La suma de PAGO.IMPORTE de cada venta es igual a VENTA.TOTAL
     (aprox. 1 de cada 7 ventas se paga en dos medios de pago)
   - Fechas distribuidas aleatoriamente entre hoy - 18 meses y hoy,
     en horario de 08:00 a 21:59

   Es re-ejecutable: los catalogos no se duplican; cada ejecucion agrega
   @CantidadVentas ventas nuevas.
   ===================================================================== */

-- USE NombreDeTuBaseDeDatos;
-- GO

SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   PASO 0: Columna FECHA en VENTA (solo si no existe)
   --------------------------------------------------------------------- */
IF COL_LENGTH('dbo.VENTA', 'FECHA') IS NULL
BEGIN
    ALTER TABLE dbo.VENTA
        ADD FECHA datetime NOT NULL
        CONSTRAINT DF_VENTA_FECHA DEFAULT (GETDATE());
    PRINT 'Columna VENTA.FECHA agregada.';
END
GO

/* ---------------------------------------------------------------------
   PASO 1 en adelante: carga transaccional
   --------------------------------------------------------------------- */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CantidadVentas int          = 3000;    -- parametro: volumen de ventas a generar
DECLARE @TasaIGV        numeric(5,4) = 0.18;    -- parametro: tasa de impuesto

DECLARE @Hoy    date = CAST(GETDATE() AS date);
DECLARE @Desde  date = DATEADD(MONTH, -18, @Hoy);
DECLARE @Dias   int  = DATEDIFF(DAY, @Desde, @Hoy) + 1;
DECLARE @IdVentaBase int = ISNULL((SELECT MAX(IDVENTA) FROM dbo.VENTA), 0);
DECLARE @nCli int, @nEmp int;

BEGIN TRY
    BEGIN TRAN;

    /* ---------- TIPO_PAGO ---------- */
    INSERT INTO dbo.TIPO_PAGO (IDTIPO, NOMBRE_CORTO, NOMBRE)
    SELECT v.id, v.corto, v.nombre
    FROM (VALUES
        (1, 'EFE', 'Efectivo'),
        (2, 'TCR', 'Tarjeta de credito'),
        (3, 'TDB', 'Tarjeta de debito'),
        (4, 'YAP', 'Billetera digital'),
        (5, 'TRF', 'Transferencia bancaria')
    ) AS v(id, corto, nombre)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TIPO_PAGO t WHERE t.IDTIPO = v.id);

    /* ---------- CATEGORIA ---------- */
    INSERT INTO dbo.CATEGORIA (IDCATEGORIA, NOMBRE)
    SELECT v.id, v.nombre
    FROM (VALUES
        (1, 'Abarrotes'),
        (2, 'Bebidas'),
        (3, 'Lacteos'),
        (4, 'Limpieza'),
        (5, 'Cuidado Personal'),
        (6, 'Snacks y Golosinas')
    ) AS v(id, nombre)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CATEGORIA c WHERE c.IDCATEGORIA = v.id);

    /* ---------- EMPLEADO (claves en texto plano: SOLO para pruebas) ---------- */
    INSERT INTO dbo.EMPLEADO (NOMBRE, USUARIO, CLAVE)
    SELECT v.nombre, v.usuario, v.clave
    FROM (VALUES
        ('Rosa Maria Flores Quispe',   'rflores',   'Clave#001'),
        ('Luis Alberto Ramos Huaman',  'lramos',    'Clave#002'),
        ('Carmen Julia Vega Torres',   'cvega',     'Clave#003'),
        ('Jorge Luis Salazar Rojas',   'jsalazar',  'Clave#004'),
        ('Patricia Elena Mendoza Paz', 'pmendoza',  'Clave#005'),
        ('Miguel Angel Castro Leon',   'mcastro',   'Clave#006'),
        ('Ana Lucia Paredes Chavez',   'aparedes',  'Clave#007'),
        ('Victor Hugo Cardenas Diaz',  'vcardenas', 'Clave#008')
    ) AS v(nombre, usuario, clave)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.EMPLEADO e WHERE e.USUARIO = v.usuario);

    /* ---------- PRODUCTO ---------- */
    INSERT INTO dbo.PRODUCTO (IDCATEGORIA, NOMBRE, PRECIO, STOCK)
    SELECT v.idcat, v.nombre, v.precio, 50 + ABS(CHECKSUM(NEWID()) % 451)
    FROM (VALUES
        -- 1 Abarrotes
        (1, 'Arroz Superior 1 kg',          4.50),
        (1, 'Azucar Rubia 1 kg',            4.20),
        (1, 'Aceite Vegetal 1 L',           9.80),
        (1, 'Fideo Spaghetti 500 g',        3.50),
        (1, 'Atun en Aceite 170 g',         6.50),
        (1, 'Lentejas 500 g',               5.20),
        -- 2 Bebidas
        (2, 'Agua Mineral 625 ml',          1.80),
        (2, 'Gaseosa Cola 1.5 L',           6.50),
        (2, 'Jugo de Naranja 1 L',          5.90),
        (2, 'Cerveza Lager 650 ml',         7.50),
        (2, 'Bebida Energizante 473 ml',    4.50),
        (2, 'Te Helado 500 ml',             3.20),
        -- 3 Lacteos
        (3, 'Leche Entera 1 L',             5.40),
        (3, 'Yogurt Natural 1 L',           8.20),
        (3, 'Queso Fresco 250 g',           9.50),
        (3, 'Mantequilla 200 g',            7.90),
        (3, 'Leche Evaporada 400 g',        4.30),
        -- 4 Limpieza
        (4, 'Detergente en Polvo 1 kg',    12.50),
        (4, 'Lejia 1 L',                    4.80),
        (4, 'Lavavajilla 500 ml',           6.90),
        (4, 'Papel Higienico x4',           7.80),
        (4, 'Desinfectante 900 ml',         8.60),
        -- 5 Cuidado Personal
        (5, 'Shampoo 400 ml',              14.90),
        (5, 'Jabon de Tocador x3',          7.20),
        (5, 'Pasta Dental 100 ml',          6.30),
        (5, 'Desodorante 150 ml',          11.90),
        (5, 'Toallas Higienicas x10',       5.90),
        -- 6 Snacks y Golosinas
        (6, 'Galletas de Soda x6',          3.60),
        (6, 'Chocolate en Barra 100 g',     5.50),
        (6, 'Papas Fritas 150 g',           6.40),
        (6, 'Chicle x12',                   2.50),
        (6, 'Mani Salado 200 g',            7.10)
    ) AS v(idcat, nombre, precio)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.PRODUCTO p WHERE p.NOMBRE = v.nombre);

    /* ---------- CLIENTE (250 nombres unicos combinando listas) ---------- */
    INSERT INTO dbo.CLIENTE (NOMBRE)
    SELECT TOP (250) x.completo
    FROM (
        SELECT n.nom + ' ' + a.ape + ' ' + b.ape AS completo
        FROM (VALUES ('Carlos'),('Maria'),('Jose'),('Lucia'),('Pedro'),('Rosa'),('Juan'),
                     ('Elena'),('Diego'),('Sofia'),('Andres'),('Camila'),('Fernando'),
                     ('Valeria'),('Ricardo'),('Daniela'),('Hector'),('Gabriela'),
                     ('Oscar'),('Natalia')) AS n(nom)
        CROSS JOIN (VALUES ('Quispe'),('Flores'),('Huaman'),('Garcia'),('Rodriguez'),
                           ('Mamani'),('Sanchez'),('Torres'),('Ramirez'),('Vargas'),
                           ('Rojas'),('Castillo'),('Mendoza'),('Chavez'),('Diaz'),
                           ('Gutierrez'),('Salazar'),('Ortiz'),('Silva'),('Paredes')) AS a(ape)
        CROSS JOIN (VALUES ('Quispe'),('Flores'),('Huaman'),('Garcia'),('Rodriguez'),
                           ('Mamani'),('Sanchez'),('Torres'),('Ramirez'),('Vargas'),
                           ('Rojas'),('Castillo'),('Mendoza'),('Chavez'),('Diaz'),
                           ('Gutierrez'),('Salazar'),('Ortiz'),('Silva'),('Paredes')) AS b(ape)
        WHERE a.ape <> b.ape
    ) AS x
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CLIENTE c WHERE c.NOMBRE = x.completo)
    ORDER BY NEWID();

    /* ---------- Listas de trabajo (numeradas para sorteo) ---------- */
    DROP TABLE IF EXISTS #Cli, #Emp, #Prod, #Num, #R, #VentaGen, #V, #PagoPlan;

    SELECT ROW_NUMBER() OVER (ORDER BY IDCLIENTE)  AS rn, IDCLIENTE  AS id INTO #Cli  FROM dbo.CLIENTE;
    SELECT ROW_NUMBER() OVER (ORDER BY IDEMPLEADO) AS rn, IDEMPLEADO AS id INTO #Emp  FROM dbo.EMPLEADO;
    SELECT IDPRODUCTO AS id, PRECIO AS precio INTO #Prod FROM dbo.PRODUCTO;

    SELECT @nCli = COUNT(*) FROM #Cli;
    SELECT @nEmp = COUNT(*) FROM #Emp;

    /* ---------- Generador de numeros 1..@CantidadVentas ---------- */
    SELECT TOP (@CantidadVentas)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    INTO #Num
    FROM sys.all_columns a CROSS JOIN sys.all_columns b;

    /* ---------- Sorteo de cliente, empleado, dia y hora ---------- */
    SELECT n,
           ABS(CHECKSUM(NEWID()) % @nCli) + 1      AS rc,
           ABS(CHECKSUM(NEWID()) % @nEmp) + 1      AS re,
           ABS(CHECKSUM(NEWID()) % @Dias)          AS dd,
           ABS(CHECKSUM(NEWID()) % (14 * 3600))    AS ss   -- 14 h de atencion
    INTO #R
    FROM #Num;

    SELECT c.id AS IDCLIENTE,
           e.id AS IDEMPLEADO,
           CASE WHEN f.FECHA > GETDATE() THEN DATEADD(DAY, -1, f.FECHA) ELSE f.FECHA END AS FECHA
    INTO #VentaGen
    FROM #R r
    JOIN #Cli c ON c.rn = r.rc
    JOIN #Emp e ON e.rn = r.re
    CROSS APPLY (SELECT DATEADD(SECOND, 8 * 3600 + r.ss,
                                CAST(DATEADD(DAY, r.dd, @Desde) AS datetime)) AS FECHA) f;

    /* ---------- VENTA (cabecera con totales en cero; se recalculan luego) ---------- */
    INSERT INTO dbo.VENTA (IDCLIENTE, IDEMPLEADO, SUBTOTAL, IMPUESTO, TOTAL, FECHA)
    SELECT IDCLIENTE, IDEMPLEADO, 0, 0, 0, FECHA
    FROM #VentaGen
    ORDER BY FECHA;

    /* ---------- Cantidad de lineas por venta (materializada) ---------- */
    SELECT IDVENTA, 1 + ABS(CHECKSUM(NEWID()) % 5) AS nl
    INTO #V
    FROM dbo.VENTA
    WHERE IDVENTA > @IdVentaBase;

    /* ---------- DETALLE_VENTA: productos distintos por venta ---------- */
    ;WITH Cand AS (
        SELECT v.IDVENTA, v.nl, p.id AS IDPRODUCTO, p.precio,
               ROW_NUMBER() OVER (PARTITION BY v.IDVENTA ORDER BY NEWID()) AS rn,
               1 + ABS(CHECKSUM(NEWID()) % 4) AS cant
        FROM #V v
        CROSS JOIN #Prod p
    )
    INSERT INTO dbo.DETALLE_VENTA (IDVENTA, IDPRODUCTO, PRECIO_VENTA, CANTIDAD, SUBTOTAL)
    SELECT IDVENTA, IDPRODUCTO, precio,
           CAST(cant AS numeric(10,2)),
           CAST(ROUND(precio * cant, 2) AS numeric(10,2))
    FROM Cand
    WHERE rn <= nl;

    /* ---------- Totales de VENTA a partir del detalle ---------- */
    UPDATE v
       SET SUBTOTAL = d.s,
           IMPUESTO = CAST(ROUND(d.s * @TasaIGV, 2) AS numeric(10,2)),
           TOTAL    = d.s + CAST(ROUND(d.s * @TasaIGV, 2) AS numeric(10,2))
    FROM dbo.VENTA v
    JOIN (SELECT IDVENTA, SUM(SUBTOTAL) AS s
          FROM dbo.DETALLE_VENTA
          WHERE IDVENTA > @IdVentaBase
          GROUP BY IDVENTA) d ON d.IDVENTA = v.IDVENTA;

    /* ---------- PAGO: 1 pago (aprox. 86 %) o 2 pagos (aprox. 14 %) ---------- */
    SELECT IDVENTA,
           1 + ABS(CHECKSUM(NEWID()) % 5)          AS tipo1,
           CASE WHEN IDVENTA % 7 = 0 THEN 1 ELSE 0 END AS dividido
    INTO #PagoPlan
    FROM #V;

    -- Pago principal (o primera mitad si es dividido)
    INSERT INTO dbo.PAGO (IDTIPO, IDVENTA, IMPORTE)
    SELECT pp.tipo1, v.IDVENTA,
           CAST(CASE WHEN pp.dividido = 1 THEN ROUND(v.TOTAL * 0.5, 2) ELSE v.TOTAL END AS numeric(10,2))
    FROM #PagoPlan pp
    JOIN dbo.VENTA v ON v.IDVENTA = pp.IDVENTA;

    -- Segunda mitad con un medio de pago distinto
    INSERT INTO dbo.PAGO (IDTIPO, IDVENTA, IMPORTE)
    SELECT (pp.tipo1 % 5) + 1, v.IDVENTA,
           CAST(v.TOTAL - ROUND(v.TOTAL * 0.5, 2) AS numeric(10,2))
    FROM #PagoPlan pp
    JOIN dbo.VENTA v ON v.IDVENTA = pp.IDVENTA
    WHERE pp.dividido = 1;

    DROP TABLE IF EXISTS #Cli, #Emp, #Prod, #Num, #R, #VentaGen, #V, #PagoPlan;

    COMMIT TRAN;
    PRINT 'Carga de datos de prueba finalizada correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT 'Error en la carga: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO

/* =====================================================================
   VERIFICACION
   ===================================================================== */

-- 1) Conteo por tabla
SELECT 'CLIENTE' AS tabla, COUNT(*) AS filas FROM dbo.CLIENTE UNION ALL
SELECT 'EMPLEADO',      COUNT(*) FROM dbo.EMPLEADO UNION ALL
SELECT 'CATEGORIA',     COUNT(*) FROM dbo.CATEGORIA UNION ALL
SELECT 'PRODUCTO',      COUNT(*) FROM dbo.PRODUCTO UNION ALL
SELECT 'TIPO_PAGO',     COUNT(*) FROM dbo.TIPO_PAGO UNION ALL
SELECT 'VENTA',         COUNT(*) FROM dbo.VENTA UNION ALL
SELECT 'DETALLE_VENTA', COUNT(*) FROM dbo.DETALLE_VENTA UNION ALL
SELECT 'PAGO',          COUNT(*) FROM dbo.PAGO;

-- 2) Rango de fechas y ventas por mes
SELECT MIN(FECHA) AS primera_venta, MAX(FECHA) AS ultima_venta FROM dbo.VENTA;

SELECT FORMAT(FECHA, 'yyyy-MM') AS mes,
       COUNT(*)                 AS ventas,
       SUM(TOTAL)               AS total_vendido
FROM dbo.VENTA
GROUP BY FORMAT(FECHA, 'yyyy-MM')
ORDER BY mes;

-- 3) Controles de integridad (ambas consultas deben devolver 0 filas)
SELECT v.IDVENTA, v.SUBTOTAL, SUM(d.SUBTOTAL) AS suma_detalle
FROM dbo.VENTA v
JOIN dbo.DETALLE_VENTA d ON d.IDVENTA = v.IDVENTA
GROUP BY v.IDVENTA, v.SUBTOTAL
HAVING v.SUBTOTAL <> SUM(d.SUBTOTAL);

SELECT v.IDVENTA, v.TOTAL, SUM(p.IMPORTE) AS suma_pagos
FROM dbo.VENTA v
JOIN dbo.PAGO p ON p.IDVENTA = v.IDVENTA
GROUP BY v.IDVENTA, v.TOTAL
HAVING v.TOTAL <> SUM(p.IMPORTE);
GO

/* =====================================================================
   LIMPIEZA OPCIONAL (descomentar para reiniciar los datos de prueba)
   Respeta el orden de las claves foraneas.
   =====================================================================
-- DELETE FROM dbo.PAGO;
-- DELETE FROM dbo.DETALLE_VENTA;
-- DELETE FROM dbo.VENTA;
-- DELETE FROM dbo.PRODUCTO;
-- DELETE FROM dbo.CATEGORIA;
-- DELETE FROM dbo.TIPO_PAGO;
-- DELETE FROM dbo.EMPLEADO;
-- DELETE FROM dbo.CLIENTE;
-- DBCC CHECKIDENT ('dbo.PAGO',          RESEED, 0);
-- DBCC CHECKIDENT ('dbo.DETALLE_VENTA', RESEED, 0);
-- DBCC CHECKIDENT ('dbo.VENTA',         RESEED, 0);
-- DBCC CHECKIDENT ('dbo.PRODUCTO',      RESEED, 0);
-- DBCC CHECKIDENT ('dbo.EMPLEADO',      RESEED, 0);
-- DBCC CHECKIDENT ('dbo.CLIENTE',       RESEED, 0);
   ===================================================================== */