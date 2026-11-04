/*
    LavaFácil - Proyecto 2 - Script único de entrega
    Ejecutar directamente desde SQL Server Management Studio.

    Contenido:
      1. Estructura, restricciones, datos base, triggers y procedimientos almacenados.
      2. Mejoras del aplicativo.
      3. Treinta registros del Proyecto 2 provenientes de los diez archivos CSV.
      4. Roles y permisos de GraphQL.

    Las contraseñas de los logins SQL no se incluyen. Los logins deben crearse de forma privada.
*/


/* Estructura, datos base, restricciones, triggers y procedimientos */

USE [master]
GO
IF DB_ID(N'LavaFacil') IS NULL EXEC(N'CREATE DATABASE [LavaFacil]');
GO
USE [LavaFacil]
GO
IF EXISTS(SELECT 1 FROM sys.objects WHERE is_ms_shipped=0 AND type IN ('U','P','TR'))
    THROW 50000, 'La base ya contiene objetos. No se debe sobrescribir; usar una instancia de reconstruccion vacia.', 1;
GO

USE [LavaFacil]
GO
/****** Objeto: Table [dbo].[Clientes] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Clientes](
	[IdCliente] [int] IDENTITY(1,1) NOT NULL,
	[Cedula] [varchar](20) NOT NULL,
	[Nombre] [varchar](50) NOT NULL,
	[Apellidos] [varchar](100) NOT NULL,
	[Telefono] [varchar](20) NOT NULL,
	[Email] [varchar](150) NOT NULL,
	[Direccion] [varchar](250) NULL,
	[FechaRegistro] [datetime] NOT NULL,
	[Activo] [bit] NOT NULL,
 CONSTRAINT [PK_Clientes] PRIMARY KEY CLUSTERED 
(
	[IdCliente] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[DetallePedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DetallePedido](
	[IdDetalle] [int] IDENTITY(1,1) NOT NULL,
	[IdPedido] [int] NOT NULL,
	[IdServicio] [int] NOT NULL,
	[Cantidad] [decimal](10, 2) NOT NULL,
	[PrecioBase] [decimal](10, 2) NOT NULL,
	[MontoAdicional] [decimal](10, 2) NOT NULL,
	[Subtotal] [decimal](10, 2) NOT NULL,
 CONSTRAINT [PK_DetallePedido] PRIMARY KEY CLUSTERED 
(
	[IdDetalle] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Empleados] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Empleados](
	[IdEmpleado] [int] IDENTITY(1,1) NOT NULL,
	[Cedula] [varchar](20) NOT NULL,
	[Nombre] [varchar](50) NOT NULL,
	[Apellidos] [varchar](100) NOT NULL,
	[Telefono] [varchar](20) NOT NULL,
	[Email] [varchar](150) NOT NULL,
	[Cargo] [varchar](30) NOT NULL,
	[FechaIngreso] [date] NOT NULL,
	[Activo] [bit] NOT NULL,
 CONSTRAINT [PK_Empleados] PRIMARY KEY CLUSTERED 
(
	[IdEmpleado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Inventario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Inventario](
	[IdInventario] [int] IDENTITY(1,1) NOT NULL,
	[NombreProducto] [varchar](100) NOT NULL,
	[Descripcion] [varchar](250) NULL,
	[Cantidad] [decimal](10, 2) NOT NULL,
	[UnidadMedida] [varchar](20) NOT NULL,
	[CantidadMinima] [decimal](10, 2) NOT NULL,
	[FechaActualizacion] [datetime] NOT NULL,
	[Activo] [bit] NOT NULL,
 CONSTRAINT [PK_Inventario] PRIMARY KEY CLUSTERED 
(
	[IdInventario] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Pagos] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pagos](
	[IdPago] [int] IDENTITY(1,1) NOT NULL,
	[IdPedido] [int] NOT NULL,
	[FechaPago] [datetime] NOT NULL,
	[Monto] [decimal](10, 2) NOT NULL,
	[MetodoPago] [varchar](20) NOT NULL,
	[EstadoPago] [varchar](20) NOT NULL,
	[Referencia] [varchar](100) NULL,
 CONSTRAINT [PK_Pagos] PRIMARY KEY CLUSTERED 
(
	[IdPago] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Pedidos] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pedidos](
	[IdPedido] [int] IDENTITY(1,1) NOT NULL,
	[IdCliente] [int] NOT NULL,
	[FechaPedido] [datetime] NOT NULL,
	[FechaEntregaEstimada] [datetime] NULL,
	[Estado] [varchar](20) NOT NULL,
	[Total] [decimal](10, 2) NOT NULL,
	[Observaciones] [varchar](300) NULL,
 CONSTRAINT [PK_Pedidos] PRIMARY KEY CLUSTERED 
(
	[IdPedido] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Promociones] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Promociones](
	[IdPromocion] [int] IDENTITY(1,1) NOT NULL,
	[IdServicio] [int] NULL,
	[NombrePromocion] [varchar](100) NOT NULL,
	[Descripcion] [varchar](250) NULL,
	[PorcentajeDescuento] [decimal](5, 2) NOT NULL,
	[FechaInicio] [date] NOT NULL,
	[FechaFin] [date] NOT NULL,
	[Activa] [bit] NOT NULL,
 CONSTRAINT [PK_Promociones] PRIMARY KEY CLUSTERED 
(
	[IdPromocion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Recolecciones] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Recolecciones](
	[IdRecoleccion] [int] IDENTITY(1,1) NOT NULL,
	[IdPedido] [int] NOT NULL,
	[Direccion] [varchar](250) NOT NULL,
	[FechaProgramada] [datetime] NOT NULL,
	[Estado] [varchar](20) NOT NULL,
	[Observaciones] [varchar](300) NULL,
 CONSTRAINT [PK_Recolecciones] PRIMARY KEY CLUSTERED 
(
	[IdRecoleccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Servicios] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Servicios](
	[IdServicio] [int] IDENTITY(1,1) NOT NULL,
	[NombreServicio] [varchar](100) NOT NULL,
	[Descripcion] [varchar](250) NULL,
	[TipoCobro] [varchar](20) NOT NULL,
	[PrecioBase] [decimal](10, 2) NOT NULL,
	[CantidadIncluida] [decimal](10, 2) NOT NULL,
	[PrecioAdicional] [decimal](10, 2) NULL,
	[Activo] [bit] NOT NULL,
 CONSTRAINT [PK_Servicios] PRIMARY KEY CLUSTERED 
(
	[IdServicio] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Objeto: Table [dbo].[Usuarios] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Usuarios](
	[IdUsuario] [int] IDENTITY(1,1) NOT NULL,
	[NombreUsuario] [varchar](50) NOT NULL,
	[Clave] [varchar](255) NOT NULL,
	[TipoUsuario] [varchar](20) NOT NULL,
	[IdCliente] [int] NULL,
	[IdEmpleado] [int] NULL,
	[Activo] [bit] NOT NULL,
	[FechaCreacion] [datetime] NOT NULL,
 CONSTRAINT [PK_Usuarios] PRIMARY KEY CLUSTERED 
(
	[IdUsuario] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
SET IDENTITY_INSERT [dbo].[Clientes] ON 

INSERT [dbo].[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (1007, N'DEMO-CLIENTE-1', N'Cliente Demo 1', N'Datos Ficticios', N'00000000', N'cliente.demo.1@example.test', N'Direccion ficticia del proyecto 1', CAST(N'2026-10-11T20:11:00.753' AS DateTime), 1)
INSERT [dbo].[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (1008, N'DEMO-CLIENTE-2', N'Cliente Demo 2', N'Datos Ficticios', N'00000000', N'cliente.demo.2@example.test', N'Direccion ficticia del proyecto 2', CAST(N'2026-10-11T20:11:00.753' AS DateTime), 1)
INSERT [dbo].[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (1009, N'DEMO-CLIENTE-3', N'Cliente Demo 3', N'Datos Ficticios', N'00000000', N'cliente.demo.3@example.test', N'Direccion ficticia del proyecto 3', CAST(N'2026-10-11T20:11:00.753' AS DateTime), 1)
SET IDENTITY_INSERT [dbo].[Clientes] OFF
GO
SET IDENTITY_INSERT [dbo].[DetallePedido] ON 

INSERT [dbo].[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (3, 2, 4, CAST(1.00 AS Decimal(10, 2)), CAST(1500.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), CAST(1500.00 AS Decimal(10, 2)))
INSERT [dbo].[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (4, 3, 5, CAST(1.00 AS Decimal(10, 2)), CAST(2500.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), CAST(2500.00 AS Decimal(10, 2)))
INSERT [dbo].[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (5, 4, 6, CAST(1.00 AS Decimal(10, 2)), CAST(6000.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), CAST(6000.00 AS Decimal(10, 2)))
SET IDENTITY_INSERT [dbo].[DetallePedido] OFF
GO
SET IDENTITY_INSERT [dbo].[Empleados] ON 

INSERT [dbo].[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (6, N'305430020', N'Jose Ramses', N'Aguilar', N'85992849', N'jm0760195@gmail.com', N'Administrador', CAST(N'2026-10-11' AS Date), 1)
INSERT [dbo].[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (1006, N'DEMO-EMPLEADO-1', N'Empleado Demo 1', N'Datos Ficticios', N'00000000', N'empleado.demo.1@example.test', N'Empleado', CAST(N'2026-10-11' AS Date), 1)
INSERT [dbo].[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (1007, N'DEMO-EMPLEADO-2', N'Empleado Demo 2', N'Datos Ficticios', N'00000000', N'empleado.demo.2@example.test', N'Empleado', CAST(N'2026-10-11' AS Date), 1)
SET IDENTITY_INSERT [dbo].[Empleados] OFF
GO
SET IDENTITY_INSERT [dbo].[Inventario] ON 

INSERT [dbo].[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (1, N'Detergente demo', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(10, 2)), N'Litro', CAST(2.00 AS Decimal(10, 2)), CAST(N'2026-10-11T20:11:00.930' AS DateTime), 1)
INSERT [dbo].[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (2, N'Suavizante demo', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(10, 2)), N'Litro', CAST(2.00 AS Decimal(10, 2)), CAST(N'2026-10-11T20:11:00.933' AS DateTime), 1)
INSERT [dbo].[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (3, N'Bolsas demo 3', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(10, 2)), N'Unidad', CAST(2.00 AS Decimal(10, 2)), CAST(N'2026-10-11T20:11:00.933' AS DateTime), 1)
SET IDENTITY_INSERT [dbo].[Inventario] OFF
GO
SET IDENTITY_INSERT [dbo].[Pagos] ON 

INSERT [dbo].[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (3, 2, CAST(N'2026-10-11T20:11:00.923' AS DateTime), CAST(1000.00 AS Decimal(10, 2)), N'Efectivo', N'Pendiente', N'DEMO-ENTREGA-PAGO-1')
INSERT [dbo].[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (4, 3, CAST(N'2026-10-11T20:11:00.930' AS DateTime), CAST(1000.00 AS Decimal(10, 2)), N'Efectivo', N'Pendiente', N'DEMO-ENTREGA-PAGO-2')
INSERT [dbo].[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (5, 4, CAST(N'2026-10-11T20:11:00.930' AS DateTime), CAST(1000.00 AS Decimal(10, 2)), N'Efectivo', N'Pendiente', N'DEMO-ENTREGA-PAGO-3')
SET IDENTITY_INSERT [dbo].[Pagos] OFF
GO
SET IDENTITY_INSERT [dbo].[Pedidos] ON 

INSERT [dbo].[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (2, 1007, CAST(N'2026-10-11T20:11:00.757' AS DateTime), CAST(N'2026-10-15T00:00:00.000' AS DateTime), N'Pendiente', CAST(1500.00 AS Decimal(10, 2)), N'Pedido ficticio para entrega del proyecto')
INSERT [dbo].[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (3, 1008, CAST(N'2026-10-11T20:11:00.760' AS DateTime), CAST(N'2026-10-15T00:00:00.000' AS DateTime), N'Pendiente', CAST(2500.00 AS Decimal(10, 2)), N'Pedido ficticio para entrega del proyecto')
INSERT [dbo].[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (4, 1009, CAST(N'2026-10-11T20:11:00.760' AS DateTime), CAST(N'2026-10-15T00:00:00.000' AS DateTime), N'Pendiente', CAST(6000.00 AS Decimal(10, 2)), N'Pedido ficticio para entrega del proyecto')
SET IDENTITY_INSERT [dbo].[Pedidos] OFF
GO
SET IDENTITY_INSERT [dbo].[Promociones] ON 

INSERT [dbo].[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (1, 4, N'Promocion demo 1', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(5, 2)), CAST(N'2026-10-11' AS Date), CAST(N'2026-10-31' AS Date), 1)
INSERT [dbo].[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (2, 5, N'Promocion demo 2', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(5, 2)), CAST(N'2026-10-11' AS Date), CAST(N'2026-10-31' AS Date), 1)
INSERT [dbo].[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (3, 6, N'Promocion demo 3', N'Datos ficticios del proyecto', CAST(10.00 AS Decimal(5, 2)), CAST(N'2026-10-11' AS Date), CAST(N'2026-10-31' AS Date), 1)
SET IDENTITY_INSERT [dbo].[Promociones] OFF
GO
SET IDENTITY_INSERT [dbo].[Recolecciones] ON 

INSERT [dbo].[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (1, 2, N'Direccion ficticia 1', CAST(N'2026-10-14T00:00:00.000' AS DateTime), N'Programada', N'Recoleccion ficticia para entrega')
INSERT [dbo].[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (2, 3, N'Direccion ficticia 2', CAST(N'2026-10-14T00:00:00.000' AS DateTime), N'Programada', N'Recoleccion ficticia para entrega')
INSERT [dbo].[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (3, 4, N'Direccion ficticia 3', CAST(N'2026-10-14T00:00:00.000' AS DateTime), N'Programada', N'Recoleccion ficticia para entrega')
SET IDENTITY_INSERT [dbo].[Recolecciones] OFF
GO
SET IDENTITY_INSERT [dbo].[Servicios] ON 

INSERT [dbo].[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (4, N'Lavado, secado y doblado', N'Servicio de demostracion del proyecto', N'Kilogramo', CAST(1500.00 AS Decimal(10, 2)), CAST(1.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), 1)
INSERT [dbo].[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (5, N'Uniformes deportivos', N'Servicio de demostracion del proyecto', N'Uniforme', CAST(2500.00 AS Decimal(10, 2)), CAST(1.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), 1)
INSERT [dbo].[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (6, N'Edredones demo 3', N'Servicio de demostracion del proyecto', N'Unidad', CAST(6000.00 AS Decimal(10, 2)), CAST(1.00 AS Decimal(10, 2)), CAST(0.00 AS Decimal(10, 2)), 1)
SET IDENTITY_INSERT [dbo].[Servicios] OFF
GO
SET IDENTITY_INSERT [dbo].[Usuarios] ON 

INSERT [dbo].[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (10, N'ramses.aguilar', N'REEMPLAZAR_CLAVE_40b4dbe788c549ed920924d1e10ea58f', N'Administrador', NULL, 6, 1, CAST(N'2026-10-11T19:42:34.843' AS DateTime))
INSERT [dbo].[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (1010, N'demo.entrega.1', N'REEMPLAZAR_CLAVE_8bb3d063cbcd47b49c31a7c25af250b7', N'Cliente', 1007, NULL, 0, CAST(N'2026-10-11T20:11:00.757' AS DateTime))
INSERT [dbo].[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (1011, N'demo.entrega.2', N'REEMPLAZAR_CLAVE_1aa98cab205d4939a3f649c4ad38bf66', N'Empleado', NULL, 1006, 0, CAST(N'2026-10-11T20:11:00.757' AS DateTime))
SET IDENTITY_INSERT [dbo].[Usuarios] OFF
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Clientes_Cedula] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Clientes] ADD  CONSTRAINT [UQ_Clientes_Cedula] UNIQUE NONCLUSTERED 
(
	[Cedula] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Clientes_Email] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Clientes] ADD  CONSTRAINT [UQ_Clientes_Email] UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Empleados_Cedula] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Empleados] ADD  CONSTRAINT [UQ_Empleados_Cedula] UNIQUE NONCLUSTERED 
(
	[Cedula] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Empleados_Email] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Empleados] ADD  CONSTRAINT [UQ_Empleados_Email] UNIQUE NONCLUSTERED 
(
	[Email] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Inventario_Producto] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Inventario] ADD  CONSTRAINT [UQ_Inventario_Producto] UNIQUE NONCLUSTERED 
(
	[NombreProducto] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Servicios_Nombre] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Servicios] ADD  CONSTRAINT [UQ_Servicios_Nombre] UNIQUE NONCLUSTERED 
(
	[NombreServicio] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Objeto: Index [UQ_Usuarios_NombreUsuario] Fecha de script: 11/10/2026 20:21:15 ******/
