/* ============================================================
   BASE DE DATOS: LavaFacil
   PROYECTO BASES DE DATOS AVANZADAS
   ============================================================ */

CREATE DATABASE LavaFacil;
GO

USE LavaFacil;
GO


/* ============================================================
   1. TABLA CLIENTES
   ============================================================ */

CREATE TABLE Clientes
(
    IdCliente INT IDENTITY(1,1) NOT NULL,
    Cedula VARCHAR(20) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NOT NULL,
    Email VARCHAR(150) NOT NULL,
    Direccion VARCHAR(250) NULL,
    FechaRegistro DATETIME NOT NULL
        CONSTRAINT DF_Clientes_FechaRegistro
        DEFAULT GETDATE(),
    Activo BIT NOT NULL
        CONSTRAINT DF_Clientes_Activo
        DEFAULT 1,

    CONSTRAINT PK_Clientes
        PRIMARY KEY (IdCliente),

    CONSTRAINT UQ_Clientes_Cedula
        UNIQUE (Cedula),

    CONSTRAINT UQ_Clientes_Email
        UNIQUE (Email)
);
GO


/* ============================================================
   2. TABLA EMPLEADOS
   ============================================================ */

CREATE TABLE Empleados
(
    IdEmpleado INT IDENTITY(1,1) NOT NULL,
    Cedula VARCHAR(20) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NOT NULL,
    Email VARCHAR(150) NOT NULL,
    Cargo VARCHAR(30) NOT NULL,
    FechaIngreso DATE NOT NULL,
    Activo BIT NOT NULL
        CONSTRAINT DF_Empleados_Activo
        DEFAULT 1,

    CONSTRAINT PK_Empleados
        PRIMARY KEY (IdEmpleado),

    CONSTRAINT UQ_Empleados_Cedula
        UNIQUE (Cedula),

    CONSTRAINT UQ_Empleados_Email
        UNIQUE (Email),

    CONSTRAINT CK_Empleados_Cargo
        CHECK
        (
            Cargo IN
            (
                'Empleado',
                'Administrador'
            )
        )
);
GO


/* ============================================================
   3. TABLA USUARIOS
   ============================================================ */

CREATE TABLE Usuarios
(
    IdUsuario INT IDENTITY(1,1) NOT NULL,
    NombreUsuario VARCHAR(50) NOT NULL,
    Clave VARCHAR(255) NOT NULL,
    TipoUsuario VARCHAR(20) NOT NULL,

    IdCliente INT NULL,
    IdEmpleado INT NULL,

    Activo BIT NOT NULL
        CONSTRAINT DF_Usuarios_Activo
        DEFAULT 1,

    FechaCreacion DATETIME NOT NULL
        CONSTRAINT DF_Usuarios_FechaCreacion
        DEFAULT GETDATE(),

    CONSTRAINT PK_Usuarios
        PRIMARY KEY (IdUsuario),

    CONSTRAINT UQ_Usuarios_NombreUsuario
        UNIQUE (NombreUsuario),

    CONSTRAINT FK_Usuarios_Clientes
        FOREIGN KEY (IdCliente)
        REFERENCES Clientes(IdCliente),

    CONSTRAINT FK_Usuarios_Empleados
        FOREIGN KEY (IdEmpleado)
        REFERENCES Empleados(IdEmpleado),

    CONSTRAINT CK_Usuarios_TipoUsuario
        CHECK
        (
            TipoUsuario IN
            (
                'Cliente',
                'Empleado',
                'Administrador'
            )
        ),

    CONSTRAINT CK_Usuarios_Referencia
        CHECK
        (
            (
                TipoUsuario = 'Cliente'
                AND IdCliente IS NOT NULL
                AND IdEmpleado IS NULL
            )
            OR
            (
                TipoUsuario IN ('Empleado','Administrador')
                AND IdEmpleado IS NOT NULL
                AND IdCliente IS NULL
            )
        )
);
GO


/* ============================================================
   4. TABLA SERVICIOS
   ============================================================ */

