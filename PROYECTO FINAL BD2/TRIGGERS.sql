USE DBGestionComercial;


GO

/*--------------------------------Eliminar Productos-------------------------------------------*/

CREATE TRIGGER TR_ValidarBajaProducto
ON Productos
INSTEAD OF UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo permitimos UPDATE si no se intenta cambiar Estado de 1 a 0 cuando ya está en 0
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.ID_Producto = d.ID_Producto
        WHERE d.Estado = 0 AND i.Estado = 0 -- ya estaba 0 y sigue 0, permito
        OR (d.Estado = 0 AND i.Estado = 1) -- Re-activación permitida si querés, si no eliminar esta línea
    )
    BEGIN
        -- Si se intenta dar baja a un producto ya dado de baja, bloqueamos
        RAISERROR('El producto ya está dado de baja.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Si pasa la validación, hacer el UPDATE normalmente
    UPDATE Productos
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
END


Go



/*–------------------------------------------- Agregar Empleados –----------------------------*/



CREATE TRIGGER trg_ValidarUsuarioUnico
ON Usuario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que no se hayan insertado campos vacíos o NULL
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE 
            Nombre_Usuario IS NULL OR LTRIM(RTRIM(Nombre_Usuario)) = '' OR
            Apellido_Usuario IS NULL OR LTRIM(RTRIM(Apellido_Usuario)) = '' OR
            DNI_Usuario IS NULL OR LTRIM(RTRIM(DNI_Usuario)) = '' OR
            Email IS NULL OR LTRIM(RTRIM(Email)) = '' OR
            Contraseña IS NULL OR LTRIM(RTRIM(Contraseña)) = '' OR
            Telefono IS NULL OR LTRIM(RTRIM(Telefono)) = ''
    )
    BEGIN
        RAISERROR('No se permiten campos vacíos o nulos en los datos del usuario.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Validar que no se repita DNI, Email o Teléfono
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
        RAISERROR('Ya existe un usuario con el mismo DNI, email o teléfono.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END


GO


/*-------------------------------------------Eliminar Empleado---------------------------------------------------------*/

CREATE TRIGGER trg_ActualizarEmpleadoInactivo
ON Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo si el Estado cambia de 1 a 0 (baja lógica) para Administrador o Empleado
    UPDATE u
    SET u.Fecha_Salida = GETDATE()
    FROM Usuario u
    INNER JOIN inserted i ON u.ID_Usuario = i.ID_Usuario
    INNER JOIN deleted d ON d.ID_Usuario = i.ID_Usuario
    WHERE d.Estado = 1 AND i.Estado = 0
      AND d.ID_TipoUsuario IN (1, 2);  -- Aplica a administradores y empleados
END;



/*----------------------------------------Agregar Cliente------------------------------ */
GO

CREATE TRIGGER trg_ValidarClienteUnico
ON Usuario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que campos obligatorios no estén vacíos ni nulos
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



GO