ALTER TABLE [dbo].[Usuarios] ADD  CONSTRAINT [UQ_Usuarios_NombreUsuario] UNIQUE NONCLUSTERED 
(
	[NombreUsuario] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Clientes] ADD  CONSTRAINT [DF_Clientes_FechaRegistro]  DEFAULT (getdate()) FOR [FechaRegistro]
GO
ALTER TABLE [dbo].[Clientes] ADD  CONSTRAINT [DF_Clientes_Activo]  DEFAULT ((1)) FOR [Activo]
GO
ALTER TABLE [dbo].[DetallePedido] ADD  CONSTRAINT [DF_DetallePedido_MontoAdicional]  DEFAULT ((0)) FOR [MontoAdicional]
GO
ALTER TABLE [dbo].[Empleados] ADD  CONSTRAINT [DF_Empleados_Activo]  DEFAULT ((1)) FOR [Activo]
GO
ALTER TABLE [dbo].[Inventario] ADD  CONSTRAINT [DF_Inventario_Fecha]  DEFAULT (getdate()) FOR [FechaActualizacion]
GO
ALTER TABLE [dbo].[Inventario] ADD  CONSTRAINT [DF_Inventario_Activo]  DEFAULT ((1)) FOR [Activo]
GO
ALTER TABLE [dbo].[Pagos] ADD  CONSTRAINT [DF_Pagos_FechaPago]  DEFAULT (getdate()) FOR [FechaPago]
GO
ALTER TABLE [dbo].[Pagos] ADD  CONSTRAINT [DF_Pagos_Estado]  DEFAULT ('Pendiente') FOR [EstadoPago]
GO
ALTER TABLE [dbo].[Pedidos] ADD  CONSTRAINT [DF_Pedidos_FechaPedido]  DEFAULT (getdate()) FOR [FechaPedido]
GO
ALTER TABLE [dbo].[Pedidos] ADD  CONSTRAINT [DF_Pedidos_Estado]  DEFAULT ('Pendiente') FOR [Estado]
GO
ALTER TABLE [dbo].[Pedidos] ADD  CONSTRAINT [DF_Pedidos_Total]  DEFAULT ((0)) FOR [Total]
GO
ALTER TABLE [dbo].[Promociones] ADD  CONSTRAINT [DF_Promociones_Activa]  DEFAULT ((1)) FOR [Activa]
GO
ALTER TABLE [dbo].[Recolecciones] ADD  CONSTRAINT [DF_Recolecciones_Estado]  DEFAULT ('Pendiente') FOR [Estado]
GO
ALTER TABLE [dbo].[Servicios] ADD  CONSTRAINT [DF_Servicios_Activo]  DEFAULT ((1)) FOR [Activo]
GO
ALTER TABLE [dbo].[Usuarios] ADD  CONSTRAINT [DF_Usuarios_Activo]  DEFAULT ((1)) FOR [Activo]
GO
ALTER TABLE [dbo].[Usuarios] ADD  CONSTRAINT [DF_Usuarios_FechaCreacion]  DEFAULT (getdate()) FOR [FechaCreacion]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [FK_DetallePedido_Pedidos] FOREIGN KEY([IdPedido])
REFERENCES [dbo].[Pedidos] ([IdPedido])
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [FK_DetallePedido_Pedidos]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [FK_DetallePedido_Servicios] FOREIGN KEY([IdServicio])
REFERENCES [dbo].[Servicios] ([IdServicio])
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [FK_DetallePedido_Servicios]
GO
ALTER TABLE [dbo].[Pagos]  WITH CHECK ADD  CONSTRAINT [FK_Pagos_Pedidos] FOREIGN KEY([IdPedido])
REFERENCES [dbo].[Pedidos] ([IdPedido])
GO
ALTER TABLE [dbo].[Pagos] CHECK CONSTRAINT [FK_Pagos_Pedidos]
GO
ALTER TABLE [dbo].[Pedidos]  WITH CHECK ADD  CONSTRAINT [FK_Pedidos_Clientes] FOREIGN KEY([IdCliente])
REFERENCES [dbo].[Clientes] ([IdCliente])
GO
ALTER TABLE [dbo].[Pedidos] CHECK CONSTRAINT [FK_Pedidos_Clientes]
GO
ALTER TABLE [dbo].[Promociones]  WITH CHECK ADD  CONSTRAINT [FK_Promociones_Servicios] FOREIGN KEY([IdServicio])
REFERENCES [dbo].[Servicios] ([IdServicio])
GO
ALTER TABLE [dbo].[Promociones] CHECK CONSTRAINT [FK_Promociones_Servicios]
GO
ALTER TABLE [dbo].[Recolecciones]  WITH CHECK ADD  CONSTRAINT [FK_Recolecciones_Pedidos] FOREIGN KEY([IdPedido])
REFERENCES [dbo].[Pedidos] ([IdPedido])
GO
ALTER TABLE [dbo].[Recolecciones] CHECK CONSTRAINT [FK_Recolecciones_Pedidos]
GO
ALTER TABLE [dbo].[Usuarios]  WITH CHECK ADD  CONSTRAINT [FK_Usuarios_Clientes] FOREIGN KEY([IdCliente])
REFERENCES [dbo].[Clientes] ([IdCliente])
GO
ALTER TABLE [dbo].[Usuarios] CHECK CONSTRAINT [FK_Usuarios_Clientes]
GO
ALTER TABLE [dbo].[Usuarios]  WITH CHECK ADD  CONSTRAINT [FK_Usuarios_Empleados] FOREIGN KEY([IdEmpleado])
REFERENCES [dbo].[Empleados] ([IdEmpleado])
GO
ALTER TABLE [dbo].[Usuarios] CHECK CONSTRAINT [FK_Usuarios_Empleados]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [CK_DetallePedido_Cantidad] CHECK  (([Cantidad]>(0)))
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [CK_DetallePedido_Cantidad]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [CK_DetallePedido_MontoAdicional] CHECK  (([MontoAdicional]>=(0)))
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [CK_DetallePedido_MontoAdicional]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [CK_DetallePedido_PrecioBase] CHECK  (([PrecioBase]>=(0)))
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [CK_DetallePedido_PrecioBase]
GO
ALTER TABLE [dbo].[DetallePedido]  WITH CHECK ADD  CONSTRAINT [CK_DetallePedido_Subtotal] CHECK  (([Subtotal]>=(0)))
GO
ALTER TABLE [dbo].[DetallePedido] CHECK CONSTRAINT [CK_DetallePedido_Subtotal]
GO
ALTER TABLE [dbo].[Empleados]  WITH CHECK ADD  CONSTRAINT [CK_Empleados_Cargo] CHECK  (([Cargo]='Administrador' OR [Cargo]='Empleado'))
GO
ALTER TABLE [dbo].[Empleados] CHECK CONSTRAINT [CK_Empleados_Cargo]
GO
ALTER TABLE [dbo].[Inventario]  WITH CHECK ADD  CONSTRAINT [CK_Inventario_Cantidad] CHECK  (([Cantidad]>=(0)))
GO
ALTER TABLE [dbo].[Inventario] CHECK CONSTRAINT [CK_Inventario_Cantidad]
GO
ALTER TABLE [dbo].[Inventario]  WITH CHECK ADD  CONSTRAINT [CK_Inventario_CantidadMinima] CHECK  (([CantidadMinima]>=(0)))
GO
ALTER TABLE [dbo].[Inventario] CHECK CONSTRAINT [CK_Inventario_CantidadMinima]
GO
ALTER TABLE [dbo].[Inventario]  WITH CHECK ADD  CONSTRAINT [CK_Inventario_Unidad] CHECK  (([UnidadMedida]='Unidad' OR [UnidadMedida]='Gramo' OR [UnidadMedida]='Kilogramo' OR [UnidadMedida]='Mililitro' OR [UnidadMedida]='Litro'))
GO
ALTER TABLE [dbo].[Inventario] CHECK CONSTRAINT [CK_Inventario_Unidad]
GO
ALTER TABLE [dbo].[Pagos]  WITH CHECK ADD  CONSTRAINT [CK_Pagos_Estado] CHECK  (([EstadoPago]='Anulado' OR [EstadoPago]='Pagado' OR [EstadoPago]='Pendiente'))
GO
ALTER TABLE [dbo].[Pagos] CHECK CONSTRAINT [CK_Pagos_Estado]
GO
ALTER TABLE [dbo].[Pagos]  WITH CHECK ADD  CONSTRAINT [CK_Pagos_Metodo] CHECK  (([MetodoPago]='SINPE Movil' OR [MetodoPago]='Efectivo'))
GO
ALTER TABLE [dbo].[Pagos] CHECK CONSTRAINT [CK_Pagos_Metodo]
GO
ALTER TABLE [dbo].[Pagos]  WITH CHECK ADD  CONSTRAINT [CK_Pagos_Monto] CHECK  (([Monto]>(0)))
GO
ALTER TABLE [dbo].[Pagos] CHECK CONSTRAINT [CK_Pagos_Monto]
GO
ALTER TABLE [dbo].[Pedidos]  WITH CHECK ADD  CONSTRAINT [CK_Pedidos_Estado] CHECK  (([Estado]='Cancelado' OR [Estado]='Entregado' OR [Estado]='Listo' OR [Estado]='En proceso' OR [Estado]='Recibido' OR [Estado]='Pendiente'))
GO
ALTER TABLE [dbo].[Pedidos] CHECK CONSTRAINT [CK_Pedidos_Estado]
GO
ALTER TABLE [dbo].[Pedidos]  WITH CHECK ADD  CONSTRAINT [CK_Pedidos_Total] CHECK  (([Total]>=(0)))
GO
ALTER TABLE [dbo].[Pedidos] CHECK CONSTRAINT [CK_Pedidos_Total]
GO
ALTER TABLE [dbo].[Promociones]  WITH CHECK ADD  CONSTRAINT [CK_Promociones_Descuento] CHECK  (([PorcentajeDescuento]>(0) AND [PorcentajeDescuento]<=(100)))
GO
ALTER TABLE [dbo].[Promociones] CHECK CONSTRAINT [CK_Promociones_Descuento]
GO
ALTER TABLE [dbo].[Promociones]  WITH CHECK ADD  CONSTRAINT [CK_Promociones_Fechas] CHECK  (([FechaFin]>=[FechaInicio]))
GO
ALTER TABLE [dbo].[Promociones] CHECK CONSTRAINT [CK_Promociones_Fechas]
GO
ALTER TABLE [dbo].[Recolecciones]  WITH CHECK ADD  CONSTRAINT [CK_Recolecciones_Estado] CHECK  (([Estado]='Cancelada' OR [Estado]='Recolectada' OR [Estado]='Programada' OR [Estado]='Pendiente'))
GO
ALTER TABLE [dbo].[Recolecciones] CHECK CONSTRAINT [CK_Recolecciones_Estado]
GO
ALTER TABLE [dbo].[Servicios]  WITH CHECK ADD  CONSTRAINT [CK_Servicios_CantidadIncluida] CHECK  (([CantidadIncluida]>(0)))
GO
ALTER TABLE [dbo].[Servicios] CHECK CONSTRAINT [CK_Servicios_CantidadIncluida]
GO
ALTER TABLE [dbo].[Servicios]  WITH CHECK ADD  CONSTRAINT [CK_Servicios_PrecioAdicional] CHECK  (([PrecioAdicional] IS NULL OR [PrecioAdicional]>=(0)))
GO
ALTER TABLE [dbo].[Servicios] CHECK CONSTRAINT [CK_Servicios_PrecioAdicional]
GO
ALTER TABLE [dbo].[Servicios]  WITH CHECK ADD  CONSTRAINT [CK_Servicios_PrecioBase] CHECK  (([PrecioBase]>=(0)))
GO
ALTER TABLE [dbo].[Servicios] CHECK CONSTRAINT [CK_Servicios_PrecioBase]
GO
ALTER TABLE [dbo].[Servicios]  WITH CHECK ADD  CONSTRAINT [CK_Servicios_TipoCobro] CHECK  (([TipoCobro]='Unidad' OR [TipoCobro]='Uniforme' OR [TipoCobro]='Kilogramo'))
GO
ALTER TABLE [dbo].[Servicios] CHECK CONSTRAINT [CK_Servicios_TipoCobro]
GO
ALTER TABLE [dbo].[Usuarios]  WITH CHECK ADD  CONSTRAINT [CK_Usuarios_Referencia] CHECK  (([TipoUsuario]='Cliente' AND [IdCliente] IS NOT NULL AND [IdEmpleado] IS NULL OR ([TipoUsuario]='Administrador' OR [TipoUsuario]='Empleado') AND [IdEmpleado] IS NOT NULL AND [IdCliente] IS NULL))
GO
ALTER TABLE [dbo].[Usuarios] CHECK CONSTRAINT [CK_Usuarios_Referencia]
GO
ALTER TABLE [dbo].[Usuarios]  WITH CHECK ADD  CONSTRAINT [CK_Usuarios_TipoUsuario] CHECK  (([TipoUsuario]='Administrador' OR [TipoUsuario]='Empleado' OR [TipoUsuario]='Cliente'))
GO
ALTER TABLE [dbo].[Usuarios] CHECK CONSTRAINT [CK_Usuarios_TipoUsuario]
GO
/****** Objeto: StoredProcedure [dbo].[ActualizarCliente] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarCliente]
    @IdCliente INT,
    @Cedula VARCHAR(20),
    @Nombre VARCHAR(50),
    @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(150),
    @Direccion VARCHAR(250)
AS
BEGIN

    UPDATE Clientes
    SET
        Cedula = @Cedula,
        Nombre = @Nombre,
        Apellidos = @Apellidos,
        Telefono = @Telefono,
        Email = @Email,
        Direccion = @Direccion
    WHERE IdCliente = @IdCliente;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarDetallePedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarDetallePedido]
    @IdDetalle INT,
    @IdPedido INT,
    @IdServicio INT,
    @Cantidad DECIMAL(10,2),
    @PrecioBase DECIMAL(10,2),
    @MontoAdicional DECIMAL(10,2),
    @Subtotal DECIMAL(10,2)
AS
BEGIN

    UPDATE DetallePedido
    SET
        IdPedido = @IdPedido,
        IdServicio = @IdServicio,
        Cantidad = @Cantidad,
        PrecioBase = @PrecioBase,
        MontoAdicional = @MontoAdicional,
        Subtotal = @Subtotal
    WHERE IdDetalle = @IdDetalle;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarEmpleado] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarEmpleado]
    @IdEmpleado INT,
    @Cedula VARCHAR(20),
    @Nombre VARCHAR(50),
    @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(150),
    @Cargo VARCHAR(30),
    @FechaIngreso DATE
AS
BEGIN

    UPDATE Empleados
    SET
        Cedula = @Cedula,
        Nombre = @Nombre,
        Apellidos = @Apellidos,
        Telefono = @Telefono,
        Email = @Email,
        Cargo = @Cargo,
        FechaIngreso = @FechaIngreso
    WHERE IdEmpleado = @IdEmpleado;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarInventario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarInventario]
    @IdInventario INT,
    @NombreProducto VARCHAR(100),
    @Descripcion VARCHAR(250),
    @Cantidad DECIMAL(10,2),
    @UnidadMedida VARCHAR(20),
    @CantidadMinima DECIMAL(10,2)
AS
BEGIN

    UPDATE Inventario
    SET
        NombreProducto = @NombreProducto,
        Descripcion = @Descripcion,
        Cantidad = @Cantidad,
        UnidadMedida = @UnidadMedida,
        CantidadMinima = @CantidadMinima
    WHERE IdInventario = @IdInventario;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarPago] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarPago]
    @IdPago INT,
    @IdPedido INT,
    @Monto DECIMAL(10,2),
    @MetodoPago VARCHAR(20),
    @EstadoPago VARCHAR(20),
    @Referencia VARCHAR(100)
AS
BEGIN

    UPDATE Pagos
    SET
        IdPedido = @IdPedido,
        Monto = @Monto,
        MetodoPago = @MetodoPago,
        EstadoPago = @EstadoPago,
        Referencia = @Referencia
    WHERE IdPago = @IdPago;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarPedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarPedido]
    @IdPedido INT,
    @IdCliente INT,
    @FechaEntregaEstimada DATETIME,
    @Estado VARCHAR(20),
    @Total DECIMAL(10,2),
    @Observaciones VARCHAR(300)
AS
BEGIN

    UPDATE Pedidos
    SET
        IdCliente = @IdCliente,
        FechaEntregaEstimada = @FechaEntregaEstimada,
        Estado = @Estado,
        Total = @Total,
        Observaciones = @Observaciones
    WHERE IdPedido = @IdPedido;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarPromocion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarPromocion]
    @IdPromocion INT,
    @IdServicio INT,
    @NombrePromocion VARCHAR(100),
    @Descripcion VARCHAR(250),
    @PorcentajeDescuento DECIMAL(5,2),
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN

    UPDATE Promociones
    SET
        IdServicio = @IdServicio,
        NombrePromocion = @NombrePromocion,
        Descripcion = @Descripcion,
        PorcentajeDescuento = @PorcentajeDescuento,
        FechaInicio = @FechaInicio,
        FechaFin = @FechaFin
    WHERE IdPromocion = @IdPromocion;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarRecoleccion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarRecoleccion]
    @IdRecoleccion INT,
    @IdPedido INT,
    @Direccion VARCHAR(250),
    @FechaProgramada DATETIME,
    @Estado VARCHAR(20),
    @Observaciones VARCHAR(300)
AS
BEGIN

    UPDATE Recolecciones
    SET
        IdPedido = @IdPedido,
        Direccion = @Direccion,
        FechaProgramada = @FechaProgramada,
        Estado = @Estado,
        Observaciones = @Observaciones
    WHERE IdRecoleccion = @IdRecoleccion;

END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarServicio] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarServicio]
	@IdServicio INT,
	@NombreServicio VARCHAR(100),
	@Descripcion VARCHAR(250),
    @TipoCobro VARCHAR(20),
    @PrecioBase DECIMAL(10,2),
    @CantidadIncluida DECIMAL(10,2),
    @PrecioAdicional DECIMAL(10,2)

AS
BEGIN
    UPDATE Servicios
    SET 
        NombreServicio = @NombreServicio,
        Descripcion = @Descripcion,
        TipoCobro = @TipoCobro,
        PrecioBase = @PrecioBase,
        CantidadIncluida = @CantidadIncluida,
        PrecioAdicional = @PrecioAdicional
    WHERE IdServicio = @IdServicio;
END;

GO
/****** Objeto: StoredProcedure [dbo].[ActualizarUsuario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ActualizarUsuario]
    @IdUsuario INT,
    @NombreUsuario VARCHAR(50),
    @Clave VARCHAR(255),
    @TipoUsuario VARCHAR(20),
    @IdCliente INT,
    @IdEmpleado INT
AS
BEGIN

    UPDATE Usuarios
    SET
        NombreUsuario = @NombreUsuario,
        Clave = @Clave,
        TipoUsuario = @TipoUsuario,
        IdCliente = @IdCliente,
        IdEmpleado = @IdEmpleado
    WHERE IdUsuario = @IdUsuario;

END;

GO
/****** Objeto: StoredProcedure [dbo].[app_ActualizarPerfil] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_ActualizarPerfil]
    @IdUsuario INT, @Nombre VARCHAR(50), @Apellidos VARCHAR(100), @Telefono VARCHAR(20), @Email VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL
       THROW 50101, 'Completa los datos obligatorios del perfil.', 1;
    DECLARE @IdCliente INT, @IdEmpleado INT;
    SELECT @IdCliente=IdCliente,@IdEmpleado=IdEmpleado FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario;
    IF @IdCliente IS NOT NULL UPDATE dbo.Clientes SET Nombre=@Nombre,Apellidos=@Apellidos,Telefono=@Telefono,Email=@Email WHERE IdCliente=@IdCliente;
    ELSE UPDATE dbo.Empleados SET Nombre=@Nombre,Apellidos=@Apellidos,Telefono=@Telefono,Email=@Email WHERE IdEmpleado=@IdEmpleado;
    EXEC dbo.app_ConsultarPerfil @IdUsuario;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_Autorizar] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Procedimiento de autorización del aplicativo LavaFacil.
-- Valida el estado y los permisos de la cuenta en cada operación.
CREATE   PROCEDURE [dbo].[app_Autorizar]
    @IdUsuario INT, @SoloPersonal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.Usuarios u
        LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
        LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
        WHERE u.IdUsuario=@IdUsuario AND u.Activo=1
          AND ((u.TipoUsuario='Cliente' AND c.Activo=1 AND @SoloPersonal=0)
          OR (u.TipoUsuario IN ('Empleado','Administrador') AND e.Activo=1))
    ) THROW 50100, 'La cuenta está inactiva o no tiene permiso para esta operación.', 1;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_ConsultarClientes] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_ConsultarClientes] @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario, 1;
    SELECT IdCliente, Cedula, Nombre, Apellidos, Telefono, Email, Direccion, FechaRegistro, Activo
    FROM dbo.Clientes ORDER BY FechaRegistro DESC, IdCliente DESC;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_ConsultarPerfil] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_ConsultarPerfil] @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT u.NombreUsuario,u.TipoUsuario,COALESCE(c.Nombre,e.Nombre) AS Nombre,
      COALESCE(c.Apellidos,e.Apellidos) AS Apellidos,COALESCE(c.Cedula,e.Cedula) AS Cedula,
      COALESCE(c.Telefono,e.Telefono) AS Telefono,COALESCE(c.Email,e.Email) AS Email
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
      LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado WHERE u.IdUsuario=@IdUsuario;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_ConsultarServicios] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_ConsultarServicios] @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT IdServicio, NombreServicio, Descripcion, TipoCobro, PrecioBase,
      CantidadIncluida, PrecioAdicional, Activo
    FROM dbo.Servicios WHERE Activo=1 ORDER BY NombreServicio;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_CrearAdministradorInicial] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_CrearAdministradorInicial]
    @Cedula VARCHAR(20),@Nombre VARCHAR(50),@Apellidos VARCHAR(100),@Telefono VARCHAR(20),
    @Email VARCHAR(150),@NombreUsuario VARCHAR(50),@Clave VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@NombreUsuario)),'') IS NULL
       OR DATALENGTH(@Clave)<8
       THROW 50101,'Completa los datos y usa una contraseña de al menos 8 caracteres.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(TABLOCKX,HOLDLOCK))
            THROW 50102,'Ya existen cuentas. La creación inicial ya no está disponible.',1;
        INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso)
        VALUES(@Cedula,@Nombre,@Apellidos,@Telefono,@Email,'Administrador',CONVERT(DATE,GETDATE()));
        DECLARE @IdEmpleado INT=SCOPE_IDENTITY();
        INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdEmpleado)
        VALUES(@NombreUsuario,@Clave,'Administrador',@IdEmpleado);
        DECLARE @IdUsuario INT=SCOPE_IDENTITY();
        COMMIT TRANSACTION;
        SELECT @IdUsuario AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_EstadoInicial] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_EstadoInicial]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CONVERT(BIT,CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuarios) THEN 0 ELSE 1 END) AS RequiereAdministrador;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_RegistrarCliente] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_RegistrarCliente]
    @IdUsuario INT, @Cedula VARCHAR(20), @Nombre VARCHAR(50), @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20), @Email VARCHAR(150), @Direccion VARCHAR(250)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario, 1;
    IF NULLIF(LTRIM(RTRIM(@Cedula)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Nombre)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Apellidos)),'') IS NULL OR NULLIF(LTRIM(RTRIM(@Telefono)),'') IS NULL
       OR NULLIF(LTRIM(RTRIM(@Email)),'') IS NULL
       THROW 50101, 'Completa todos los datos obligatorios del cliente.', 1;
    INSERT dbo.Clientes (Cedula,Nombre,Apellidos,Telefono,Email,Direccion)
    VALUES (@Cedula,@Nombre,@Apellidos,@Telefono,@Email,NULLIF(@Direccion,''));
    SELECT CONVERT(INT,SCOPE_IDENTITY()) AS IdCliente;
END;

GO
/****** Objeto: StoredProcedure [dbo].[app_Resumen] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[app_Resumen] @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT (SELECT COUNT(*) FROM dbo.Servicios WHERE Activo=1) AS ServiciosActivos,
      CASE WHEN EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario IN ('Empleado','Administrador'))
      THEN (SELECT COUNT(*) FROM dbo.Clientes WHERE Activo=1) ELSE NULL END AS ClientesActivos;
END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarClientes] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarClientes]
    @TipoConsulta INT,
    @IdCliente INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Clientes;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Clientes
        WHERE IdCliente = @IdCliente;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarDetallePedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarDetallePedido]
    @TipoConsulta INT,
    @IdDetalle INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM DetallePedido;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM DetallePedido
        WHERE IdDetalle = @IdDetalle;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarEmpleados] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarEmpleados]
    @TipoConsulta INT,
    @IdEmpleado INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Empleados;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Empleados
        WHERE IdEmpleado = @IdEmpleado;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarInventario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarInventario]
    @TipoConsulta INT,
    @IdInventario INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Inventario;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Inventario
        WHERE IdInventario = @IdInventario;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarPagos] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarPagos]
    @TipoConsulta INT,
    @IdPago INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Pagos;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Pagos
        WHERE IdPago = @IdPago;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarPedidos] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarPedidos]
    @TipoConsulta INT,
    @IdPedido INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Pedidos;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Pedidos
        WHERE IdPedido = @IdPedido;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarPromociones] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarPromociones]
    @TipoConsulta INT,
    @IdPromocion INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Promociones;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Promociones
        WHERE IdPromocion = @IdPromocion;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarRecolecciones] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarRecolecciones]
    @TipoConsulta INT,
    @IdRecoleccion INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Recolecciones;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Recolecciones
        WHERE IdRecoleccion = @IdRecoleccion;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarServicios] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarServicios]
	@TipoConsulta INT,
	@IdServicio INT = NULL
AS
BEGIN
	 IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Servicios;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Servicios
        WHERE IdServicio = @IdServicio;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[ConsultarUsuarios] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[ConsultarUsuarios]
    @TipoConsulta INT,
    @IdUsuario INT = NULL
AS
BEGIN

    IF @TipoConsulta = 1
    BEGIN
        SELECT * FROM Usuarios;
    END

    IF @TipoConsulta = 2
    BEGIN
        SELECT * FROM Usuarios
        WHERE IdUsuario = @IdUsuario;
    END

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarCliente] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarCliente]
    @IdCliente INT
AS
BEGIN

    DELETE FROM Clientes
    WHERE IdCliente = @IdCliente;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarDetallePedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarDetallePedido]
    @IdDetalle INT
AS
BEGIN

    DELETE FROM DetallePedido
    WHERE IdDetalle = @IdDetalle;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarEmpleado] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarEmpleado]
    @IdEmpleado INT
AS
BEGIN

    DELETE FROM Empleados
    WHERE IdEmpleado = @IdEmpleado;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarInventario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarInventario]
    @IdInventario INT
AS
BEGIN

    DELETE FROM Inventario
    WHERE IdInventario = @IdInventario;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarPago] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarPago]
    @IdPago INT
AS
BEGIN

    DELETE FROM Pagos
    WHERE IdPago = @IdPago;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarPedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarPedido]
    @IdPedido INT
AS
BEGIN

    DELETE FROM Pedidos
    WHERE IdPedido = @IdPedido;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarPromocion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarPromocion]
    @IdPromocion INT
AS
BEGIN

    DELETE FROM Promociones
    WHERE IdPromocion = @IdPromocion;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarRecoleccion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarRecoleccion]
    @IdRecoleccion INT
AS
BEGIN

    DELETE FROM Recolecciones
    WHERE IdRecoleccion = @IdRecoleccion;

END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarServicio] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarServicio]
	@IdServicio INT
AS
BEGIN
	DELETE FROM Servicios
	WHERE IdServicio = @IdServicio;
END;

GO
/****** Objeto: StoredProcedure [dbo].[EliminarUsuario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EliminarUsuario]
    @IdUsuario INT
AS
BEGIN

    DELETE FROM Usuarios
    WHERE IdUsuario = @IdUsuario;

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarCliente] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarCliente]
    @Cedula VARCHAR(20),
    @Nombre VARCHAR(50),
    @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(150),
    @Direccion VARCHAR(250)
AS
BEGIN

    INSERT INTO Clientes
    (
        Cedula,
        Nombre,
        Apellidos,
        Telefono,
        Email,
        Direccion
    )
    VALUES
    (
        @Cedula,
        @Nombre,
        @Apellidos,
        @Telefono,
        @Email,
        @Direccion
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarDetallePedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarDetallePedido]
    @IdPedido INT,
    @IdServicio INT,
    @Cantidad DECIMAL(10,2),
    @PrecioBase DECIMAL(10,2),
    @MontoAdicional DECIMAL(10,2),
    @Subtotal DECIMAL(10,2)
AS
BEGIN

    INSERT INTO DetallePedido
    (
        IdPedido,
        IdServicio,
        Cantidad,
        PrecioBase,
        MontoAdicional,
        Subtotal
    )
    VALUES
    (
        @IdPedido,
        @IdServicio,
        @Cantidad,
        @PrecioBase,
        @MontoAdicional,
        @Subtotal
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarEmpleado] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarEmpleado]
    @Cedula VARCHAR(20),
    @Nombre VARCHAR(50),
    @Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),
    @Email VARCHAR(150),
    @Cargo VARCHAR(30),
    @FechaIngreso DATE
AS
BEGIN

    INSERT INTO Empleados
    (
        Cedula,
        Nombre,
        Apellidos,
        Telefono,
        Email,
        Cargo,
        FechaIngreso
    )
    VALUES
    (
        @Cedula,
        @Nombre,
        @Apellidos,
        @Telefono,
        @Email,
        @Cargo,
        @FechaIngreso
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarInventario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarInventario]
    @NombreProducto VARCHAR(100),
    @Descripcion VARCHAR(250),
    @Cantidad DECIMAL(10,2),
    @UnidadMedida VARCHAR(20),
    @CantidadMinima DECIMAL(10,2)
AS
BEGIN

    INSERT INTO Inventario
    (
        NombreProducto,
        Descripcion,
        Cantidad,
        UnidadMedida,
        CantidadMinima
    )
    VALUES
    (
        @NombreProducto,
        @Descripcion,
        @Cantidad,
        @UnidadMedida,
        @CantidadMinima
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarPago] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarPago]
    @IdPedido INT,
    @Monto DECIMAL(10,2),
    @MetodoPago VARCHAR(20),
    @EstadoPago VARCHAR(20),
    @Referencia VARCHAR(100)
AS
BEGIN

    INSERT INTO Pagos
    (
        IdPedido,
        Monto,
        MetodoPago,
        EstadoPago,
        Referencia
    )
    VALUES
    (
        @IdPedido,
        @Monto,
        @MetodoPago,
        @EstadoPago,
        @Referencia
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarPedido] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarPedido]
    @IdCliente INT,
    @FechaEntregaEstimada DATETIME,
    @Estado VARCHAR(20),
    @Total DECIMAL(10,2),
    @Observaciones VARCHAR(300)
AS
BEGIN

    INSERT INTO Pedidos
    (
        IdCliente,
        FechaEntregaEstimada,
        Estado,
        Total,
        Observaciones
    )
    VALUES
    (
        @IdCliente,
        @FechaEntregaEstimada,
        @Estado,
        @Total,
        @Observaciones
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarPromocion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarPromocion]
    @IdServicio INT,
    @NombrePromocion VARCHAR(100),
    @Descripcion VARCHAR(250),
    @PorcentajeDescuento DECIMAL(5,2),
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN

    INSERT INTO Promociones
    (
        IdServicio,
        NombrePromocion,
        Descripcion,
        PorcentajeDescuento,
        FechaInicio,
        FechaFin
    )
    VALUES
    (
        @IdServicio,
        @NombrePromocion,
        @Descripcion,
        @PorcentajeDescuento,
        @FechaInicio,
        @FechaFin
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarRecoleccion] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarRecoleccion]
    @IdPedido INT,
    @Direccion VARCHAR(250),
    @FechaProgramada DATETIME,
    @Estado VARCHAR(20),
    @Observaciones VARCHAR(300)
AS
BEGIN

    INSERT INTO Recolecciones
    (
        IdPedido,
        Direccion,
        FechaProgramada,
        Estado,
        Observaciones
    )
    VALUES
    (
        @IdPedido,
        @Direccion,
        @FechaProgramada,
        @Estado,
        @Observaciones
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarServicio] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarServicio]
	@NombreServicio VARCHAR(100),
	@Descripcion VARCHAR(250),
	@TipoCobro VARCHAR(20),
	@PrecioBase DECIMAL(10,2),
	@CantidadIncluida DECIMAL(10,2),
	@PrecioAdicional DECIMAL(10,2)
AS
BEGIN

	INSERT INTO Servicios
	(
	NombreServicio,
	Descripcion,
	TipoCobro,
	PrecioBase,
	CantidadIncluida,
	PrecioAdicional
	)
	Values
	(
	@NombreServicio,
	@Descripcion,
	@TipoCobro,
	@PrecioBase,
	@CantidadIncluida,
	@PrecioAdicional
	);
	END;

GO
/****** Objeto: StoredProcedure [dbo].[InsertarUsuario] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertarUsuario]
    @NombreUsuario VARCHAR(50),
    @Clave VARCHAR(255),
    @TipoUsuario VARCHAR(20),
    @IdCliente INT,
    @IdEmpleado INT
AS
BEGIN

    INSERT INTO Usuarios
    (
        NombreUsuario,
        Clave,
        TipoUsuario,
        IdCliente,
        IdEmpleado
    )
    VALUES
    (
        @NombreUsuario,
        @Clave,
        @TipoUsuario,
        @IdCliente,
        @IdEmpleado
    );

END;

GO
/****** Objeto: StoredProcedure [dbo].[usp_ValidarLogin] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =========================================================
   1. PROCEDIMIENTO DE VALIDACION DE LOGIN
   Devuelve una fila con LoginValido = 1 o 0.
   No devuelve la clave.
   ========================================================= */

