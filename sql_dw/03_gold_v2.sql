/*
  VERSION 2 - CAPA GOLD
  Modelo estrella simple para analisis de transporte publico.
  Ejecutar despues de 02_silver_v2.sql, conectado a dw_transporte.
  Gold se alimenta desde Silver: este script solo crea la estructura.
*/
SET NOCOUNT ON;
GO

IF DB_NAME() <> N'dw_transporte'
    THROW 51200, 'Conectese a la base de datos dw_transporte antes de ejecutar este script.', 1;
GO

IF SCHEMA_ID(N'gold') IS NULL EXEC(N'CREATE SCHEMA gold');
GO

IF OBJECT_ID(N'gold.dim_ruta', N'U') IS NOT NULL
    THROW 51201, 'gold.dim_ruta ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.dim_parada', N'U') IS NOT NULL
    THROW 51202, 'gold.dim_parada ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.dim_vehiculo', N'U') IS NOT NULL
    THROW 51203, 'gold.dim_vehiculo ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.dim_fecha', N'U') IS NOT NULL
    THROW 51204, 'gold.dim_fecha ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.dim_franja_horaria', N'U') IS NOT NULL
    THROW 51205, 'gold.dim_franja_horaria ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.fact_viaje', N'U') IS NOT NULL
    THROW 51206, 'gold.fact_viaje ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.fact_demanda_parada', N'U') IS NOT NULL
    THROW 51207, 'gold.fact_demanda_parada ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.fact_incidente', N'U') IS NOT NULL
    THROW 51208, 'gold.fact_incidente ya existe. Version 2 requiere una base limpia.', 1;
IF OBJECT_ID(N'gold.bridge_incidente_ruta', N'U') IS NOT NULL
    THROW 51209, 'gold.bridge_incidente_ruta ya existe. Version 2 requiere una base limpia.', 1;
GO

CREATE TABLE gold.dim_ruta (
    ruta_sk             INT IDENTITY(1,1) NOT NULL,
    ruta_historica_id   NVARCHAR(30)     NOT NULL,
    codigo_ruta         NVARCHAR(20)     NOT NULL,
    nombre_ruta         NVARCHAR(120)    NOT NULL,
    origen              NVARCHAR(80)     NOT NULL,
    destino             NVARCHAR(80)     NOT NULL,
    vigencia_desde      DATE             NOT NULL,
    vigencia_hasta      DATE             NOT NULL,
    estado              NVARCHAR(20)     NOT NULL,
    CONSTRAINT PK_gold_dim_ruta PRIMARY KEY (ruta_sk),
    CONSTRAINT UQ_gold_dim_ruta_historica UNIQUE (ruta_historica_id)
);
GO

CREATE TABLE gold.dim_parada (
    parada_sk             INT IDENTITY(1,1) NOT NULL,
    parada_historica_id   NVARCHAR(30)     NOT NULL,
    codigo_publicado      NVARCHAR(20)     NOT NULL,
    nombre_parada         NVARCHAR(120)    NOT NULL,
    zona                  NVARCHAR(40)     NOT NULL,
    latitud               DECIMAL(9,6)     NOT NULL,
    longitud              DECIMAL(9,6)     NOT NULL,
    vigencia_desde        DATE             NOT NULL,
    vigencia_hasta        DATE             NOT NULL,
    estado                NVARCHAR(20)     NOT NULL,
    CONSTRAINT PK_gold_dim_parada PRIMARY KEY (parada_sk),
    CONSTRAINT UQ_gold_dim_parada_historica UNIQUE (parada_historica_id)
);
GO

CREATE TABLE gold.dim_vehiculo (
    vehiculo_sk           INT IDENTITY(1,1) NOT NULL,
    vehiculo_id           NVARCHAR(20)     NOT NULL,
    placa                 NVARCHAR(20)     NOT NULL,
    tipo_vehiculo         NVARCHAR(30)     NOT NULL,
    capacidad_efectiva    INT              NOT NULL,
    vigencia_desde        DATE             NOT NULL,
    vigencia_hasta        DATE             NOT NULL,
    estado                NVARCHAR(20)     NOT NULL,
    CONSTRAINT PK_gold_dim_vehiculo PRIMARY KEY (vehiculo_sk),
    CONSTRAINT UQ_gold_dim_vehiculo_id UNIQUE (vehiculo_id)
);
GO

CREATE TABLE gold.dim_fecha (
    fecha_sk         INT          NOT NULL,
    fecha            DATE         NOT NULL,
    anio             SMALLINT     NOT NULL,
    mes              TINYINT      NOT NULL,
    dia              TINYINT      NOT NULL,
    trimestre        TINYINT      NOT NULL,
    CONSTRAINT PK_gold_dim_fecha PRIMARY KEY (fecha_sk),
    CONSTRAINT UQ_gold_dim_fecha UNIQUE (fecha)
);
GO

CREATE TABLE gold.dim_franja_horaria (
    franja_sk        INT IDENTITY(1,1) NOT NULL,
    franja           NVARCHAR(20)     NOT NULL,
    orden_franja     TINYINT          NOT NULL,
    CONSTRAINT PK_gold_dim_franja_horaria PRIMARY KEY (franja_sk),
    CONSTRAINT UQ_gold_dim_franja_horaria UNIQUE (franja)
);
GO

