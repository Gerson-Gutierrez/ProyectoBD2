CREATE DATABASE DBProyectoGestionElectronica
COLLATE Latin1_General_CI_AI;
GO

USE DBProyectoGestionElectronica;

GO



CREATE TABLE Categorias (
    ID_Categoria INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL
);
GO

CREATE TABLE Tipo_de_Usuario (
    ID_TipoUsuario INT PRIMARY KEY IDENTITY(1,1),
    Nombre_TipoUsuario NVARCHAR(30) NOT NULL
);
GO

CREATE TABLE Menu (
    ID_Menu INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL
);
GO


CREATE TABLE SubMenu (
    ID_SubMenu INT PRIMARY KEY IDENTITY(1,1),
    ID_Menu INT NOT NULL,
    Nombre NVARCHAR(50) NOT NULL,
    CONSTRAINT FK_SubMenu_Menu FOREIGN KEY (ID_Menu) REFERENCES Menu(ID_Menu) ON DELETE CASCADE
);
GO

CREATE TABLE Productos (
    ID_Producto INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(100) NOT NULL,
    PrecioUnitario DECIMAL(10, 2) NOT NULL CHECK (PrecioUnitario > 0),
    PrecioSinImpuesto DECIMAL(10, 2) NOT NULL CHECK (PrecioSinImpuesto >= 0),
    Stock INT NOT NULL CHECK (Stock >= 0),
    ID_Categoria INT NOT NULL,
    Estado BIT DEFAULT 1 CHECK (Estado IN (0,1)),
    CONSTRAINT FK_Productos_Categorias FOREIGN KEY (ID_Categoria) REFERENCES Categorias(ID_Categoria) ON DELETE CASCADE
);
GO

CREATE TABLE Usuario (
    ID_Usuario INT PRIMARY KEY IDENTITY(1,1),
    ID_TipoUsuario INT NOT NULL,
    Nombre_Usuario NVARCHAR(50) NOT NULL,
    Apellido_Usuario NVARCHAR(50) NOT NULL,
    DNI_Usuario NVARCHAR(20) NOT NULL CHECK (LEN(DNI_Usuario) BETWEEN 7 AND 10),
    Email NVARCHAR(30) NOT NULL,
    Contraseña NVARCHAR(30) COLLATE Latin1_General_CS_AS NOT NULL,
    Telefono NVARCHAR(20) NOT NULL,
    Fecha_Ingreso DATE,
    Fecha_Salida DATE,
    Estado BIT DEFAULT 1 CHECK (Estado IN (0,1)),
    CONSTRAINT FK_Usuario_TipoUsuario FOREIGN KEY (ID_TipoUsuario) REFERENCES Tipo_de_Usuario(ID_TipoUsuario) ON DELETE CASCADE
);
GO

CREATE TABLE Permiso (
    ID_Permiso INT PRIMARY KEY IDENTITY(1,1),
    ID_TipoUsuario INT NOT NULL,
    ID_SubMenu INT NOT NULL,
    Estado BIT CHECK (Estado IN (0,1)),
    CONSTRAINT FK_Permiso_TipoUsuario FOREIGN KEY (ID_TipoUsuario) REFERENCES Tipo_de_Usuario(ID_TipoUsuario) ON DELETE CASCADE,
    CONSTRAINT FK_Permiso_SubMenu FOREIGN KEY (ID_SubMenu) REFERENCES SubMenu(ID_SubMenu) ON DELETE CASCADE
);
GO

CREATE TABLE Ventas (
    ID_Venta INT PRIMARY KEY IDENTITY(1,1),
    ID_Usuario INT NULL,   
    ID_Cliente INT NULL,   
    Importe_Total DECIMAL(12, 2) CHECK (Importe_Total >= 0),
    FechaDeVenta DATE DEFAULT GETDATE(),
    CONSTRAINT FK_Ventas_Usuario FOREIGN KEY (ID_Usuario) REFERENCES Usuario(ID_Usuario),
    CONSTRAINT FK_Ventas_Cliente FOREIGN KEY (ID_Cliente) REFERENCES Usuario(ID_Usuario)
);
GO

CREATE TABLE Detalle_Venta (
    ID_Detalle INT PRIMARY KEY IDENTITY(1,1),
    ID_Venta INT NOT NULL,
    ID_Producto INT NULL,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    Precio_Unitario DECIMAL(10, 2) NOT NULL CHECK (Precio_Unitario >= 0),
    CONSTRAINT FK_DetalleVenta_Venta FOREIGN KEY (ID_Venta) REFERENCES Ventas(ID_Venta) ON DELETE CASCADE,
    CONSTRAINT FK_DetalleVenta_Producto FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto) ON DELETE SET NULL
);
GO