CREATE   PROCEDURE [dbo].[usp_ValidarLogin]
    @NombreUsuario VARCHAR(50),
    @Clave VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdUsuario INT;

    SELECT @IdUsuario = u.IdUsuario
    FROM dbo.Usuarios AS u
    LEFT JOIN dbo.Clientes AS c
        ON c.IdCliente = u.IdCliente
    LEFT JOIN dbo.Empleados AS e
        ON e.IdEmpleado = u.IdEmpleado
    WHERE u.NombreUsuario = @NombreUsuario
      AND u.Clave COLLATE Latin1_General_100_BIN2
          = @Clave COLLATE Latin1_General_100_BIN2
      AND DATALENGTH(u.Clave) = DATALENGTH(@Clave)
      AND u.Activo = 1
      AND
      (
          (u.TipoUsuario = 'Cliente' AND c.Activo = 1)
          OR
          (u.TipoUsuario IN ('Empleado', 'Administrador')
           AND e.Activo = 1)
      );

    IF @IdUsuario IS NOT NULL
    BEGIN
        SELECT
            CAST(1 AS BIT) AS LoginValido,
            IdUsuario,
            NombreUsuario,
            TipoUsuario,
            IdCliente,
            IdEmpleado
        FROM dbo.Usuarios
        WHERE IdUsuario = @IdUsuario;
    END
    ELSE
    BEGIN
        SELECT
            CAST(0 AS BIT) AS LoginValido,
            CAST(NULL AS INT) AS IdUsuario,
            CAST(NULL AS VARCHAR(50)) AS NombreUsuario,
            CAST(NULL AS VARCHAR(20)) AS TipoUsuario,
            CAST(NULL AS INT) AS IdCliente,
            CAST(NULL AS INT) AS IdEmpleado;
    END;