CREATE TABLE Servicios
(
    IdServicio INT IDENTITY(1,1) NOT NULL,
    NombreServicio VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(250) NULL,

    TipoCobro VARCHAR(20) NOT NULL,

    PrecioBase DECIMAL(10,2) NOT NULL,
    CantidadIncluida DECIMAL(10,2) NOT NULL,
    PrecioAdicional DECIMAL(10,2) NULL,

    Activo BIT NOT NULL
        CONSTRAINT DF_Servicios_Activo
        DEFAULT 1,

    CONSTRAINT PK_Servicios
        PRIMARY KEY (IdServicio),

    CONSTRAINT UQ_Servicios_Nombre
        UNIQUE (NombreServicio),

    CONSTRAINT CK_Servicios_TipoCobro
        CHECK
        (
            TipoCobro IN
            (
                'Kilogramo',
                'Uniforme',
                'Unidad'
            )
        ),

    CONSTRAINT CK_Servicios_PrecioBase
        CHECK (PrecioBase >= 0),

    CONSTRAINT CK_Servicios_CantidadIncluida
        CHECK (CantidadIncluida > 0),

    CONSTRAINT CK_Servicios_PrecioAdicional
        CHECK
        (
            PrecioAdicional IS NULL
            OR PrecioAdicional >= 0
        )
);
GO


/* ============================================================
   5. TABLA PEDIDOS
   ============================================================ */

CREATE TABLE Pedidos
(
    IdPedido INT IDENTITY(1,1) NOT NULL,
    IdCliente INT NOT NULL,

    FechaPedido DATETIME NOT NULL
        CONSTRAINT DF_Pedidos_FechaPedido
        DEFAULT GETDATE(),

    FechaEntregaEstimada DATETIME NULL,

    Estado VARCHAR(20) NOT NULL
        CONSTRAINT DF_Pedidos_Estado
        DEFAULT 'Pendiente',

    Total DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Pedidos_Total
        DEFAULT 0,

    Observaciones VARCHAR(300) NULL,

    CONSTRAINT PK_Pedidos
        PRIMARY KEY (IdPedido),

    CONSTRAINT FK_Pedidos_Clientes
        FOREIGN KEY (IdCliente)
        REFERENCES Clientes(IdCliente),

    CONSTRAINT CK_Pedidos_Estado
        CHECK
        (
            Estado IN
            (
                'Pendiente',
                'Recibido',
                'En proceso',
                'Listo',
                'Entregado',
                'Cancelado'
            )
        ),

    CONSTRAINT CK_Pedidos_Total
        CHECK (Total >= 0)
);
GO


/* ============================================================
   6. TABLA DETALLE PEDIDO
   ============================================================ */

CREATE TABLE DetallePedido
(
    IdDetalle INT IDENTITY(1,1) NOT NULL,
    IdPedido INT NOT NULL,
    IdServicio INT NOT NULL,

    Cantidad DECIMAL(10,2) NOT NULL,
    PrecioBase DECIMAL(10,2) NOT NULL,
    MontoAdicional DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_DetallePedido_MontoAdicional
        DEFAULT 0,

    Subtotal DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_DetallePedido
        PRIMARY KEY (IdDetalle),

    CONSTRAINT FK_DetallePedido_Pedidos
        FOREIGN KEY (IdPedido)
        REFERENCES Pedidos(IdPedido),

    CONSTRAINT FK_DetallePedido_Servicios
        FOREIGN KEY (IdServicio)
        REFERENCES Servicios(IdServicio),

    CONSTRAINT CK_DetallePedido_Cantidad
        CHECK (Cantidad > 0),

    CONSTRAINT CK_DetallePedido_PrecioBase
        CHECK (PrecioBase >= 0),

    CONSTRAINT CK_DetallePedido_MontoAdicional
        CHECK (MontoAdicional >= 0),

    CONSTRAINT CK_DetallePedido_Subtotal
        CHECK (Subtotal >= 0)
);
GO


/* ============================================================
   7. TABLA PAGOS
   ============================================================ */

