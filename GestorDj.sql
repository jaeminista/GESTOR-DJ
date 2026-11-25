-- 1. BASE DE DATOS ----------------------------------------------------
    CREATE DATABASE GestorDJ;
GO

USE GestorDJ;
GO

-- 2. TABLAS ------------------------------------------------------------

-- Roles
CREATE TABLE dbo.Roles (
    id_rol      INT IDENTITY(1,1) NOT NULL,
    nombre_rol  VARCHAR(50)       NOT NULL,
    CONSTRAINT PK_Roles        PRIMARY KEY (id_rol),
    CONSTRAINT UQ_Roles_nombre UNIQUE (nombre_rol)
);
GO

-- Empleados
CREATE TABLE dbo.Empleados (
    id_empleado INT IDENTITY(1,1) NOT NULL,
    nombre      VARCHAR(50)       NOT NULL,
    apellido    VARCHAR(50)       NOT NULL,
    telefono    VARCHAR(15)       NULL,
    id_rol      INT               NOT NULL,
    estado      BIT               NOT NULL CONSTRAINT DF_Empleados_estado DEFAULT (1),
    CONSTRAINT PK_Empleados      PRIMARY KEY (id_empleado),
    CONSTRAINT FK_Empleados_Roles FOREIGN KEY (id_rol) REFERENCES dbo.Roles (id_rol)
);
GO

-- Usuarios (un usuario por empleado)
CREATE TABLE dbo.Usuarios (
    id_usuario    INT IDENTITY(1,1) NOT NULL,
    id_empleado   INT               NOT NULL,
    usuario       VARCHAR(30)       NOT NULL,
    contrasena    VARCHAR(15)       NOT NULL,
    ultimo_acceso DATETIME          NOT NULL CONSTRAINT DF_Usuarios_ultimo_acceso DEFAULT (GETDATE()),
    CONSTRAINT PK_Usuarios          PRIMARY KEY (id_usuario),
    CONSTRAINT UQ_Usuarios_empleado UNIQUE (id_empleado),
    CONSTRAINT UQ_Usuarios_usuario  UNIQUE (usuario),
    CONSTRAINT FK_Usuarios_Empleados FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados (id_empleado)
);
GO

-- Categoria
CREATE TABLE dbo.Categoria (
    id_categoria INT IDENTITY(1,1) NOT NULL,
    nombre       VARCHAR(50)       NOT NULL,
    descripcion  VARCHAR(100)      NULL,
    estado       BIT               NOT NULL CONSTRAINT DF_Categoria_estado DEFAULT (1),
    CONSTRAINT PK_Categoria        PRIMARY KEY (id_categoria),
    CONSTRAINT UQ_Categoria_nombre UNIQUE (nombre)
);
GO

-- Productos
CREATE TABLE dbo.Productos (
    id_producto   INT IDENTITY(1,1) NOT NULL,
    codigo_barras VARCHAR(30)       NULL,
    nombre        VARCHAR(100)      NOT NULL,
    id_categoria  INT               NOT NULL,
    precio        DECIMAL(10,2)     NOT NULL,
    stock         INT               NOT NULL CONSTRAINT DF_Productos_stock        DEFAULT (0),
    stock_minimo  INT               NOT NULL CONSTRAINT DF_Productos_stock_minimo DEFAULT (0),
    estado        BIT               NOT NULL CONSTRAINT DF_Productos_estado       DEFAULT (1),
    CONSTRAINT PK_Productos           PRIMARY KEY (id_producto),
    CONSTRAINT FK_Productos_Categoria FOREIGN KEY (id_categoria) REFERENCES dbo.Categoria (id_categoria),
    CONSTRAINT CK_Productos_precio       CHECK (precio > 0),
    CONSTRAINT CK_Productos_stock        CHECK (stock >= 0),
    CONSTRAINT CK_Productos_stock_minimo CHECK (stock_minimo >= 0)
);
GO