END;

GO
/****** Objeto: Trigger [dbo].[trg_DetallePedido_ActualizarTotal] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =========================================================
   2. TRIGGER PARA RECALCULAR EL TOTAL DEL PEDIDO
   Se ejecuta al insertar, actualizar o eliminar detalles.
   También impide reducir el total por debajo de lo pagado.
   ========================================================= */

CREATE   TRIGGER [dbo].[trg_DetallePedido_ActualizarTotal]
ON [dbo].[DetallePedido]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PedidosAfectados TABLE
    (
        IdPedido INT PRIMARY KEY
    );

    INSERT INTO @PedidosAfectados (IdPedido)
    SELECT IdPedido FROM inserted
    UNION
    SELECT IdPedido FROM deleted;

    UPDATE p
    SET Total = COALESCE
    (
        (
            SELECT SUM(d.Subtotal)
            FROM dbo.DetallePedido AS d
            WHERE d.IdPedido = p.IdPedido
        ),
        0
    )
    FROM dbo.Pedidos AS p
    INNER JOIN @PedidosAfectados AS a
        ON a.IdPedido = p.IdPedido;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Pedidos AS p
        INNER JOIN @PedidosAfectados AS a
            ON a.IdPedido = p.IdPedido
        WHERE
        (
            SELECT COALESCE(SUM(pg.Monto), 0)
            FROM dbo.Pagos AS pg
            WHERE pg.IdPedido = p.IdPedido
              AND pg.EstadoPago = 'Pagado'
        ) > p.Total
    )
    BEGIN
        THROW 50001,
            'No se puede reducir el total del pedido por debajo del monto ya pagado.',
            1;
    END;
