USE DBProyectoGestionElectronica;

GO

/*----------------------------------Ventas-------------------------------------------------*/

CREATE TRIGGER trg_ActualizarStock
ON Detalle_Venta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.Stock = p.Stock - i.Cantidad
    FROM Productos p
    JOIN inserted i ON p.ID_Producto = i.ID_Producto;
END;



GO

/*-----------------------------------Productos--------------------------------------------*/

CREATE TRIGGER TR_ValidarProductoUnico
ON Productos
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE
            -- Campos string no nulos ni vacíos (ni espacios en blanco)
            LTRIM(RTRIM(ISNULL(Nombre, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(Descripcion, ''))) = ''
            -- Campos numéricos no nulos y mayores que cero
            OR PrecioUnitario IS NULL OR PrecioUnitario <= 0
            OR PrecioSinImpuesto IS NULL OR PrecioSinImpuesto <= 0
            OR Stock IS NULL OR Stock < 0
            OR ID_Categoria IS NULL
    )
    BEGIN
        RAISERROR('Todos los campos obligatorios deben estar completos y válidos (no vacíos, no nulos, y precios/stock positivos).', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM Productos p
        JOIN inserted i ON
            p.Nombre = i.Nombre AND
            p.Descripcion = i.Descripcion AND
            p.PrecioUnitario = i.PrecioUnitario AND
            p.PrecioSinImpuesto = i.PrecioSinImpuesto AND
            p.Stock = i.Stock AND
            p.ID_Categoria = i.ID_Categoria
    )
    BEGIN
        RAISERROR('Ya existe un producto con los mismos datos.', 16, 1);
        RETURN;
    END

    INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
    SELECT Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria
    FROM inserted;
END;


Go



CREATE TRIGGER TR_ValidarBajaProducto
ON Productos
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.ID_Producto = d.ID_Producto
        WHERE d.Estado = 0 AND i.Estado = 0
    )
    BEGIN
        RAISERROR('El producto ya está dado de baja.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE p
    SET
        Nombre = i.Nombre,
        Descripcion = i.Descripcion,
        PrecioUnitario = i.PrecioUnitario,
        PrecioSinImpuesto = i.PrecioSinImpuesto,
        Stock = i.Stock,
        ID_Categoria = i.ID_Categoria,
        Estado = i.Estado
    FROM Productos p
    INNER JOIN inserted i ON p.ID_Producto = i.ID_Producto;
END;
GO




/*---------------------------------Empleados--------------------------------------------*/



CREATE TRIGGER trg_ValidarUsuarioUnico
ON Usuario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN inserted i ON 
            (u.DNI_Usuario = i.DNI_Usuario
             OR u.Email = i.Email
             OR u.Telefono = i.Telefono)
        WHERE u.ID_Usuario <> i.ID_Usuario
    )
    BEGIN
        RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO


CREATE TRIGGER trg_ActualizarEmpleadoInactivo
ON Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

   
    UPDATE u
    SET u.Fecha_Salida = GETDATE()
    FROM Usuario u
    INNER JOIN inserted i ON u.ID_Usuario = i.ID_Usuario
    INNER JOIN deleted d ON d.ID_Usuario = i.ID_Usuario
    WHERE d.Estado = 1
      AND i.Estado = 0
      AND d.ID_TipoUsuario IN (1, 2)
      AND d.Estado <> i.Estado; 
END;
GO





/*-----------------------------CLIENTES--------------------------------------*/


CREATE TRIGGER trg_ValidarClienteUnico
ON Usuario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar campos obligatorios
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE LTRIM(RTRIM(ISNULL(Nombre_Usuario, ''))) = ''
           OR LTRIM(RTRIM(ISNULL(Apellido_Usuario, ''))) = ''
           OR LTRIM(RTRIM(ISNULL(DNI_Usuario, ''))) = ''
           OR LTRIM(RTRIM(ISNULL(Email, ''))) = ''
           OR LTRIM(RTRIM(ISNULL(Telefono, ''))) = ''
    )
    BEGIN
        RAISERROR('No se permiten campos obligatorios vacíos o nulos (Nombre, Apellido, DNI, Email o Teléfono).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Validar duplicados en DNI, Email o Teléfono
    IF EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN inserted i ON 
            (u.DNI_Usuario = i.DNI_Usuario
             OR u.Email = i.Email
             OR u.Telefono = i.Telefono)
        WHERE u.ID_Usuario <> i.ID_Usuario
    )
    BEGIN
        RAISERROR('Ya existe un cliente con el mismo DNI, Email o Teléfono.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END


