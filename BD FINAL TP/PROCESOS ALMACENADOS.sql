
USE DBProyectoGestionElectronica;

GO

CREATE TYPE TVP_DetalleVenta AS TABLE (
    ID_Producto INT,
    Cantidad INT
);

GO


CREATE PROCEDURE AgregarVenta
(
    @ID_Usuario INT,
    @ID_Cliente INT,
    @ProductosVenta TVP_DetalleVenta READONLY
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_Usuario = @ID_Cliente
        BEGIN
            RAISERROR('El vendedor y el cliente no pueden ser la misma persona.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_Usuario IS NULL
        BEGIN
            RAISERROR('El parámetro ID_Usuario es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_Cliente IS NULL
        BEGIN
            RAISERROR('El parámetro ID_Cliente es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND u.Estado = 1
              AND p.ID_SubMenu = 1
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permisos para realizar una venta o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Cliente
              AND ID_TipoUsuario = 3
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El cliente no existe, no está activo o no tiene el rol correcto.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM @ProductosVenta)
        BEGIN
            RAISERROR('Debe ingresar al menos un producto para realizar la venta.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT ID_Producto
            FROM @ProductosVenta
            GROUP BY ID_Producto
            HAVING COUNT(*) > 1
        )
        BEGIN
            RAISERROR('Un mismo producto no puede repetirse. Sume la cantidad en una sola línea.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @ProductosVenta WHERE Cantidad <= 0)
        BEGIN
            RAISERROR('La cantidad de cada producto debe ser mayor que cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            LEFT JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto
            WHERE pr.ID_Producto IS NULL
        )
        BEGIN
            RAISERROR('Uno o más productos ingresados no existen.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto
            WHERE pr.Estado = 0
        )
        BEGIN
            RAISERROR('Uno o más productos están inactivos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto
            WHERE pv.Cantidad > ISNULL(pr.Stock, 0)
        )
        BEGIN
            RAISERROR('Uno o más productos no tienen stock suficiente.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END


        DECLARE @Total DECIMAL(12, 2);
        SELECT @Total = SUM(pv.Cantidad * pr.PrecioUnitario)
        FROM @ProductosVenta pv
        JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto;


        DECLARE @ID_Venta INT;
        INSERT INTO Ventas (ID_Usuario, ID_Cliente, Importe_Total)
        VALUES (@ID_Usuario, @ID_Cliente, @Total);

        SET @ID_Venta = SCOPE_IDENTITY();

        INSERT INTO Detalle_Venta (ID_Venta, ID_Producto, Cantidad, Precio_Unitario)
        SELECT @ID_Venta, pv.ID_Producto, pv.Cantidad, pr.PrecioUnitario
        FROM @ProductosVenta pv
        JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END



/*
DECLARE @DetalleVenta TVP_DetalleVenta;

INSERT INTO @DetalleVenta (ID_Producto, Cantidad)
VALUES (1, 1 );

EXEC AgregarVenta
    @ID_Usuario = 1,
    @ID_Cliente =6 ,
    @ProductosVenta = @DetalleVenta;
*/




/*-----------------------------------LISTA DE VENTAS----------------------------*/
GO
CREATE PROCEDURE SP_ListadoDeVentas(
    @ID_Usuario INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF @ID_Usuario IS NULL OR @ID_Usuario = 0
        BEGIN
            RAISERROR('Debe ingresar un ID de usuario válido.', 16, 1);
            RETURN;
        END
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Usuario
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no existe o está inactivo.', 16, 1);
            RETURN;
        END

        DECLARE @TipoUsuario INT;
        SELECT @TipoUsuario = ID_TipoUsuario
        FROM Usuario
        WHERE ID_Usuario = @ID_Usuario;

        IF NOT EXISTS (
            SELECT 1
            FROM Permiso
            WHERE ID_TipoUsuario = @TipoUsuario
              AND ID_SubMenu = 2
              AND Estado = 1
        )
        BEGIN
            RAISERROR('Permiso denegado. El usuario no tiene acceso al listado de ventas.', 16, 1);
            RETURN;
        END

        SELECT 
            V.ID_Venta,
            V.FechaDeVenta,
            CONCAT(C.Nombre_Usuario, ' ', C.Apellido_Usuario) AS Nombre_Cliente,
            CONCAT(U.Nombre_Usuario, ' ', U.Apellido_Usuario) AS Nombre_Vendedor,
            STRING_AGG(CONCAT(P.Nombre, ' (', DV.Cantidad, ')'), ', ') AS ProductosComprados,
            SUM(DV.Cantidad) AS CantidadTotalProductos,
            V.Importe_Total
        FROM Ventas V
        INNER JOIN Detalle_Venta DV ON V.ID_Venta = DV.ID_Venta
        INNER JOIN Productos P ON DV.ID_Producto = P.ID_Producto
        INNER JOIN Usuario C ON V.ID_Cliente = C.ID_Usuario AND C.Estado = 1
        INNER JOIN Usuario U ON V.ID_Usuario = U.ID_Usuario AND U.Estado = 1
        GROUP BY 
            V.ID_Venta, 
            V.FechaDeVenta,
            C.Nombre_Usuario, C.Apellido_Usuario,
            U.Nombre_Usuario, U.Apellido_Usuario,
            V.Importe_Total;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;



--EJECUTAR

--EXEC SP_ListadoDeVentas @ID_Usuario = 1;




/*---------------------------------Listado de Ventas por id------------------------------------*/

GO
  
CREATE PROCEDURE SP_ListadoDeVentasPorID (
    @ID_Usuario INT,
    @ID_Venta INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_Usuario IS NULL OR @ID_Usuario = 0
        BEGIN
            RAISERROR('Debe ingresar un ID de usuario válido.', 16, 1);
            RETURN;
        END

        IF @ID_Venta IS NULL OR @ID_Venta = 0
        BEGIN
            RAISERROR('Debe ingresar un ID de venta válido.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Usuario AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no existe o está inactivo.', 16, 1);
            RETURN;
        END

        DECLARE @TipoUsuario INT;
        SELECT @TipoUsuario = ID_TipoUsuario
        FROM Usuario
        WHERE ID_Usuario = @ID_Usuario;

        IF NOT EXISTS (
            SELECT 1 FROM Permiso
            WHERE ID_TipoUsuario = @TipoUsuario
              AND ID_SubMenu = 3
              AND Estado = 1
        )
        BEGIN
            RAISERROR('Permiso denegado. El usuario no tiene acceso para buscar ventas.', 16, 1);
            RETURN;
        END
        SELECT 
            V.ID_Venta,
            V.FechaDeVenta,
            CONCAT(C.Nombre_Usuario, ' ', C.Apellido_Usuario) AS Nombre_Cliente,
            CONCAT(U.Nombre_Usuario, ' ', U.Apellido_Usuario) AS Nombre_Vendedor,
            STRING_AGG(CONCAT(P.Nombre, ' (', DV.Cantidad, ')'), ', ') AS ProductosComprados,
            SUM(DV.Cantidad) AS CantidadTotalProductos,
            V.Importe_Total
        FROM Ventas V
        INNER JOIN Detalle_Venta DV ON V.ID_Venta = DV.ID_Venta
        INNER JOIN Productos P ON DV.ID_Producto = P.ID_Producto
        INNER JOIN Usuario C ON V.ID_Cliente = C.ID_Usuario AND C.Estado = 1
        INNER JOIN Usuario U ON V.ID_Usuario = U.ID_Usuario AND U.Estado = 1
        WHERE V.ID_Venta = @ID_Venta
        GROUP BY 
            V.ID_Venta, 
            V.FechaDeVenta,
            C.Nombre_Usuario, C.Apellido_Usuario,
            U.Nombre_Usuario, U.Apellido_Usuario,
            V.Importe_Total;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No se encontró la venta con el ID especificado o los datos asociados están inactivos.', 16, 1);
        END
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;


/*EXEC SP_ListadoDeVentasPorID 
    @ID_Usuario =1,
    @ID_Venta  =1;
	*/



/*---------------------------------------Agregar productos--------------------------------------*/

GO
CREATE PROCEDURE AgregarProducto(
    @ID_UsuarioEjecutor INT,
    @Nombre NVARCHAR(50),
    @Descripcion NVARCHAR(100),
    @PrecioUnitario DECIMAL(10,2),
    @PrecioSinImpuesto DECIMAL(10,2),
    @Stock INT,
    @ID_Categoria INT
)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        BEGIN
            RAISERROR('El nombre del producto no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END
        IF LEN(@Nombre) > 50
        BEGIN
            RAISERROR('El nombre del producto excede el máximo permitido (50 caracteres).', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = ''
        BEGIN
            RAISERROR('La descripción del producto no puede estar vacía.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END
        IF LEN(@Descripcion) > 100
        BEGIN
            RAISERROR('La descripción del producto excede el máximo permitido (100 caracteres).', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @PrecioUnitario IS NULL
        BEGIN
            RAISERROR('El precio unitario no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END
        IF @PrecioUnitario < 1 OR @PrecioUnitario > 1000000000
        BEGIN
            RAISERROR('El precio unitario está fuera del rango permitido (1 a 1,000,000,000).', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @PrecioSinImpuesto IS NULL
        BEGIN
            RAISERROR('El precio sin impuesto no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END
        IF @PrecioSinImpuesto < 1 OR @PrecioSinImpuesto > 1000000000
        BEGIN
            RAISERROR('El precio sin impuesto está fuera del rango permitido (1 a 1,000,000,000).', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @Stock IS NULL
        BEGIN
            RAISERROR('El stock no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END
        IF @Stock <= 0
        BEGIN
            RAISERROR('El stock debe ser mayor que cero.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @ID_Categoria IS NULL
        BEGIN
            RAISERROR('La categoría no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor 
              AND p.ID_SubMenu = 4 
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para agregar productos.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE ID_Categoria = @ID_Categoria)
        BEGIN
            RAISERROR('La categoría no existe.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
        VALUES (@Nombre, @Descripcion, @PrecioUnitario, @PrecioSinImpuesto, @Stock, @ID_Categoria);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;






/*
EXEC AgregarProducto
    @ID_UsuarioEjecutor = 1,
    @Nombre = 'Nuevo Procesador T900',
    @Descripcion = 'Procesador avanzado con 16 núcleos y alto rendimiento.',
   @PrecioUnitario = 200000,
    @PrecioSinImpuesto = 380.00,
    @Stock = 22,
    @ID_Categoria = 1;
*/	


/*-----------------------------------Listar Productos------------------------------------------------------*/
GO

CREATE PROCEDURE ListarProductos
    (@ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor 
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 5
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para listar productos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT 
            ID_Producto,
            Nombre,
            Descripcion,
            PrecioUnitario,
            PrecioSinImpuesto,
            Stock,
            ID_Categoria,
            CASE 
                WHEN Estado = 1 THEN 'Activo'
                WHEN Estado = 0 THEN 'Inactivo'
            END AS Estado
        FROM Productos
        ORDER BY ID_Producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END



--EXEC ListarProductos @ID_UsuarioEjecutor=1;



/*--------------------------------------Listar Productos por ID Categoria----------------------------------------------*/
GO
CREATE PROCEDURE ListarProductosPorCategoria(
    @ID_UsuarioEjecutor INT,
    @ID_Categoria INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_Categoria IS NULL
        BEGIN
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Categoria son obligatorios.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1)
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 6
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para listar productos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE ID_Categoria = @ID_Categoria)
        BEGIN
            RAISERROR('La categoría no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT 
            p.ID_Producto,
            p.Nombre,
            p.Descripcion,
            p.PrecioUnitario,
            p.PrecioSinImpuesto,
            p.Stock,
            c.Nombre AS Categoria
        FROM Productos p
        JOIN Categorias c ON p.ID_Categoria = c.ID_Categoria
        WHERE p.ID_Categoria = @ID_Categoria
		AND p.Estado = 1
        ORDER BY p.Nombre;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;


--EXEC ListarProductosPorCategoria @ID_UsuarioEjecutor = 1, @ID_Categoria = 1;


/*--------------------------------Eliminar Productos-------------------------------------------*/
GO

CREATE PROCEDURE BajaLogicaProducto
   ( @ID_UsuarioEjecutor INT,
    @ID_Producto INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
        BEGIN
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 10
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para dar baja productos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
        BEGIN
            RAISERROR('El producto no existe o ya está dado de baja.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Productos
        SET Estado = 0
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;



--EXEC BajaLogicaProducto @ID_UsuarioEjecutor = 1, @ID_Producto = 13;

/*-----------------------------MODIFICAR PRECIO---------------------------------------*/
GO
CREATE PROCEDURE ModificarPrecioProducto(
    @ID_UsuarioEjecutor INT,
    @ID_Producto INT,
    @NuevoPrecioUnitario DECIMAL(10,2),
    @NuevoPrecioSinImpuesto DECIMAL(10,2))
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor AND p.ID_SubMenu = 7 AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para modificar productos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
        BEGIN
            RAISERROR('El producto no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NuevoPrecioUnitario IS NULL OR @NuevoPrecioUnitario < 1 OR @NuevoPrecioUnitario > 1000000000
           OR @NuevoPrecioSinImpuesto IS NULL OR @NuevoPrecioSinImpuesto < 1 OR @NuevoPrecioSinImpuesto > 1000000000
        BEGIN
            RAISERROR('Los precios deben estar entre 1 y 1000000000.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NuevoPrecioSinImpuesto > @NuevoPrecioUnitario
        BEGIN
            RAISERROR('El precio sin impuesto no puede ser mayor que el precio unitario.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Productos
        SET PrecioUnitario = @NuevoPrecioUnitario,
            PrecioSinImpuesto = @NuevoPrecioSinImpuesto
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;



/*
EXEC ModificarPrecioProducto
    @ID_UsuarioEjecutor = 1,
    @ID_Producto = 13,
    @NuevoPrecioUnitario = 1500.00,
    @NuevoPrecioSinImpuesto = 1200.00;
	
*/

/*----------------------------------------Actualizar stock----------------------------------------------------*/


GO
CREATE PROCEDURE ActualizarStockProducto(
    @ID_UsuarioEjecutor INT,
    @ID_Producto INT,
    @NuevoStock INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor AND p.ID_SubMenu = 8 AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para actualizar stock.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
        BEGIN
            RAISERROR('El producto no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NuevoStock IS NULL OR @NuevoStock < 0
        BEGIN
            RAISERROR('El stock debe ser un número mayor o igual a cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NuevoStock > 1000000
        BEGIN
            RAISERROR('El stock es demasiado alto.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Actualizar el stock
        UPDATE Productos
        SET Stock = @NuevoStock
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;


/*
EXEC ActualizarStockProducto
    @ID_UsuarioEjecutor = 1,
    @ID_Producto = 4,
    @NuevoStock = 100;
*/



/*---------------------------------------------Agregar categoria-----------------------------------------*/

GO
CREATE PROCEDURE AgregarCategoria(
    @ID_UsuarioEjecutor INT,
    @NombreCategoria NVARCHAR(100))
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @NombreCategoria IS NULL OR LEN(LTRIM(RTRIM(@NombreCategoria))) = 0
        BEGIN
            RAISERROR('El nombre de la categoría no puede ser NULL ni estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar longitud máxima
        IF LEN(@NombreCategoria) > 100
        BEGIN
            RAISERROR('El nombre de la categoría no puede superar los 100 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 9
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para agregar categorías.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM Categorias WHERE UPPER(LTRIM(RTRIM(Nombre))) = UPPER(LTRIM(RTRIM(@NombreCategoria)))
        )
        BEGIN
            RAISERROR('La categoría ya existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar la nueva categoría
        INSERT INTO Categorias (Nombre)
        VALUES (@NombreCategoria);

        COMMIT TRANSACTION;

        PRINT 'Categoría agregada correctamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMensaje, 16, 1);
    END CATCH
END;


--EXEC AgregarCategoria @ID_UsuarioEjecutor = 3, @NombreCategoria = 'Electrónica';

 
/*---------------------------------Restablecer producto---------------------------------------------------------------*/


GO

CREATE PROCEDURE RestablecerProducto(
   @ID_UsuarioEjecutor INT,
   @ID_Producto INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
        BEGIN
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor 
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 11
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer productos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Productos 
            WHERE ID_Producto = @ID_Producto AND Estado = 0
        )
        BEGIN
            RAISERROR('El producto no existe o ya está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Productos
        SET Estado = 1
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
        PRINT 'Producto restablecido correctamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;

/*
EXEC RestablecerProducto 
    @ID_UsuarioEjecutor = 1, 
    @ID_Producto = 4;
	
*/



/*--------------------------------------Empleado------------------------------------------------------------*/


CREATE PROCEDURE AgregarEmpleado_Administrador (
    @ID_UsuarioEjecutor INT,
    @ID_TipoUsuario INT,         
    @Nombre NVARCHAR(50),
    @Apellido NVARCHAR(50),
    @DNI NVARCHAR(20),
    @Email NVARCHAR(30),
    @Contrasena NVARCHAR(30),
    @Telefono NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_TipoUsuario IS NULL
        BEGIN
            RAISERROR('El tipo de usuario es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
        BEGIN
            RAISERROR('El nombre es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
        BEGIN
            RAISERROR('El apellido es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @DNI IS NULL OR LTRIM(RTRIM(@DNI)) = ''
        BEGIN
            RAISERROR('El DNI es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
        BEGIN
            RAISERROR('El Email es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Contrasena IS NULL OR LTRIM(RTRIM(@Contrasena)) = ''
        BEGIN
            RAISERROR('La contraseña es obligatoria.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
        BEGIN
            RAISERROR('El teléfono es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Nombre) > 50
        BEGIN
            RAISERROR('El nombre no puede superar los 50 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Apellido) > 50
        BEGIN
            RAISERROR('El apellido no puede superar los 50 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@DNI) > 20
        BEGIN
            RAISERROR('El DNI no puede superar los 20 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Email) > 30
        BEGIN
            RAISERROR('El email no puede superar los 30 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Contrasena) > 30
        BEGIN
            RAISERROR('La contraseña no puede superar los 30 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Telefono) > 20
        BEGIN
            RAISERROR('El teléfono no puede superar los 20 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_TipoUsuario NOT IN (1, 2)
        BEGIN
            RAISERROR('Solo se permite tipo de usuario Administrador (1) o Empleado (2).', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @ID_SubMenu INT = CASE 
                                      WHEN @ID_TipoUsuario = 1 THEN 12  -- Alta Administrador
                                      WHEN @ID_TipoUsuario = 2 THEN 13  -- Alta Empleado
                                  END;

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor 
              AND p.ID_SubMenu = @ID_SubMenu
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no tiene permiso para realizar esta acción.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM Usuario
            WHERE DNI_Usuario = @DNI
               OR Email = @Email
               OR Telefono = @Telefono
        )
        BEGIN
            RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO Usuario (ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario, DNI_Usuario, Email, Contraseña, Telefono, Fecha_Ingreso, Estado)
        VALUES (@ID_TipoUsuario, @Nombre, @Apellido, @DNI, @Email, @Contrasena, @Telefono, GETDATE(), 1);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- Muestra el mensaje de error interno
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END
GO



/* EXEC AgregarEmpleado_Admistrador
    @ID_UsuarioEjecutor = 1,
    @ID_TipoUsuario = 2,
    @Nombre = 'fernando',
    @Apellido = '',
    @DNI = '444440500',
    @Email = 'ferv.gutierrez@empresa.com',
    @Contrasena = 'Callefalsa123',
    @Telefono = '000000845'; */



/*-----------------------------------------------ListarEmpleados---------------------------------*/
GO

CREATE PROCEDURE ListarEmpleados(
    @ID_UsuarioEjecutor INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Validar que el ID del usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);
            RETURN;
        END

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            RETURN;
        END

        -- Validar que el tipo de usuario del ejecutor sea Administrador o Empleado
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND ID_TipoUsuario IN (1, 2)
        )
        BEGIN
            RAISERROR('Solo administradores o empleados pueden listar usuarios.', 16, 1);
            RETURN;
        END

        -- Validar que el usuario ejecutor tenga permiso para listar empleados (ID_SubMenu = 14)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 14
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para listar empleados.', 16, 1);
            RETURN;
        END

        -- Listar empleados y administradores con información adicional
        SELECT 
            u.ID_Usuario,
            u.Nombre_Usuario,
            u.Apellido_Usuario,
            u.DNI_Usuario,
            u.Email,
            u.Contraseña,  -- Incluido porque vos lo solicitaste
            u.Telefono,
            u.Fecha_Ingreso,
            u.Fecha_Salida,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            CASE 
                WHEN u.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Usuario u
        JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        WHERE u.ID_TipoUsuario IN (1, 2);  -- Empleado o Administrador
    END TRY
    BEGIN CATCH
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END


--EXEC ListarEmpleados @ID_UsuarioEjecutor = 1;


/*----------------------------------------------Buscar empleado–-----------------------------------------*/
GO
CREATE PROCEDURE BuscarEmpleadoPorID(
    @ID_UsuarioEjecutor INT,
    @ID_EmpleadoBuscar INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el ID del usuario ejecutor no sea NULL y mayor que cero
        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
        BEGIN
            RAISERROR('El ID del usuario ejecutor es obligatorio y debe ser mayor que cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el ID del empleado a buscar no sea NULL y mayor que cero
        IF @ID_EmpleadoBuscar IS NULL OR @ID_EmpleadoBuscar <= 0
        BEGIN
            RAISERROR('El ID del empleado a buscar es obligatorio y debe ser mayor que cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar existencia y estado activo del usuario ejecutor
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar permisos sobre el SubMenú "Buscar Empleado por ID" (ID_SubMenu = 15)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 15
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para buscar empleados por ID.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar existencia del empleado buscado (solo Administrador o Empleado)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_EmpleadoBuscar
              AND ID_TipoUsuario IN (1, 2)
        )
        BEGIN
            RAISERROR('El empleado buscado no existe o no es administrador/empleado.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Mostrar datos del empleado
        SELECT 
            u.ID_Usuario AS ID_Empleado,
            u.Nombre_Usuario,
            u.Apellido_Usuario,
            u.DNI_Usuario,
            u.Email,
            u.Telefono,
            u.Fecha_Ingreso,
            u.Fecha_Salida,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            CASE 
                WHEN u.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Usuario u
        JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        WHERE u.ID_Usuario = @ID_EmpleadoBuscar;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END

/*
EXEC BuscarEmpleadoPorID 
    @ID_UsuarioEjecutor = 1,
    @ID_EmpleadoBuscar = 4;

*/



/*------------------------------------Eliminar Empleado--------------------------------------------------*/

CREATE PROCEDURE EliminarEmpleado(
    @ID_UsuarioEjecutor INT,
    @ID_Empleado INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_Empleado IS NULL
        BEGIN
            RAISERROR('El ID del empleado a eliminar es obligatorio.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_UsuarioEjecutor = @ID_Empleado
        BEGIN
            RAISERROR('No puede eliminarse a sí mismo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 17
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para eliminar empleados.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario 
            WHERE ID_Usuario = @ID_Empleado 
              AND ID_TipoUsuario IN (1, 2)
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no es un empleado/administrador válido o ya está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Usuario
        SET Estado = 0
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;

/*
EXEC EliminarEmpleado 
    @ID_UsuarioEjecutor = 1, 
    @ID_Empleado = 4;
*/


/*-------------------------------------------Modificar Empleado---------------------------------------------------------*/


GO
CREATE PROCEDURE ModificarEmpleado
(
    @ID_UsuarioEjecutor INT,
    @ID_Empleado INT,
    @Nombre NVARCHAR(50) = NULL,
    @Apellido NVARCHAR(50) = NULL,
    @DNI NVARCHAR(20) = NULL,
    @Email NVARCHAR(50) = NULL,
    @Contraseña NVARCHAR(30) = NULL,
    @Telefono NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ID_Empleado IS NULL
        BEGIN
            RAISERROR('El ID del empleado a modificar no puede ser NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 16
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para modificar empleados.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario 
            WHERE ID_Usuario = @ID_Empleado
              AND ID_TipoUsuario IN (1, 2)
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El empleado no existe, no es válido o está dado de baja.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Nombre IS NULL AND @Apellido IS NULL AND @DNI IS NULL AND 
           @Email IS NULL AND @Contraseña IS NULL AND @Telefono IS NULL
        BEGIN
            RAISERROR('Debe proporcionar al menos un dato para modificar.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Email IS NOT NULL AND @Email NOT LIKE '%@%.%'
        BEGIN
            RAISERROR('El email no tiene un formato válido.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 
            FROM Usuario
            WHERE ID_Usuario <> @ID_Empleado
              AND (
                   (@DNI IS NOT NULL AND DNI_Usuario = @DNI)
                OR (@Email IS NOT NULL AND Email = @Email)
                OR (@Telefono IS NOT NULL AND Telefono = @Telefono)
              )
        )
        BEGIN
            RAISERROR('DNI, Email o Teléfono ya están registrados por otro usuario.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Nombre IS NOT NULL AND LTRIM(RTRIM(@Nombre)) = ''
        BEGIN
            RAISERROR('El nombre no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Apellido IS NOT NULL AND LTRIM(RTRIM(@Apellido)) = ''
        BEGIN
            RAISERROR('El apellido no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @DNI IS NOT NULL AND LTRIM(RTRIM(@DNI)) = ''
        BEGIN
            RAISERROR('El DNI no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Email IS NOT NULL AND LTRIM(RTRIM(@Email)) = ''
        BEGIN
            RAISERROR('El email no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Contraseña IS NOT NULL AND LTRIM(RTRIM(@Contraseña)) = ''
        BEGIN
            RAISERROR('La contraseña no puede estar vacía.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Telefono IS NOT NULL AND LTRIM(RTRIM(@Telefono)) = ''
        BEGIN
            RAISERROR('El teléfono no puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Nombre IS NOT NULL AND LEN(@Nombre) > 50
        BEGIN
            RAISERROR('El nombre no puede superar los 50 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Apellido IS NOT NULL AND LEN(@Apellido) > 50
        BEGIN
            RAISERROR('El apellido no puede superar los 50 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @DNI IS NOT NULL AND LEN(@DNI) > 20
        BEGIN
            RAISERROR('El DNI no puede superar los 20 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Email IS NOT NULL AND LEN(@Email) > 50
        BEGIN
            RAISERROR('El email no puede superar los 50 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Contraseña IS NOT NULL AND LEN(@Contraseña) > 30
        BEGIN
            RAISERROR('La contraseña no puede superar los 30 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Telefono IS NOT NULL AND LEN(@Telefono) > 20
        BEGIN
            RAISERROR('El teléfono no puede superar los 20 caracteres.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Usuario
        SET
            Nombre_Usuario = COALESCE(@Nombre, Nombre_Usuario),
            Apellido_Usuario = COALESCE(@Apellido, Apellido_Usuario),
            DNI_Usuario = COALESCE(@DNI, DNI_Usuario),
            Email = COALESCE(@Email, Email),
            Contraseña = COALESCE(@Contraseña, Contraseña),
            Telefono = COALESCE(@Telefono, Telefono)
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END


/*
EXEC ModificarEmpleado
    @ID_UsuarioEjecutor = 5,
    @ID_Empleado = 10,
    @Nombre = 'Lucas',
    @Apellido = 'Fernandez',
    @DNI = '30123456',
    @Email = 'lucas.fernandez@email.com',
    @Contraseña = 'nuevaClave123',
    @Telefono = '1122334455';

*/

/*-------------------------------------------Restablecer Empleado--------------------------------------------------------------------*/

GO
CREATE PROCEDURE RestablecerEmpleado
(
    @ID_UsuarioEjecutor INT,
    @Email NVARCHAR(30),
    @NuevaContraseña NVARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('Debe ingresar un ID de usuario ejecutor.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
        BEGIN
            RAISERROR('Debe ingresar un email válido.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @NuevaContraseña IS NULL OR LTRIM(RTRIM(@NuevaContraseña)) = ''
        BEGIN
            RAISERROR('Debe ingresar una contraseña válida.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 19
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer empleados.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        DECLARE @ID_Empleado INT;
        SELECT @ID_Empleado = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND ID_TipoUsuario = 2;

        IF @ID_Empleado IS NULL
        BEGIN
            RAISERROR('No se encontró un empleado con ese correo.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Empleado AND Estado = 1
        )
        BEGIN
            RAISERROR('El empleado ya está activo. No es necesario restablecer.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        UPDATE Usuario
        SET Estado = 1,
            Contraseña = @NuevaContraseña
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
        PRINT 'Empleado restablecido correctamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END

/*

EXEC RestablecerEmpleado
    @ID_UsuarioEjecutor = 1,                
    @Email = 'empleado@example.com',           
    @NuevaContraseña = 'NuevaClaveSegura123';  

*/


/*------------------------------------------Restablecer Administrador--------------------------------------------------------------*/

GO
CREATE PROCEDURE RestablecerAdministrador
(
    @ID_UsuarioEjecutor INT,
    @Email NVARCHAR(30),
    @NuevaContraseña NVARCHAR(30)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
           OR @NuevaContraseña IS NULL OR LTRIM(RTRIM(@NuevaContraseña)) = ''
        BEGIN
            RAISERROR('El email y la nueva contraseña no pueden estar vacíos.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 18
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer administradores.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @ID_UsuarioRestablecer INT;
        SELECT @ID_UsuarioRestablecer = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND ID_TipoUsuario = 1;

        IF @ID_UsuarioRestablecer IS NULL
        BEGIN
            RAISERROR('No se encontró un administrador con ese correo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioRestablecer AND Estado = 1
        )
        BEGIN
            RAISERROR('El administrador ya está activo. No es necesario restablecer.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Usuario
        SET Estado = 1,
            Contraseña = @NuevaContraseña
        WHERE ID_Usuario = @ID_UsuarioRestablecer;

        COMMIT TRANSACTION;
        PRINT 'Administrador restablecido correctamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;


/*
EXEC RestablecerAdministrador
    @ID_UsuarioEjecutor = 1,                  
    @Email = 'admin.prueba@example.com',           
    @NuevaContraseña = 'NuevaClaveSegura456';         

*/



/*------------------------------------------CLIENTES--------------------------------------*/

GO
CREATE PROCEDURE AgregarCliente (
    @ID_UsuarioEjecutor INT,
    @Nombre NVARCHAR(50),
    @Apellido NVARCHAR(50),
    @DNI NVARCHAR(20),
    @Email NVARCHAR(50),
    @Contraseña NVARCHAR(30),
    @Telefono NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor 
              AND p.ID_SubMenu = 20 AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para agregar clientes.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(LTRIM(RTRIM(@Nombre))) = 0
            OR LEN(LTRIM(RTRIM(@Apellido))) = 0
            OR LEN(LTRIM(RTRIM(@DNI))) = 0
            OR LEN(LTRIM(RTRIM(@Email))) = 0
            OR LEN(LTRIM(RTRIM(@Contraseña))) = 0
            OR LEN(LTRIM(RTRIM(@Telefono))) = 0
        BEGIN
            RAISERROR('Ningún campo puede estar vacío.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF LEN(@Nombre) > 50 BEGIN RAISERROR('Nombre muy largo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END
        IF LEN(@Apellido) > 50 BEGIN RAISERROR('Apellido muy largo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END
        IF LEN(@DNI) > 20 BEGIN RAISERROR('DNI muy largo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END
        IF LEN(@Email) > 30 BEGIN RAISERROR('Email muy largo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END
        IF LEN(@Contraseña) > 50 BEGIN RAISERROR('Contraseña muy larga.', 16, 1); ROLLBACK TRANSACTION; RETURN; END
        IF LEN(@Telefono) > 20 BEGIN RAISERROR('Teléfono muy largo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END

        INSERT INTO Usuario (
            ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario,
            DNI_Usuario, Email, Contraseña, Telefono, Fecha_Ingreso, Estado
        )
        VALUES (
            3, @Nombre, @Apellido, @DNI, @Email, @Contraseña, @Telefono, GETDATE(), 1
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

/*
EXEC AgregarCliente
    @ID_UsuarioEjecutor = 1,
    @Nombre = 'Juan',
    @Apellido = 'Pérez',
    @DNI = '12345678',
    @Email = 'juan.perez@email.com',
    @Contrasena = '12345',
    @Telefono = '1155550000';

*/


/*--------------------------------Listar Cliente---------------------------------------------------------*/

GO

CREATE PROCEDURE ListarClientes (
    @ID_UsuarioEjecutor INT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 
        FROM Usuario 
        WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
    )
    BEGIN
        RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
        WHERE u.ID_Usuario = @ID_UsuarioEjecutor
          AND p.ID_SubMenu = 21
          AND p.Estado = 1
    )
    BEGIN
        RAISERROR('El usuario no tiene permiso para listar clientes.', 16, 1);
        RETURN;
    END

    SELECT 
        ID_Usuario,
        Nombre_Usuario,
        Apellido_Usuario,
        DNI_Usuario,
        Email,
        Telefono,
        Fecha_Ingreso,
        Fecha_Salida,
        CASE 
            WHEN Estado = 1 THEN 'Activo'
            ELSE 'Inactivo'
        END AS Estado_Descripcion
    FROM Usuario
    WHERE ID_TipoUsuario = 3
    ORDER BY Apellido_Usuario, Nombre_Usuario;
END;




--EXEC ListarClientes @ID_UsuarioEjecutor = 3;



/*--------------------------------Buscar cliente por ID------------------------------------------------------------*/

GO

CREATE  PROCEDURE BuscarClientePorID(
    @ID_UsuarioEjecutor INT = NULL,
    @ID_ClienteBuscar INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            SELECT 0 AS Resultado, 'Debe ingresar un ID de usuario ejecutor válido.' AS Mensaje;
            RETURN;
        END

        IF @ID_ClienteBuscar IS NULL
        BEGIN
            SELECT 0 AS Resultado, 'Debe ingresar un ID de cliente válido para buscar.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            SELECT 0 AS Resultado, 'El usuario ejecutor no existe o no está activo.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 22 AND p.Estado = 1
        )
        BEGIN
            SELECT 0 AS Resultado, 'El usuario no tiene permiso para buscar clientes por ID.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_ClienteBuscar AND ID_TipoUsuario = 3
        )
        BEGIN
            SELECT 0 AS Resultado, 'El cliente buscado no existe o no es cliente.' AS Mensaje;
            RETURN;
        END

        SELECT 
            1 AS Resultado,
            ID_Usuario AS ID_Cliente,
            Nombre_Usuario,
            Apellido_Usuario,
            DNI_Usuario,
            Email,
            Telefono,
            Fecha_Ingreso,
            Fecha_Salida,
            CASE 
                WHEN Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado,
            'Cliente encontrado correctamente.' AS Mensaje
        FROM Usuario
        WHERE ID_Usuario = @ID_ClienteBuscar;

    END TRY
    BEGIN CATCH
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;



/*EXEC BuscarClientePorID 
    @ID_UsuarioEjecutor = 1, 
    @ID_ClienteBuscar = 5;*/




/*----------------------------ELIMINAR CLIENTES-----------------------------------------------------------------*/


GO
CREATE PROCEDURE EliminarCliente
(
    @ID_UsuarioEjecutor INT,
    @ID_Cliente INT
)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 24
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para eliminar clientes.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_Cliente 
              AND ID_TipoUsuario = 3
              AND Estado = 1
        )
        BEGIN
            RAISERROR('El cliente no existe, no es cliente o ya está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Usuario
        SET Estado = 0,
            Fecha_Salida = GETDATE()
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;


--EXEC EliminarCliente @ID_UsuarioEjecutor = 1, @ID_Cliente = 5;






/*---------------------------------Modificar Cliente----------------------------------------------*/

GO
CREATE PROCEDURE ModificarCliente
(
    @ID_UsuarioEjecutor INT = NULL,
    @ID_Cliente INT,
    @Nombre NVARCHAR(50) = NULL,
    @Apellido NVARCHAR(50) = NULL,
    @DNI NVARCHAR(20) = NULL,
    @Email NVARCHAR(50) = NULL,
    @Contraseña NVARCHAR(50) = NULL,
    @Telefono NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Nombre IS NULL AND @Apellido IS NULL AND @DNI IS NULL AND @Email IS NULL AND @Contraseña IS NULL AND @Telefono IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe especificar al menos un campo para modificar.' AS Mensaje;
            RETURN;
        END

        IF @Nombre IS NOT NULL AND LEN(@Nombre) > 50
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El nombre no puede superar los 50 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @Apellido IS NOT NULL AND LEN(@Apellido) > 50
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El apellido no puede superar los 50 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @DNI IS NOT NULL AND LEN(@DNI) > 20
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El DNI no puede superar los 20 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @Email IS NOT NULL AND LEN(@Email) > 50
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El email no puede superar los 50 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @Contraseña IS NOT NULL AND LEN(@Contraseña) > 50
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'La contraseña no puede superar los 50 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @Telefono IS NOT NULL AND LEN(@Telefono) > 20
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El teléfono no puede superar los 20 caracteres.' AS Mensaje;
            RETURN;
        END

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar un ID de usuario ejecutor válido.' AS Mensaje;
            RETURN;
        END

        IF @Email IS NOT NULL AND LTRIM(RTRIM(@Email)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar un email válido.' AS Mensaje;
            RETURN;
        END

        IF @Contraseña IS NOT NULL AND LTRIM(RTRIM(@Contraseña)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar una contraseña válida.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El usuario ejecutor no existe o está inactivo.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 23
              AND p.Estado = 1
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El usuario no tiene permiso para modificar clientes.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 FROM Usuario 
            WHERE ID_Usuario = @ID_Cliente 
              AND ID_TipoUsuario = 3 
              AND Estado = 1
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El cliente no existe o está dado de baja.' AS Mensaje;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario <> @ID_Cliente
              AND (
                   (@DNI IS NOT NULL AND DNI_Usuario = @DNI)
                OR (@Email IS NOT NULL AND Email = @Email)
                OR (@Telefono IS NOT NULL AND Telefono = @Telefono)
              )
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'DNI, Email o Teléfono ya están registrados por otro usuario.' AS Mensaje;
            RETURN;
        END

        UPDATE Usuario
        SET
            Nombre_Usuario = COALESCE(@Nombre, Nombre_Usuario),
            Apellido_Usuario = COALESCE(@Apellido, Apellido_Usuario),
            DNI_Usuario = COALESCE(@DNI, DNI_Usuario),
            Email = COALESCE(@Email, Email),
            Contraseña = COALESCE(@Contraseña, Contraseña),
            Telefono = COALESCE(@Telefono, Telefono)
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;

        SELECT 1 AS Resultado, 'Cliente modificado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        SELECT 0 AS Resultado, @Mensaje AS Mensaje;
    END CATCH
END;



/*EXEC ModificarCliente
    @ID_UsuarioEjecutor = 1,
    @ID_Cliente = 5,
    @Nombre = 'NuevoNombre',
    @Telefono = '123456789'*/


/*--------------------------------Restablecer Cliente-----------------------------------------------------------*/

GO

CREATE PROCEDURE RestablecerCliente
(
    @ID_UsuarioEjecutor INT = NULL,
    @Email NVARCHAR(30) = NULL,
    @Contraseña NVARCHAR(30) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar un ID de usuario ejecutor válido.' AS Mensaje;
            RETURN;
        END

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar un email válido.' AS Mensaje;
            RETURN;
        END

        IF @Contraseña IS NULL OR LTRIM(RTRIM(@Contraseña)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'Debe ingresar una contraseña válida.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1 
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND u.Estado = 1
              AND p.ID_SubMenu = 25
              AND p.Estado = 1
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El usuario ejecutor no existe, está inactivo o no tiene permiso para restablecer clientes.' AS Mensaje;
            RETURN;
        END

        DECLARE @ID_Cliente INT;
        SELECT @ID_Cliente = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND Contraseña = @Contraseña
          AND ID_TipoUsuario = 3;

        IF @ID_Cliente IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'No se encontró un cliente con ese correo y contraseña.' AS Mensaje;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Cliente AND Estado = 0
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 0 AS Resultado, 'El cliente ya está activo. No es necesario restablecer.' AS Mensaje;
            RETURN;
        END

        UPDATE Usuario
        SET Estado = 1,
            Fecha_Salida = NULL -- Solo si tienes este campo en tu tabla
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;

        SELECT 1 AS Resultado, 'Cliente restablecido correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        SELECT 0 AS Resultado, @Mensaje AS Mensaje;
    END CATCH
END;



/*EXEC RestablecerCliente
    @ID_UsuarioEjecutor = 1,
    @Email = 'cliente@example.com',
    @Contrasena = 'contraseña123';
	*/




/*--------------------------Recaudacion Anual por Empleados------------------------------*/
GO
CREATE PROCEDURE RecaudacionEmpleados
    (@ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @TipoUsuarioEjecutor INT;
        SELECT @TipoUsuarioEjecutor = ID_TipoUsuario
        FROM Usuario
        WHERE ID_Usuario = @ID_UsuarioEjecutor;

        IF NOT EXISTS (
            SELECT 1
            FROM Permiso
            WHERE ID_TipoUsuario = @TipoUsuarioEjecutor
              AND ID_SubMenu = 28
              AND Estado = 1
        )
        BEGIN
            RAISERROR('Permiso denegado: no puede acceder a la recaudación anual.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT 
            U.Nombre_Usuario,
            TU.Nombre_TipoUsuario AS Tipo_Usuario,
            ISNULL(SUM(DV.Cantidad), 0) AS Total_Productos_Vendidos,
            ISNULL(SUM(V.Importe_Total), 0) AS Total_Recaudado,
            YEAR(V.FechaDeVenta) AS Año
        FROM Usuario U
        INNER JOIN Tipo_de_Usuario TU ON U.ID_TipoUsuario = TU.ID_TipoUsuario
        INNER JOIN Ventas V ON V.ID_Usuario = U.ID_Usuario
        INNER JOIN Detalle_Venta DV ON DV.ID_Venta = V.ID_Venta
        WHERE U.Estado = 1
          AND TU.Nombre_TipoUsuario IN ('Administrador', 'Empleado')
        GROUP BY U.Nombre_Usuario, TU.Nombre_TipoUsuario, YEAR(V.FechaDeVenta)
        ORDER BY Año, Nombre_Usuario;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error: ' + @ErrorMsg;
    END CATCH
END;






--EXEC RecaudacionEmpleados @ID_UsuarioEjecutor = 2;




/*--------------------------Recaudacion anual por cliente----------------------------*/

GO
CREATE PROCEDURE recaudacionDeClientes
   ( @ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @TipoUsuarioEjecutor INT;
        SELECT @TipoUsuarioEjecutor = ID_TipoUsuario
        FROM Usuario
        WHERE ID_Usuario = @ID_UsuarioEjecutor;

        IF NOT EXISTS (
            SELECT 1
            FROM Permiso
            WHERE ID_TipoUsuario = @TipoUsuarioEjecutor AND ID_SubMenu = 27 AND Estado = 1
        )
        BEGIN
            RAISERROR('No tiene permisos para ver la recaudación por cliente.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT 
            u.Nombre_Usuario + ' ' + u.Apellido_Usuario AS Nombre_Usuario,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            SUM(dv.Cantidad) AS Total_Productos_Comprados,
            SUM(dv.Cantidad * dv.Precio_Unitario) AS Total_Recaudado,
            YEAR(v.FechaDeVenta) AS Año
        FROM Ventas v
        INNER JOIN Usuario u ON v.ID_Cliente = u.ID_Usuario
        INNER JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        INNER JOIN Detalle_Venta dv ON v.ID_Venta = dv.ID_Venta
        GROUP BY 
            u.Nombre_Usuario, u.Apellido_Usuario, tu.Nombre_TipoUsuario, YEAR(v.FechaDeVenta)
        ORDER BY 
            Año, Total_Recaudado DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@MensajeError, 16, 1);
    END CATCH
END;




--EXEC recaudacionDeClientes @ID_UsuarioEjecutor = 1;






/*---------------------------Recaudacion Anual---------------------------------*/
GO
CREATE PROCEDURE Mostrar_Recaudacion_Anual
    @ID_Usuario INT,
    @Año INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_Usuario IS NULL OR @ID_Usuario <= 0
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Usuario AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND u.Estado = 1
              AND p.ID_SubMenu = 26
              AND p.Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permisos para ver la recaudación anual.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT 
            DATENAME(MONTH, DATEFROMPARTS(@Año, m.NumeroMes, 1)) AS Mes,
            m.NumeroMes,
            ISNULL(SUM(v.Importe_Total), 0) AS Total_Mensual
        FROM (
            VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)
        ) AS m(NumeroMes)
        LEFT JOIN Ventas v 
            ON MONTH(v.FechaDeVenta) = m.NumeroMes 
           AND YEAR(v.FechaDeVenta) = @Año
        GROUP BY m.NumeroMes
        ORDER BY m.NumeroMes;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @Mensaje NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@Mensaje, 16, 1);
    END CATCH
END;



--EXEC Mostrar_Recaudacion_Anual @ID_Usuario = 1, @Año = 2025;




/*---------------------------------------Producto mas vendido-----------------------------------------------------------*/

GO
CREATE PROCEDURE ProductoMasVendido
    @ID_UsuarioEjecutor INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
        BEGIN
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @TipoUsuarioEjecutor INT;
        SELECT @TipoUsuarioEjecutor = ID_TipoUsuario
        FROM Usuario
        WHERE ID_Usuario = @ID_UsuarioEjecutor;

        IF NOT EXISTS (
            SELECT 1
            FROM Permiso
            WHERE ID_TipoUsuario = @TipoUsuarioEjecutor AND ID_SubMenu = 23 AND Estado = 1
        )
        BEGIN
            RAISERROR('El usuario no tiene permiso para ver el producto más vendido.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        SELECT TOP 1 
            p.Nombre AS Producto,
            SUM(dv.Cantidad) AS Total_Unidades_Vendidas,
            COUNT(DISTINCT dv.ID_Venta) AS Veces_Vendido
        FROM Detalle_Venta dv
        INNER JOIN Productos p ON dv.ID_Producto = p.ID_Producto
        GROUP BY p.Nombre
        ORDER BY SUM(dv.Cantidad) DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@MensajeError, 16, 1);
    END CATCH
END;
GO




--EXEC ProductoMasVendido @ID_UsuarioEjecutor = 1;