END;

GO
ALTER TABLE [dbo].[DetallePedido] ENABLE TRIGGER [trg_DetallePedido_ActualizarTotal]
GO
/****** Objeto: Trigger [dbo].[trg_Pagos_ValidarMonto] Fecha de script: 11/10/2026 20:21:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =========================================================
   3. TRIGGER PARA VALIDAR LOS PAGOS
   Permite abonos, pero la suma de pagos confirmados
   no puede superar el total del pedido.
   ========================================================= */

CREATE   TRIGGER [dbo].[trg_Pagos_ValidarMonto]
ON [dbo].[Pagos]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PedidosAfectados TABLE
    (
        IdPedido INT PRIMARY KEY,
        Total DECIMAL(10,2)
    );

    -- Bloquea los pedidos afectados hasta terminar
    -- la transacción para coordinar pagos concurrentes.
    INSERT INTO @PedidosAfectados (IdPedido, Total)
    SELECT p.IdPedido, p.Total
    FROM dbo.Pedidos AS p WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN
    (
        SELECT IdPedido FROM inserted
        UNION
        SELECT IdPedido FROM deleted
    ) AS a
        ON a.IdPedido = p.IdPedido;

    IF EXISTS
    (
        SELECT 1
        FROM @PedidosAfectados AS a
        WHERE
        (
            SELECT COALESCE(SUM(pg.Monto), 0)
            FROM dbo.Pagos AS pg
            WHERE pg.IdPedido = a.IdPedido
              AND pg.EstadoPago = 'Pagado'
        ) > a.Total
    )
    BEGIN
        THROW 50002,
            'Los pagos confirmados no pueden superar el total del pedido.',
            1;
    END;