CREATE TABLE gold.fact_viaje (
    viaje_sk                BIGINT IDENTITY(1,1) NOT NULL,
    anio_fuente             SMALLINT             NOT NULL,
    viaje_id                NVARCHAR(30)         NOT NULL,
    fecha_sk                INT                  NOT NULL,
    ruta_sk                 INT                  NOT NULL,
    vehiculo_sk             INT                  NOT NULL,
    hora_programada         TIME                 NOT NULL,
    hora_salida             TIME                 NOT NULL,
    hora_llegada            TIME                 NOT NULL,
    validaciones_tarjeta    INT                  NOT NULL,
    km_recorridos           DECIMAL(8,1)         NOT NULL,
    estado_viaje            NVARCHAR(20)         NOT NULL,
    CONSTRAINT PK_gold_fact_viaje PRIMARY KEY (viaje_sk),
    CONSTRAINT UQ_gold_fact_viaje_origen UNIQUE (anio_fuente, viaje_id),
    CONSTRAINT FK_gold_fact_viaje_fecha FOREIGN KEY (fecha_sk) REFERENCES gold.dim_fecha (fecha_sk),
    CONSTRAINT FK_gold_fact_viaje_ruta FOREIGN KEY (ruta_sk) REFERENCES gold.dim_ruta (ruta_sk),
    CONSTRAINT FK_gold_fact_viaje_vehiculo FOREIGN KEY (vehiculo_sk) REFERENCES gold.dim_vehiculo (vehiculo_sk)
);
GO

CREATE TABLE gold.fact_demanda_parada (
    demanda_sk               BIGINT IDENTITY(1,1) NOT NULL,
    anio_fuente              SMALLINT             NOT NULL,
    demanda_id               NVARCHAR(30)         NOT NULL,
    fecha_sk                 INT                  NOT NULL,
    ruta_sk                  INT                  NOT NULL,
    parada_sk                INT                  NOT NULL,
    franja_sk                INT                  NOT NULL,
    validaciones_tarjeta     INT                  NOT NULL,
    descensos                INT                  NOT NULL,
    demanda_no_atendida      INT                  NOT NULL,
    metodo                   NVARCHAR(30)         NOT NULL,
    CONSTRAINT PK_gold_fact_demanda_parada PRIMARY KEY (demanda_sk),
    CONSTRAINT UQ_gold_fact_demanda_origen UNIQUE (anio_fuente, demanda_id),
    CONSTRAINT FK_gold_fact_demanda_fecha FOREIGN KEY (fecha_sk) REFERENCES gold.dim_fecha (fecha_sk),
    CONSTRAINT FK_gold_fact_demanda_ruta FOREIGN KEY (ruta_sk) REFERENCES gold.dim_ruta (ruta_sk),
    CONSTRAINT FK_gold_fact_demanda_parada FOREIGN KEY (parada_sk) REFERENCES gold.dim_parada (parada_sk),
    CONSTRAINT FK_gold_fact_demanda_franja FOREIGN KEY (franja_sk) REFERENCES gold.dim_franja_horaria (franja_sk)
);
GO

CREATE TABLE gold.fact_incidente (
    incidente_sk            BIGINT IDENTITY(1,1) NOT NULL,
    anio_fuente             SMALLINT             NOT NULL,
    incidente_id            NVARCHAR(30)         NOT NULL,
    fecha_sk                INT                  NOT NULL,
    vehiculo_sk             INT                  NULL,
    tipo_incidente          NVARCHAR(30)         NOT NULL,
    severidad               NVARCHAR(15)         NOT NULL,
    fecha_hora_inicio       DATETIME2(0)         NOT NULL,
    fecha_hora_fin          DATETIME2(0)         NOT NULL,
    fecha_hora_registro     DATETIME2(0)         NOT NULL,
    descripcion             NVARCHAR(200)        NOT NULL,
    CONSTRAINT PK_gold_fact_incidente PRIMARY KEY (incidente_sk),
    CONSTRAINT UQ_gold_fact_incidente_origen UNIQUE (anio_fuente, incidente_id),
    CONSTRAINT FK_gold_fact_incidente_fecha FOREIGN KEY (fecha_sk) REFERENCES gold.dim_fecha (fecha_sk),
    CONSTRAINT FK_gold_fact_incidente_vehiculo FOREIGN KEY (vehiculo_sk) REFERENCES gold.dim_vehiculo (vehiculo_sk)
);
GO

CREATE TABLE gold.bridge_incidente_ruta (
    incidente_ruta_sk       BIGINT IDENTITY(1,1) NOT NULL,
    incidente_sk            BIGINT               NOT NULL,
    ruta_sk                 INT                  NOT NULL,
    es_principal            BIT                  NOT NULL,
    CONSTRAINT PK_gold_bridge_incidente_ruta PRIMARY KEY (incidente_ruta_sk),
    CONSTRAINT UQ_gold_bridge_incidente_ruta UNIQUE (incidente_sk, ruta_sk),
    CONSTRAINT FK_gold_bridge_incidente FOREIGN KEY (incidente_sk) REFERENCES gold.fact_incidente (incidente_sk),
    CONSTRAINT FK_gold_bridge_ruta FOREIGN KEY (ruta_sk) REFERENCES gold.dim_ruta (ruta_sk)
);
GO

CREATE INDEX IX_gold_fact_viaje_fecha_ruta
    ON gold.fact_viaje (fecha_sk, ruta_sk);
CREATE INDEX IX_gold_fact_demanda_fecha_ruta_franja
    ON gold.fact_demanda_parada (fecha_sk, ruta_sk, franja_sk);
CREATE INDEX IX_gold_fact_incidente_fecha
    ON gold.fact_incidente (fecha_sk);
GO