CREATE TABLE Pagos
(
    IdPago INT IDENTITY(1,1) NOT NULL,
    IdPedido INT NOT NULL,

    FechaPago DATETIME NOT NULL
        CONSTRAINT DF_Pagos_FechaPago
        DEFAULT GETDATE(),

    Monto DECIMAL(10,2) NOT NULL,

    MetodoPago VARCHAR(20) NOT NULL,

    EstadoPago VARCHAR(20) NOT NULL
        CONSTRAINT DF_Pagos_Estado
        DEFAULT 'Pendiente',

    Referencia VARCHAR(100) NULL,

    CONSTRAINT PK_Pagos
        PRIMARY KEY (IdPago),

    CONSTRAINT FK_Pagos_Pedidos
        FOREIGN KEY (IdPedido)
        REFERENCES Pedidos(IdPedido),

    CONSTRAINT CK_Pagos_Monto
        CHECK (Monto > 0),

    CONSTRAINT CK_Pagos_Metodo
        CHECK
        (
            MetodoPago IN
            (
                'Efectivo',
                'SINPE Movil'
            )
        ),

    CONSTRAINT CK_Pagos_Estado
        CHECK
        (
            EstadoPago IN
            (
                'Pendiente',
                'Pagado',
                'Anulado'
            )
        )
);
GO


/* ============================================================
   8. TABLA RECOLECCIONES
   ============================================================ */

CREATE TABLE Recolecciones
(
    IdRecoleccion INT IDENTITY(1,1) NOT NULL,
    IdPedido INT NOT NULL,

    Direccion VARCHAR(250) NOT NULL,
    FechaProgramada DATETIME NOT NULL,

    Estado VARCHAR(20) NOT NULL
        CONSTRAINT DF_Recolecciones_Estado
        DEFAULT 'Pendiente',

    Observaciones VARCHAR(300) NULL,

    CONSTRAINT PK_Recolecciones
        PRIMARY KEY (IdRecoleccion),

    CONSTRAINT FK_Recolecciones_Pedidos
        FOREIGN KEY (IdPedido)
        REFERENCES Pedidos(IdPedido),

    CONSTRAINT CK_Recolecciones_Estado
        CHECK
        (
            Estado IN
            (
                'Pendiente',
                'Programada',
                'Recolectada',
                'Cancelada'
            )
        )
);
GO


/* ============================================================
   9. TABLA PROMOCIONES
   ============================================================ */

CREATE TABLE Promociones
(
    IdPromocion INT IDENTITY(1,1) NOT NULL,

    IdServicio INT NULL,

    NombrePromocion VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(250) NULL,

    PorcentajeDescuento DECIMAL(5,2) NOT NULL,

    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,

    Activa BIT NOT NULL
        CONSTRAINT DF_Promociones_Activa
        DEFAULT 1,

    CONSTRAINT PK_Promociones
        PRIMARY KEY (IdPromocion),

    CONSTRAINT FK_Promociones_Servicios
        FOREIGN KEY (IdServicio)
        REFERENCES Servicios(IdServicio),

    CONSTRAINT CK_Promociones_Descuento
        CHECK
        (
            PorcentajeDescuento > 0
            AND PorcentajeDescuento <= 100
        ),

    CONSTRAINT CK_Promociones_Fechas
        CHECK
        (
            FechaFin >= FechaInicio
        )
);
GO


/* ============================================================
   10. TABLA INVENTARIO
   ============================================================ */

CREATE TABLE Inventario
(
    IdInventario INT IDENTITY(1,1) NOT NULL,

    NombreProducto VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(250) NULL,

    Cantidad DECIMAL(10,2) NOT NULL,
    UnidadMedida VARCHAR(20) NOT NULL,

    CantidadMinima DECIMAL(10,2) NOT NULL,

    FechaActualizacion DATETIME NOT NULL
        CONSTRAINT DF_Inventario_Fecha
        DEFAULT GETDATE(),

    Activo BIT NOT NULL
        CONSTRAINT DF_Inventario_Activo
        DEFAULT 1,

    CONSTRAINT PK_Inventario
        PRIMARY KEY (IdInventario),

    CONSTRAINT UQ_Inventario_Producto
        UNIQUE (NombreProducto),

    CONSTRAINT CK_Inventario_Cantidad
        CHECK (Cantidad >= 0),

    CONSTRAINT CK_Inventario_CantidadMinima
        CHECK (CantidadMinima >= 0),

    CONSTRAINT CK_Inventario_Unidad
        CHECK
        (
            UnidadMedida IN
            (
                'Litro',
                'Mililitro',
                'Kilogramo',
                'Gramo',
                'Unidad'
            )
        )
);
GO