END;

GO
ALTER TABLE [dbo].[Pagos] ENABLE TRIGGER [trg_Pagos_ValidarMonto]
GO


/* Procedimientos complementarios del aplicativo */

-- Actualización incremental: ejecutar en LavaFacil, en el servidor PRINCIPAL.
-- No restaura bases, no cambia roles de Mirroring y conserva los datos existentes.
USE [LavaFacil];
GO
IF COL_LENGTH('dbo.Usuarios','ClaveHash') IS NULL
    ALTER TABLE dbo.Usuarios ADD ClaveHash VARCHAR(255) NULL;
GO
IF OBJECT_ID('dbo.PerfilesApp','U') IS NULL
BEGIN
    CREATE TABLE dbo.PerfilesApp (
        IdUsuario INT NOT NULL PRIMARY KEY REFERENCES dbo.Usuarios(IdUsuario),
        Avatar VARCHAR(20) NOT NULL DEFAULT 'Iniciales',
        Tema VARCHAR(20) NOT NULL DEFAULT 'Oceano',
        Biografia NVARCHAR(200) NOT NULL DEFAULT N''
    );
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ExigirAdministrador @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Administrador')
        THROW 50100,'Esta operación requiere una cuenta administradora.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_BuscarServicios @IdUsuario INT,@Busqueda VARCHAR(100)='',@IncluirInactivos BIT=0
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @IncluirInactivos=1 EXEC dbo.app_ExigirAdministrador @IdUsuario;
    SELECT * FROM dbo.Servicios
    WHERE (Activo=1 OR @IncluirInactivos=1)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,NombreServicio)>0 OR CHARINDEX(@Busqueda,COALESCE(Descripcion,''))>0)
    ORDER BY NombreServicio;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarServicio
    @IdUsuario INT,@IdServicio INT=NULL,@NombreServicio VARCHAR(100),@Descripcion VARCHAR(250),
    @TipoCobro VARCHAR(20),@PrecioBase DECIMAL(10,2),@CantidadIncluida DECIMAL(10,2),@PrecioAdicional DECIMAL(10,2),@Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    IF NULLIF(TRIM(@NombreServicio),'') IS NULL OR @TipoCobro NOT IN ('Kilogramo','Unidad','Uniforme')
       OR @PrecioBase<0 OR @CantidadIncluida<=0 OR @PrecioAdicional<0
        THROW 50101,'Revisa el nombre, tipo de cobro y los importes del servicio.',1;
    IF @IdServicio IS NULL
    BEGIN
        INSERT dbo.Servicios(NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,PrecioAdicional,Activo)
        VALUES(TRIM(@NombreServicio),@Descripcion,@TipoCobro,@PrecioBase,@CantidadIncluida,@PrecioAdicional,@Activo);
        SET @IdServicio=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.Servicios SET NombreServicio=TRIM(@NombreServicio),Descripcion=@Descripcion,TipoCobro=@TipoCobro,
            PrecioBase=@PrecioBase,CantidadIncluida=@CantidadIncluida,PrecioAdicional=@PrecioAdicional,Activo=@Activo
        WHERE IdServicio=@IdServicio;
        IF @@ROWCOUNT=0 THROW 50104,'El servicio no existe.',1;
    END;
    SELECT @IdServicio AS IdServicio;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearPedido
    @IdUsuario INT,@IdCliente INT=NULL,@Observaciones VARCHAR(300)='',@Lineas NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente')
        SELECT @IdCliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente AND Activo=1)
        THROW 50101,'Selecciona un cliente activo.',1;
    IF ISJSON(@Lineas)<>1 THROW 50101,'El detalle del pedido no es válido.',1;
    DECLARE @Detalle TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2));
    IF EXISTS(SELECT IdServicio FROM OPENJSON(@Lineas) WITH(IdServicio INT '$.serviceId') GROUP BY IdServicio HAVING COUNT(*)>1)
        THROW 50101,'Cada servicio debe aparecer una sola vez; ajusta su cantidad.',1;
    INSERT @Detalle SELECT IdServicio,Cantidad FROM OPENJSON(@Lineas)
        WITH(IdServicio INT '$.serviceId',Cantidad DECIMAL(10,2) '$.quantity');
    IF (SELECT COUNT(*) FROM @Detalle) NOT BETWEEN 1 AND 30 OR EXISTS(SELECT 1 FROM @Detalle WHERE Cantidad IS NULL OR Cantidad<=0 OR Cantidad>10000)
        THROW 50101,'Agrega de 1 a 30 servicios con cantidades positivas (máximo 10000).',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Bloquea las tarifas seleccionadas hasta terminar el registro completo.
        DECLARE @Tarifas TABLE(IdServicio INT PRIMARY KEY,Cantidad DECIMAL(10,2),Base DECIMAL(10,2),Adicional DECIMAL(18,2));
        INSERT @Tarifas
        SELECT d.IdServicio,d.Cantidad,s.PrecioBase,
            CASE WHEN d.Cantidad>s.CantidadIncluida THEN (d.Cantidad-s.CantidadIncluida)*COALESCE(s.PrecioAdicional,0) ELSE 0 END
        FROM @Detalle d JOIN dbo.Servicios s WITH(UPDLOCK,HOLDLOCK) ON s.IdServicio=d.IdServicio AND s.Activo=1;
        IF (SELECT COUNT(*) FROM @Tarifas)<>(SELECT COUNT(*) FROM @Detalle)
            THROW 50101,'Uno de los servicios no existe o está inactivo. Actualiza el catálogo.',1;
        IF EXISTS(SELECT 1 FROM @Detalle d JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio WHERE s.TipoCobro<>'Kilogramo' AND d.Cantidad<>FLOOR(d.Cantidad))
            THROW 50101,'Las unidades y los uniformes requieren cantidades enteras.',1;
        IF (SELECT SUM(Base+Adicional) FROM @Tarifas)>99999999.99
            THROW 50101,'El total supera el máximo permitido.',1;
        INSERT dbo.Pedidos(IdCliente,Estado,Total,Observaciones) VALUES(@IdCliente,'Pendiente',0,@Observaciones);
        DECLARE @IdPedido INT=CONVERT(INT,SCOPE_IDENTITY());
        INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal)
        SELECT @IdPedido,IdServicio,Cantidad,Base,Adicional,Base+Adicional FROM @Tarifas;
        -- El trigger existente mantiene Pedidos.Total para todas las líneas.
        COMMIT;
        SELECT IdPedido,Total,Estado FROM dbo.Pedidos WHERE IdPedido=@IdPedido;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_BuscarPedidos
    @IdUsuario INT,@Desde DATE=NULL,@Hasta DATE=NULL,@Estado VARCHAR(20)='',@Busqueda VARCHAR(100)='',@IdServicio INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @Desde>@Hasta THROW 50101,'La fecha inicial no puede ser posterior a la final.',1;
    DECLARE @Cliente INT=NULL;
    SELECT @Cliente=IdCliente FROM dbo.Usuarios WHERE IdUsuario=@IdUsuario AND TipoUsuario='Cliente';
    SELECT TOP (500) p.IdPedido,p.FechaPedido,p.FechaEntregaEstimada,p.Estado,p.Total,p.Observaciones,
        c.IdCliente,CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,c.Cedula,
        (SELECT COUNT(*) FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido) AS Servicios
    FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    WHERE (@Cliente IS NULL OR p.IdCliente=@Cliente)
      AND (@Desde IS NULL OR CAST(p.FechaPedido AS DATE)>=@Desde)
      AND (@Hasta IS NULL OR CAST(p.FechaPedido AS DATE)<=@Hasta)
      AND (@Estado='' OR p.Estado=@Estado)
      AND (@Busqueda='' OR CHARINDEX(@Busqueda,CONCAT(c.Nombre,' ',c.Apellidos,' ',c.Cedula,' ',p.IdPedido))>0)
      AND (@IdServicio IS NULL OR EXISTS(SELECT 1 FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido AND d.IdServicio=@IdServicio))
    ORDER BY p.FechaPedido DESC,p.IdPedido DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_DetallePedido @IdUsuario INT,@IdPedido INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF NOT EXISTS(SELECT 1 FROM dbo.Pedidos p CROSS JOIN dbo.Usuarios u
        WHERE p.IdPedido=@IdPedido AND u.IdUsuario=@IdUsuario AND (u.TipoUsuario<>'Cliente' OR p.IdCliente=u.IdCliente))
        THROW 50104,'El pedido no existe o no está disponible para tu cuenta.',1;
    SELECT p.IdPedido,p.Estado,p.Total,p.FechaPedido,p.Observaciones,CONCAT(c.Nombre,' ',c.Apellidos) AS Cliente,
        d.IdServicio,s.NombreServicio,s.TipoCobro,d.Cantidad,d.PrecioBase,d.MontoAdicional,d.Subtotal
    FROM dbo.Pedidos p JOIN dbo.Clientes c ON c.IdCliente=p.IdCliente
    JOIN dbo.DetallePedido d ON d.IdPedido=p.IdPedido JOIN dbo.Servicios s ON s.IdServicio=d.IdServicio
    WHERE p.IdPedido=@IdPedido ORDER BY d.IdDetalle;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoPedido @IdUsuario INT,@IdPedido INT,@Estado VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF @Estado NOT IN ('Pendiente','Recibido','En proceso','Listo','Entregado','Cancelado')
        THROW 50101,'Estado de pedido inválido.',1;
    UPDATE dbo.Pedidos SET Estado=@Estado WHERE IdPedido=@IdPedido;
    IF @@ROWCOUNT=0 THROW 50104,'El pedido no existe.',1;
    SELECT @IdPedido AS IdPedido,@Estado AS Estado;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_Preferencias @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    SELECT COALESCE(p.Avatar,'Iniciales') AS Avatar,COALESCE(p.Tema,'Oceano') AS Tema,
        COALESCE(p.Biografia,N'') AS Biografia,c.Direccion
    FROM dbo.Usuarios u LEFT JOIN dbo.PerfilesApp p ON p.IdUsuario=u.IdUsuario
    LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente WHERE u.IdUsuario=@IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarPreferencias
    @IdUsuario INT,@Avatar VARCHAR(20),@Tema VARCHAR(20),@Biografia NVARCHAR(200),@Direccion VARCHAR(250)=''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    IF @Avatar NOT IN ('Iniciales','Burbuja','Gota','Camisa','Flor') OR @Tema NOT IN ('Oceano','Bosque','Violeta')
        THROW 50101,'Selecciona un avatar y tema válidos.',1;
    BEGIN TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.PerfilesApp WITH(UPDLOCK,HOLDLOCK) WHERE IdUsuario=@IdUsuario)
        UPDATE dbo.PerfilesApp SET Avatar=@Avatar,Tema=@Tema,Biografia=@Biografia WHERE IdUsuario=@IdUsuario;
    ELSE INSERT dbo.PerfilesApp(IdUsuario,Avatar,Tema,Biografia) VALUES(@IdUsuario,@Avatar,@Tema,@Biografia);
    UPDATE c SET Direccion=@Direccion FROM dbo.Clientes c JOIN dbo.Usuarios u ON u.IdCliente=c.IdCliente WHERE u.IdUsuario=@IdUsuario;
    COMMIT;
    EXEC dbo.app_Preferencias @IdUsuario;
