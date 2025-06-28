USE DBProyectoGestionElectronica;

GO


/*------------------------------------Vistas de menu con subMenu------------------------------------------------------*/

CREATE VIEW VW_Menu_SubMenu AS
SELECT 
    M.Nombre AS Nombre_Menu,
    SM.ID_SubMenu,
    SM.Nombre AS Nombre_SubMenu
FROM 
    Menu M
INNER JOIN 
    SubMenu SM ON M.ID_Menu = SM.ID_Menu;




/*--------------------------Vistas para todos los empleados--------------------------------*/

GO

CREATE VIEW VW_UsuariosEmpleados AS
SELECT 
    u.ID_Usuario,
    u.Nombre_Usuario,
    u.Apellido_Usuario,
    u.Email,
    u.Contraseña,
    tu.Nombre_TipoUsuario AS Tipo_Usuario,
    Estado = CASE u.Estado 
                WHEN 1 THEN 'Activo' 
                WHEN 0 THEN 'Inactivo' 
             END
FROM Usuario u
JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
WHERE u.ID_TipoUsuario IN (1, 2);  -- 1 = Administrador, 2 = Empleado



GO


/*--------------------------Vista para todos los usuarios----------------------------------------------------------------*/

CREATE VIEW VW_TodosLosUsuarios AS
SELECT
    u.ID_Usuario,
    u.Nombre_Usuario AS Nombre,
    u.Apellido_Usuario AS Apellido,
    u.DNI_Usuario AS DNI,
    u.Email,
    u.Contraseña,
    u.Telefono,
    tu.Nombre_TipoUsuario AS Tipo_Usuario,
    Estado = CASE u.Estado 
                WHEN 1 THEN 'Activo'
                WHEN 0 THEN 'Inactivo'
             END
FROM Usuario u
JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario;


