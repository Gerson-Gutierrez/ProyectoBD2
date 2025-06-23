USE DBGestionComercial;


INSERT INTO Categorias (Nombre)
VALUES 
('Procesadores'),
('Placas Madre'),
('Memorias RAM'),
('Discos SSD'),
('Fuentes de Poder');



-- Procesadores
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES 
('Intel Core i7-12700K', 'Procesador Intel de 12va generación, 12 núcleos, socket LGA1700.', 350.00, 289.26, 10, 1),
('AMD Ryzen 7 5800X', 'Procesador AMD de 8 núcleos, socket AM4, rendimiento alto.', 320.00, 264.46, 8, 1);

-- Placas Madre
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES 
('ASUS ROG STRIX B550-F', 'Placa madre para AMD Ryzen, soporte DDR4, PCIe 4.0.', 180.00, 148.76, 5, 2),
('MSI MAG Z690 TOMAHAWK', 'Placa madre Intel Z690, DDR5, soporte para 12va gen Intel.', 250.00, 206.61, 7, 2);

-- Memorias RAM
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES 
('Corsair Vengeance LPX 16GB (2x8GB) DDR4-3200', 'Kit de memoria RAM de alto rendimiento.', 90.00, 74.38, 15, 3),
('Kingston Fury Beast 32GB DDR5-5600', 'Módulo de RAM DDR5 de última generación.', 160.00, 132.23, 12, 3);

--Discos SSD
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES 
('SSD Kingston A400 240GB', 'Disco SSD SATA III de 2.5", velocidad hasta 500MB/s', 18000, 14876.03, 25, 4),
('SSD Crucial MX500 500GB', 'SSD con tecnología NAND 3D, interfaz SATA 2.5"', 32000, 26446.28, 18, 4),
('SSD Samsung 970 EVO 1TB', 'Disco NVMe M.2 ultra rápido', 58000, 47933.88, 10, 4);


--Fuentes de poder
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES 
('Fuente EVGA 600W 80 Plus', 'Fuente de poder certificada para PC de escritorio', 25000, 20661.98, 20, 5),
('Fuente Corsair RM750x', 'Fuente modular, 80 Plus Gold', 52000, 42975.20, 12, 5),
('Fuente Thermaltake Smart 500W', 'Fuente con ventilador silencioso de 120mm', 21000, 17355.37, 15, 5);






INSERT INTO Tipo_de_Usuario (Nombre_TipoUsuario)
VALUES 
    ('Administrador'),
    ('Empleado'),
    ('Cliente');
	

INSERT INTO Usuario (
    ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario, DNI_Usuario,
    Email, Contraseña, Telefono, Fecha_Ingreso, Fecha_Salida
) VALUES 
-- Administradores
(1, 'Carlos', 'Fernández', '30111222', 'carlos.admin@empresa.com', 'Admin1234', '1155667788', '2024-01-10', NULL),
(1, 'Lucía', 'González', '30222333', 'lucia.admin@empresa.com', 'LuciaPass1', '1166778899', '2024-02-15', NULL),

-- Empleados
(2, 'Matías', 'Pérez', '30333444', 'matias.emp@empresa.com', 'EmpMatias2024', '1177889900', '2024-03-05', NULL),
(2, 'Sofía', 'Ramírez', '30444555', 'sofia.emp@empresa.com', 'Sofi2024Emp', '1188990011', '2024-04-01', NULL),

-- Clientes
(3, 'Juan', 'López', '30555666', 'juan.cliente@mail.com', 'JuanCliente', '1199001122', '2025-06-01', NULL),
(3, 'Mariana', 'Torres', '30666777', 'mariana.cliente@mail.com', 'Mari1234', '1100112233', '2025-06-01', NULL);




/*--------------------------Menu---------------------------------------*/

INSERT INTO Menu(Nombre)
VALUES ('Ventas'),
      ('Articulos'), 
	  ('Empleados'),
	  ('Clientes'),
	  ('Informes');


/*-----------------------SubMenuVentas--------------------------------------*/

INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES(1,'Generar Nueva venta'),
       (1,'Listar Venta'),
	   (1,'Buscar Venta')


/*-----------------------SubMenuProductos--------------------------------------*/

INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (2,'Agregar Productos'),
       (2,'Listar Productos'),
	   (2,'Listar por Categoria con ID categoria'),
	   (2,'Modifcar Precio'),
	   (2,'Actualizar Stock'),
	   (2,'Agregar Categoria'),
	   (2,'Eliminar Producto'),
	   (2,'Restablecer Producto');



/*------------------------SubMenuEmpleados---------------------------------------*/
INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (3,'Agregar Administrador'),
       (3,'Agregar Empleado'),
       (3,'Listar Empleado y administrador'),
	   (3,'Buscar Empleado o administrador por ID'),
	   (3,'Modificar Empleado o administrador'),
	   (3,'Eliminar Empleado o administrador'),
	   (3,'Restablecer Administrador'),
       (3,'Restablecer Empleado');
	 



/*------------------------SubMenuClientes---------------------------------------*/
INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES 
      (4,'Agregar Cliente'),
      (4,'Listar Cliente'),
	  (4,'Buscar Cliente por ID'),
	  (4,'Modificar Cliente'),
	  (4,'Eliminar Cliente'),
	  (4,'Restablecer Cliente');
	


/*----------------------SubMenuInformes-----------------------------------------*/


INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES(5,'Recaudacion Anual'),
      (5,'Recaudacion por Cliente'),
	  (5,'Recaudacion por Empleado'),
	  (5,'Producto mas Vendido');


/*-----------------------Permisos Administrador---------------------------------------------*/


INSERT INTO Permiso (ID_TipoUsuario,ID_SubMenu,Estado)
VALUES (1,1,1),
       (1,2,1),
	   (1,3,1),
	   (1,4,1),
	   (1,5,1),
	   (1,6,1),
	   (1,7,1),
	   (1,8,1),
	   (1,9,1),
	   (1,10,1),
	   (1,11,1),
       (1,12,1),
	   (1,13,1),
	   (1,14,1),
	   (1,15,1),
	   (1,16,1),
	   (1,17,1),
	   (1,18,1),
	   (1,19,1),
	   (1,20,1),
	   (1,21,1),
       (1,22,1),
	   (1,23,1),
	   (1,24,1),
	   (1,25,1),
	   (1,26,1),
       (1,27,1),
	   (1,28,1),
	   (1,29,1);
       
       



/*-----------------------Permisos Empleados---------------------------------------------*/

INSERT INTO Permiso (ID_TipoUsuario,ID_SubMenu,Estado)
VALUES (2,1,1),
       (2,2,1),
	   (2,3,1),
	   (2,4,1),
	   (2,5,1),
	   (2,6,1),
	   (2,7,1),
	   (2,8,1),
	   (2,9,1),
	   (2,10,1),
	   (2,11,1),
       (2,12,0),
	   (2,13,0),
	   (2,14,0),
	   (2,15,0),
	   (2,16,0),
	   (2,17,0),
	   (2,18,0),
	   (2,19,0),
	   (2,20,1),
	   (2,21,1),
       (2,22,1),
	   (2,23,1),
       (2,24,1),
	   (2,25,1),
	   (2,26,0),
	   (2,27,0),
       (2,28,0),
       (2,29,0);

	