-- El código de barras es opcional, pero si existe no puede repetirse
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Productos_codigo_barras')
    CREATE UNIQUE INDEX UQ_Productos_codigo_barras
        ON dbo.Productos (codigo_barras) WHERE codigo_barras IS NOT NULL;
GO

-- Tipo_Movimiento (afectacion: 1 = suma al stock, -1 = resta)
CREATE TABLE dbo.Tipo_Movimiento (
    id_tipo    INT IDENTITY(1,1) NOT NULL,
    nombre     VARCHAR(30)       NOT NULL,
    afectacion SMALLINT          NOT NULL,
    CONSTRAINT PK_Tipo_Movimiento        PRIMARY KEY (id_tipo),
    CONSTRAINT UQ_Tipo_Movimiento_nombre UNIQUE (nombre),
    CONSTRAINT CK_Tipo_Movimiento_afectacion CHECK (afectacion IN (1, -1))
);
GO

-- Ajustes_Inventario
CREATE TABLE dbo.Ajustes_Inventario (
    id_ajuste   INT IDENTITY(1,1) NOT NULL,
    id_producto INT               NOT NULL,
    id_empleado INT               NOT NULL,
    id_tipo     INT               NOT NULL,
    cantidad    INT               NOT NULL,
    motivo      VARCHAR(100)      NOT NULL,
    fecha       DATETIME          NOT NULL CONSTRAINT DF_Ajustes_fecha DEFAULT (GETDATE()),
    CONSTRAINT PK_Ajustes_Inventario PRIMARY KEY (id_ajuste),
    CONSTRAINT FK_Ajustes_Productos  FOREIGN KEY (id_producto) REFERENCES dbo.Productos (id_producto),
    CONSTRAINT FK_Ajustes_Empleados  FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados (id_empleado),
    CONSTRAINT FK_Ajustes_Tipo       FOREIGN KEY (id_tipo)     REFERENCES dbo.Tipo_Movimiento (id_tipo),
    CONSTRAINT CK_Ajustes_cantidad   CHECK (cantidad > 0)
);
GO

-- Ventas (MAESTRO)
CREATE TABLE dbo.Ventas (
    id_venta    INT IDENTITY(1,1) NOT NULL,
    id_empleado INT               NOT NULL,
    fecha       DATETIME          NOT NULL CONSTRAINT DF_Ventas_fecha DEFAULT (GETDATE()),
    total       DECIMAL(10,2)     NOT NULL CONSTRAINT DF_Ventas_total DEFAULT (0),
    CONSTRAINT PK_Ventas           PRIMARY KEY (id_venta),
    CONSTRAINT FK_Ventas_Empleados FOREIGN KEY (id_empleado) REFERENCES dbo.Empleados (id_empleado),
    CONSTRAINT CK_Ventas_total     CHECK (total >= 0)
);
GO

-- Ventas_Detalle (DETALLE)
CREATE TABLE dbo.Ventas_Detalle (
    id_detalle      INT IDENTITY(1,1) NOT NULL,
    id_venta        INT               NOT NULL,
    id_producto     INT               NOT NULL,
    cantidad        INT               NOT NULL,
    precio_unitario DECIMAL(10,2)     NOT NULL,
    CONSTRAINT PK_Ventas_Detalle          PRIMARY KEY (id_detalle),
    CONSTRAINT FK_VentasDetalle_Ventas    FOREIGN KEY (id_venta)    REFERENCES dbo.Ventas (id_venta),
    CONSTRAINT FK_VentasDetalle_Productos FOREIGN KEY (id_producto) REFERENCES dbo.Productos (id_producto),
    CONSTRAINT CK_VentasDetalle_cantidad  CHECK (cantidad > 0),
    CONSTRAINT CK_VentasDetalle_precio    CHECK (precio_unitario > 0),
    CONSTRAINT UQ_VentasDetalle_venta_producto UNIQUE (id_venta, id_producto)
);
GO
