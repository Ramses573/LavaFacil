-- Script de reconstrucción de LavaFacil generado desde SSMS el 11/10/2026.
-- Incluye esquema, datos, 50 procedimientos almacenados y 2 triggers.
-- Las contraseñas de dbo.Usuarios se sustituyeron por valores de reemplazo en esta copia.
-- Las contraseñas de la base de origen no fueron modificadas.
-- Los valores de reemplazo corresponden a cuentas del aplicativo, no a logins de SQL Server.
-- Después de reconstruir la base, establecer las contraseñas de las cuentas antes de iniciar sesión.
-- Ejecutar en SSMS con Consulta > Modo SQLCMD, únicamente para una reconstrucción en una base vacía.
-- No ejecutar sobre la base de trabajo existente ni sobre el espejo de Mirroring.
:ON ERROR EXIT
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