END;
GO
-- Hash PBKDF2 calculado y verificado por el backend. Nunca se devuelve al navegador.
CREATE OR ALTER PROCEDURE dbo.app_Credencial @NombreUsuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario,u.NombreUsuario,u.TipoUsuario,u.ClaveHash
    FROM dbo.Usuarios u LEFT JOIN dbo.Clientes c ON c.IdCliente=u.IdCliente
    LEFT JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado
    WHERE u.NombreUsuario=@NombreUsuario AND u.Activo=1
      AND ((u.TipoUsuario='Cliente' AND c.Activo=1) OR (u.TipoUsuario IN ('Administrador','Empleado') AND e.Activo=1));
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_GuardarClave @IdUsuario INT,@Hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario;
    UPDATE dbo.Usuarios SET ClaveHash=@Hash,Clave=CONVERT(VARCHAR(255),NEWID()) WHERE IdUsuario=@IdUsuario;
    SELECT @IdUsuario AS IdUsuario;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CrearCuentaCliente @IdUsuario INT,@IdCliente INT,@NombreUsuario VARCHAR(50),@Hash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_ExigirAdministrador @IdUsuario;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WITH(UPDLOCK,HOLDLOCK) WHERE IdCliente=@IdCliente AND Activo=1)
            THROW 50101,'El cliente no existe o está inactivo.',1;
        IF EXISTS(SELECT 1 FROM dbo.Usuarios WITH(UPDLOCK,HOLDLOCK) WHERE IdCliente=@IdCliente)
            THROW 50101,'Este cliente ya tiene una cuenta.',1;
        INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdCliente)
        VALUES(@NombreUsuario,CONVERT(VARCHAR(255),NEWID()),@Hash,'Cliente',@IdCliente);
        DECLARE @Creado INT=CONVERT(INT,SCOPE_IDENTITY());
        COMMIT;
        SELECT @Creado AS IdUsuario;
    END TRY BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_ActualizarCliente
    @IdUsuario INT,@IdCliente INT,@Cedula VARCHAR(20),@Nombre VARCHAR(50),@Apellidos VARCHAR(100),
    @Telefono VARCHAR(20),@Email VARCHAR(150),@Direccion VARCHAR(250)=''
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NULLIF(TRIM(@Cedula),'') IS NULL OR NULLIF(TRIM(@Nombre),'') IS NULL OR NULLIF(TRIM(@Apellidos),'') IS NULL
       OR NULLIF(TRIM(@Telefono),'') IS NULL OR NULLIF(TRIM(@Email),'') IS NULL
        THROW 50101,'Completa los datos obligatorios del cliente.',1;
    UPDATE dbo.Clientes SET Cedula=TRIM(@Cedula),Nombre=TRIM(@Nombre),Apellidos=TRIM(@Apellidos),
        Telefono=TRIM(@Telefono),Email=TRIM(@Email),Direccion=@Direccion
    WHERE IdCliente=@IdCliente;
    IF @@ROWCOUNT=0 THROW 50104,'El cliente no existe.',1;
    SELECT IdCliente,Cedula,Nombre,Apellidos,Telefono,Email,Direccion,FechaRegistro,Activo
    FROM dbo.Clientes WHERE IdCliente=@IdCliente;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_CambiarEstadoCliente @IdUsuario INT,@IdCliente INT,@Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    BEGIN TRANSACTION;
    UPDATE dbo.Clientes SET Activo=@Activo WHERE IdCliente=@IdCliente;
    IF @@ROWCOUNT=0
    BEGIN
        ROLLBACK;
        THROW 50104,'El cliente no existe.',1;
    END;
    -- Una cuenta de cliente no puede quedar activa si su perfil fue desactivado.
    IF @Activo=0 UPDATE dbo.Usuarios SET Activo=0 WHERE IdCliente=@IdCliente;
    COMMIT;
    SELECT @IdCliente AS IdCliente,@Activo AS Activo;
END;
GO
CREATE OR ALTER PROCEDURE dbo.app_EliminarClienteSeguro @IdUsuario INT,@IdCliente INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    EXEC dbo.app_Autorizar @IdUsuario,1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@IdCliente)
        THROW 50104,'El cliente no existe.',1;
    IF EXISTS(SELECT 1 FROM dbo.Pedidos WHERE IdCliente=@IdCliente)
        THROW 50101,'El cliente tiene pedidos relacionados. Desactívalo para conservar su historial.',1;
    IF EXISTS(SELECT 1 FROM dbo.Usuarios WHERE IdCliente=@IdCliente)
        THROW 50101,'El cliente tiene una cuenta de acceso. Desactívalo para conservar su historial.',1;
    DELETE dbo.Clientes WHERE IdCliente=@IdCliente;
    SELECT @IdCliente AS IdCliente;
END;
GO


USE [LavaFacil];
GO


/* Datos provenientes de los diez archivos CSV del Proyecto 2 */

PRINT N'Cargando datos del Proyecto 2 en dbo.Clientes';
SET IDENTITY_INSERT dbo.[Clientes] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Clientes] WHERE [IdCliente] = 2001)
    INSERT dbo.[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (2001, N'DEMO-P2-C001', N'Ana', N'Vargas Mora', N'70000001', N'ana.p2@example.test', N'Turrialba centro', N'2026-10-24 08:00:00', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Clientes] WHERE [IdCliente] = 2002)
    INSERT dbo.[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (2002, N'DEMO-P2-C002', N'Luis', N'Solano Rojas', N'70000002', N'luis.p2@example.test', N'La Suiza Turrialba', N'2026-10-24 08:05:00', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Clientes] WHERE [IdCliente] = 2003)
    INSERT dbo.[Clientes] ([IdCliente], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Direccion], [FechaRegistro], [Activo]) VALUES (2003, N'DEMO-P2-C003', N'María', N'Castro Díaz', N'70000003', N'maria.p2@example.test', N'Santa Cruz Turrialba', N'2026-10-24 08:10:00', 1);
SET IDENTITY_INSERT dbo.[Clientes] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Empleados';
SET IDENTITY_INSERT dbo.[Empleados] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Empleados] WHERE [IdEmpleado] = 2001)
    INSERT dbo.[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (2001, N'DEMO-P2-E001', N'Carlos', N'Jiménez Soto', N'71000001', N'carlos.p2@example.test', N'Empleado', N'2026-10-24', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Empleados] WHERE [IdEmpleado] = 2002)
    INSERT dbo.[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (2002, N'DEMO-P2-E002', N'Sofía', N'Mora López', N'71000002', N'sofia.p2@example.test', N'Empleado', N'2026-10-24', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Empleados] WHERE [IdEmpleado] = 2003)
    INSERT dbo.[Empleados] ([IdEmpleado], [Cedula], [Nombre], [Apellidos], [Telefono], [Email], [Cargo], [FechaIngreso], [Activo]) VALUES (2003, N'DEMO-P2-E003', N'Daniel', N'Rojas Vega', N'71000003', N'daniel.p2@example.test', N'Administrador', N'2026-10-24', 1);
SET IDENTITY_INSERT dbo.[Empleados] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Servicios';
SET IDENTITY_INSERT dbo.[Servicios] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Servicios] WHERE [IdServicio] = 2001)
    INSERT dbo.[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (2001, N'Lavado estándar', N'Lavado y secado de ropa diaria', N'Kilogramo', 1800.00, 1.00, 900.00, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Servicios] WHERE [IdServicio] = 2002)
    INSERT dbo.[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (2002, N'Lavado de edredón', N'Lavado especializado de edredones', N'Unidad', 6500.00, 1.00, 0.00, 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Servicios] WHERE [IdServicio] = 2003)
    INSERT dbo.[Servicios] ([IdServicio], [NombreServicio], [Descripcion], [TipoCobro], [PrecioBase], [CantidadIncluida], [PrecioAdicional], [Activo]) VALUES (2003, N'Lavado de uniformes', N'Tratamiento para uniformes deportivos', N'Uniforme', 3000.00, 1.00, 500.00, 1);
SET IDENTITY_INSERT dbo.[Servicios] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Promociones';
SET IDENTITY_INSERT dbo.[Promociones] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Promociones] WHERE [IdPromocion] = 2001)
    INSERT dbo.[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (2001, 2001, N'Bienvenida', N'Descuento para primera compra', 10.00, N'2026-10-24', N'2026-12-31', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Promociones] WHERE [IdPromocion] = 2002)
    INSERT dbo.[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (2002, 2002, N'Edredón de temporada', N'Promoción de temporada seca', 15.00, N'2026-11-01', N'2027-01-31', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Promociones] WHERE [IdPromocion] = 2003)
    INSERT dbo.[Promociones] ([IdPromocion], [IdServicio], [NombrePromocion], [Descripcion], [PorcentajeDescuento], [FechaInicio], [FechaFin], [Activa]) VALUES (2003, 2003, N'Equipos deportivos', N'Descuento para grupos deportivos', 12.50, N'2026-10-24', N'2026-12-15', 1);
