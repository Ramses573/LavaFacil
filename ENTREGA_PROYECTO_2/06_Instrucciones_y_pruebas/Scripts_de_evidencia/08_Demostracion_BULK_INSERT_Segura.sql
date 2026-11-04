USE LavaFacil;
GO
-- Ejecutado realmente en SSMS el 4 de noviembre de 2026.
-- La tabla temporal conserva dbo y evita duplicar registros existentes.
IF OBJECT_ID('tempdb..#InventarioBulk') IS NOT NULL
    THROW 51000, 'Abra una consulta nueva para repetir la demostración.', 1;
SELECT TOP (0) * INTO #InventarioBulk FROM dbo.Inventario;
BULK INSERT #InventarioBulk
FROM 'C:\Users\jm076\Desktop\LavaFacil\Proyecto2\02-Datos-Carga\Ramses-SSMS\05_Inventario.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    KEEPIDENTITY,
    KEEPNULLS
);
SELECT * FROM #InventarioBulk ORDER BY IdInventario;
IF (SELECT COUNT(*) FROM #InventarioBulk) <> 3
    THROW 51001, 'La carga no produjo las tres filas previstas.', 1;
GO