SET IDENTITY_INSERT dbo.[Promociones] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Inventario';
SET IDENTITY_INSERT dbo.[Inventario] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Inventario] WHERE [IdInventario] = 2001)
    INSERT dbo.[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (2001, N'Detergente líquido', N'Detergente concentrado', 25.00, N'Litro', 5.00, N'2026-10-24 10:00:00', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Inventario] WHERE [IdInventario] = 2002)
    INSERT dbo.[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (2002, N'Suavizante', N'Suavizante floral', 18.00, N'Litro', 4.00, N'2026-10-24 10:00:00', 1);
IF NOT EXISTS (SELECT 1 FROM dbo.[Inventario] WHERE [IdInventario] = 2003)
    INSERT dbo.[Inventario] ([IdInventario], [NombreProducto], [Descripcion], [Cantidad], [UnidadMedida], [CantidadMinima], [FechaActualizacion], [Activo]) VALUES (2003, N'Bolsas transparentes', N'Bolsas para entrega', 150.00, N'Unidad', 30.00, N'2026-10-24 10:00:00', 1);
SET IDENTITY_INSERT dbo.[Inventario] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Usuarios';
SET IDENTITY_INSERT dbo.[Usuarios] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Usuarios] WHERE [IdUsuario] = 2001)
    INSERT dbo.[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (2001, N'cliente_p2_01', N'DemoTemporal2026!1', N'Cliente', 2001, NULL, 1, N'2026-10-24 10:10:00');
IF NOT EXISTS (SELECT 1 FROM dbo.[Usuarios] WHERE [IdUsuario] = 2002)
    INSERT dbo.[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (2002, N'empleado_p2_01', N'DemoTemporal2026!2', N'Empleado', NULL, 2001, 1, N'2026-10-24 10:10:00');
IF NOT EXISTS (SELECT 1 FROM dbo.[Usuarios] WHERE [IdUsuario] = 2003)
    INSERT dbo.[Usuarios] ([IdUsuario], [NombreUsuario], [Clave], [TipoUsuario], [IdCliente], [IdEmpleado], [Activo], [FechaCreacion]) VALUES (2003, N'admin_p2_01', N'DemoTemporal2026!3', N'Administrador', NULL, 2003, 1, N'2026-10-24 10:10:00');
SET IDENTITY_INSERT dbo.[Usuarios] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Pedidos';
SET IDENTITY_INSERT dbo.[Pedidos] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Pedidos] WHERE [IdPedido] = 2001)
    INSERT dbo.[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (2001, 2001, N'2026-10-24 09:00:00', N'2026-10-26 15:00:00', N'Pendiente', 3600.00, N'Carga BCP Proyecto 2');
IF NOT EXISTS (SELECT 1 FROM dbo.[Pedidos] WHERE [IdPedido] = 2002)
    INSERT dbo.[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (2002, 2002, N'2026-10-24 09:15:00', N'2026-10-27 16:00:00', N'Recibido', 6500.00, N'Carga BCP Proyecto 2');
IF NOT EXISTS (SELECT 1 FROM dbo.[Pedidos] WHERE [IdPedido] = 2003)
    INSERT dbo.[Pedidos] ([IdPedido], [IdCliente], [FechaPedido], [FechaEntregaEstimada], [Estado], [Total], [Observaciones]) VALUES (2003, 2003, N'2026-10-24 09:30:00', N'2026-10-28 14:00:00', N'En proceso', 6000.00, N'Carga BCP Proyecto 2');
SET IDENTITY_INSERT dbo.[Pedidos] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Recolecciones';
SET IDENTITY_INSERT dbo.[Recolecciones] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Recolecciones] WHERE [IdRecoleccion] = 2001)
    INSERT dbo.[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (2001, 2001, N'Turrialba centro', N'2026-10-24 11:00:00', N'Programada', N'Dato de prueba Proyecto 2');
IF NOT EXISTS (SELECT 1 FROM dbo.[Recolecciones] WHERE [IdRecoleccion] = 2002)
    INSERT dbo.[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (2002, 2002, N'La Suiza Turrialba', N'2026-10-24 11:30:00', N'Recolectada', N'Dato de prueba Proyecto 2');
IF NOT EXISTS (SELECT 1 FROM dbo.[Recolecciones] WHERE [IdRecoleccion] = 2003)
    INSERT dbo.[Recolecciones] ([IdRecoleccion], [IdPedido], [Direccion], [FechaProgramada], [Estado], [Observaciones]) VALUES (2003, 2003, N'Santa Cruz Turrialba', N'2026-10-24 12:00:00', N'Cancelada', N'Dato de prueba Proyecto 2');
SET IDENTITY_INSERT dbo.[Recolecciones] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.DetallePedido';
SET IDENTITY_INSERT dbo.[DetallePedido] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[DetallePedido] WHERE [IdDetalle] = 2001)
    INSERT dbo.[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (2001, 2001, 2001, 2.00, 1800.00, 0.00, 3600.00);
IF NOT EXISTS (SELECT 1 FROM dbo.[DetallePedido] WHERE [IdDetalle] = 2002)
    INSERT dbo.[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (2002, 2002, 2002, 1.00, 6500.00, 0.00, 6500.00);
IF NOT EXISTS (SELECT 1 FROM dbo.[DetallePedido] WHERE [IdDetalle] = 2003)
    INSERT dbo.[DetallePedido] ([IdDetalle], [IdPedido], [IdServicio], [Cantidad], [PrecioBase], [MontoAdicional], [Subtotal]) VALUES (2003, 2003, 2003, 2.00, 3000.00, 0.00, 6000.00);
SET IDENTITY_INSERT dbo.[DetallePedido] OFF;
GO

PRINT N'Cargando datos del Proyecto 2 en dbo.Pagos';
SET IDENTITY_INSERT dbo.[Pagos] ON;
IF NOT EXISTS (SELECT 1 FROM dbo.[Pagos] WHERE [IdPago] = 2001)
    INSERT dbo.[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (2001, 2001, N'2026-10-24 09:05:00', 3600.00, N'Efectivo', N'Pagado', N'P2-BCP-001');
IF NOT EXISTS (SELECT 1 FROM dbo.[Pagos] WHERE [IdPago] = 2002)
    INSERT dbo.[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (2002, 2002, N'2026-10-24 09:20:00', 6500.00, N'SINPE Movil', N'Pagado', N'P2-BCP-002');
IF NOT EXISTS (SELECT 1 FROM dbo.[Pagos] WHERE [IdPago] = 2003)
    INSERT dbo.[Pagos] ([IdPago], [IdPedido], [FechaPago], [Monto], [MetodoPago], [EstadoPago], [Referencia]) VALUES (2003, 2003, N'2026-10-24 09:35:00', 3000.00, N'Efectivo', N'Pendiente', N'P2-BCP-003');
SET IDENTITY_INSERT dbo.[Pagos] OFF;
GO


/* Roles y permisos de GraphQL */

USE [LavaFacil];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_invitado') CREATE ROLE [gql_invitado];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_cliente') CREATE ROLE [gql_cliente];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gql_empleado') CREATE ROLE [gql_empleado];
GO

-- Los LOGIN se crean en master con contraseñas privadas. Este bloque solamente crea
-- los USER y los incorpora a su rol cuando el login ya existe en la instancia.
IF SUSER_ID(N'lava_gql_invitado') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_invitado') IS NULL CREATE USER [lava_gql_invitado] FOR LOGIN [lava_gql_invitado];
    IF IS_ROLEMEMBER(N'gql_invitado', N'lava_gql_invitado') <> 1 ALTER ROLE [gql_invitado] ADD MEMBER [lava_gql_invitado];
END;
IF SUSER_ID(N'lava_gql_cliente') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_cliente') IS NULL CREATE USER [lava_gql_cliente] FOR LOGIN [lava_gql_cliente];
    IF IS_ROLEMEMBER(N'gql_cliente', N'lava_gql_cliente') <> 1 ALTER ROLE [gql_cliente] ADD MEMBER [lava_gql_cliente];
END;
IF SUSER_ID(N'lava_gql_empleado') IS NOT NULL
BEGIN
    IF USER_ID(N'lava_gql_empleado') IS NULL CREATE USER [lava_gql_empleado] FOR LOGIN [lava_gql_empleado];
    IF IS_ROLEMEMBER(N'gql_empleado', N'lava_gql_empleado') <> 1 ALTER ROLE [gql_empleado] ADD MEMBER [lava_gql_empleado];
END;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_ValidarLogin TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarServicios TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarPromociones TO [gql_invitado];
GRANT EXECUTE ON OBJECT::dbo.ConsultarServicios TO [gql_cliente];
GRANT EXECUTE ON OBJECT::dbo.ConsultarPromociones TO [gql_cliente];
GO

-- El rol de empleados puede ejecutar los CRUD, pero no recibe permisos directos
-- sobre las tablas. Toda operación queda obligada a pasar por un procedimiento.
DECLARE @sql nvarchar(max) = N'';
SELECT @sql += N'GRANT EXECUTE ON OBJECT::' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N' TO [gql_empleado];' + CHAR(13)
FROM sys.procedures
WHERE name LIKE N'Insertar%' OR name LIKE N'Actualizar%' OR name LIKE N'Eliminar%' OR name LIKE N'Consultar%' OR name = N'usp_ValidarLogin';
EXEC sys.sp_executesql @sql;
GO

SELECT r.name AS Rol, m.name AS Miembro
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = drm.member_principal_id
WHERE r.name LIKE N'gql_%'
ORDER BY r.name, m.name;
GO


/* Verificación final */

USE [LavaFacil];
GO

SELECT t.name AS Tabla, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
WHERE t.name IN (N'Clientes',N'Empleados',N'Usuarios',N'Servicios',N'Pedidos',N'DetallePedido',N'Pagos',N'Recolecciones',N'Promociones',N'Inventario')
GROUP BY t.name
ORDER BY t.name;

SELECT name AS Procedimiento
FROM sys.procedures
WHERE name LIKE N'Insertar%' OR name LIKE N'Actualizar%' OR name LIKE N'Eliminar%' OR name LIKE N'Consultar%' OR name=N'usp_ValidarLogin'
ORDER BY name;

SELECT name AS TriggerNombre, OBJECT_NAME(parent_id) AS Tabla
FROM sys.triggers
WHERE parent_class_desc=N'OBJECT_OR_COLUMN'
ORDER BY Tabla, TriggerNombre;
GO


PRINT N'Proyecto 2 instalado y verificado.';
GO
