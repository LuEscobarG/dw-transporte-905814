/*
  VERSION 2 - CAPA SILVER
  Ejecutar despues de 01_bronze_v2.sql, conectado a dw_transporte.
  Conserva las mismas entidades del origen, con tipos de datos nativos y
  relaciones para recibir solo registros ya limpiados.

  
*/

SET NOCOUNT ON;
GO

IF DB_NAME() <> N'dw_transporte'
    THROW 51100, 'Conectese a la base de datos dw_transporte antes de ejecutar este script.', 1;
GO

IF SCHEMA_ID(N'silver') IS NULL
    EXEC(N'CREATE SCHEMA silver');
GO


IF OBJECT_ID(N'silver.RutasAzure', N'U') IS NOT NULL
    THROW 51101, 'silver.RutasAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.ParadasAzure', N'U') IS NOT NULL
    THROW 51102, 'silver.ParadasAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.VehiculosAzure', N'U') IS NOT NULL
    THROW 51103, 'silver.VehiculosAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.ViajesAzure', N'U') IS NOT NULL
    THROW 51104, 'silver.ViajesAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.DemandaParadasAzure', N'U') IS NOT NULL
    THROW 51105, 'silver.DemandaParadasAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.IncidentesAzure', N'U') IS NOT NULL
    THROW 51106, 'silver.IncidentesAzure ya existe. Version 2 requiere una base limpia.', 1;

IF OBJECT_ID(N'silver.IncidenteRutaAzure', N'U') IS NOT NULL
    THROW 51107, 'silver.IncidenteRutaAzure ya existe. Version 2 requiere una base limpia.', 1;
GO


-- ============================================================
-- RUTAS
-- ============================================================

CREATE TABLE silver.RutasAzure (
    AnioFuente         SMALLINT      NOT NULL,
    RutaHistoricaId    NVARCHAR(30)  NOT NULL,
    CodigoRuta         NVARCHAR(20)  NOT NULL,
    NombreRuta         NVARCHAR(120) NOT NULL,
    Origen             NVARCHAR(80)  NOT NULL,
    Destino            NVARCHAR(80)  NOT NULL,
    VigenciaDesde      DATE          NOT NULL,
    VigenciaHasta      DATE          NOT NULL,
    Estado             NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_silver_RutasAzure
        PRIMARY KEY (RutaHistoricaId)
);
GO


-- ============================================================
-- PARADAS
-- ============================================================

CREATE TABLE silver.ParadasAzure (
    AnioFuente         SMALLINT      NOT NULL,
    ParadaHistoricaId  NVARCHAR(30)  NOT NULL,
    CodigoPublicado    NVARCHAR(20)  NOT NULL,
    NombreParada       NVARCHAR(120) NOT NULL,
    Zona               NVARCHAR(40)  NOT NULL,
    Latitud            DECIMAL(9,6)  NOT NULL,
    Longitud           DECIMAL(9,6)  NOT NULL,
    VigenciaDesde      DATE          NOT NULL,
    VigenciaHasta      DATE          NOT NULL,
    Estado             NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_silver_ParadasAzure
        PRIMARY KEY (ParadaHistoricaId)
);
GO


-- ============================================================
-- VEHICULOS
-- ============================================================

CREATE TABLE silver.VehiculosAzure (
    AnioFuente          SMALLINT     NOT NULL,
    VehiculoId          NVARCHAR(20) NOT NULL,
    Placa               NVARCHAR(20) NOT NULL,
    TipoVehiculo        NVARCHAR(30) NOT NULL,
    CapacidadEfectiva   INT          NOT NULL,
    VigenciaDesde       DATE         NOT NULL,
    VigenciaHasta       DATE         NOT NULL,
    Estado              NVARCHAR(20) NOT NULL,

    CONSTRAINT PK_silver_VehiculosAzure
        PRIMARY KEY (VehiculoId)
);
GO


-- ============================================================
-- VIAJES
-- ============================================================

CREATE TABLE silver.ViajesAzure (
    AnioFuente            SMALLINT      NOT NULL,
    ViajeId               NVARCHAR(30)  NOT NULL,
    RutaHistoricaId       NVARCHAR(30)  NOT NULL,
    VehiculoId            NVARCHAR(20)  NOT NULL,
    FechaServicio         DATE          NOT NULL,
    HoraProgramada        TIME          NOT NULL,
    HoraSalida            TIME          NOT NULL,
    HoraLlegada           TIME          NOT NULL,
    ValidacionesTarjeta   INT           NOT NULL,
    KmRecorridos          DECIMAL(8,1)  NOT NULL,
    EstadoViaje           NVARCHAR(20)  NOT NULL,

    CONSTRAINT PK_silver_ViajesAzure
        PRIMARY KEY (ViajeId),

    CONSTRAINT FK_silver_Viajes_Rutas
        FOREIGN KEY (RutaHistoricaId)
        REFERENCES silver.RutasAzure (RutaHistoricaId),

    CONSTRAINT FK_silver_Viajes_Vehiculos
        FOREIGN KEY (VehiculoId)
        REFERENCES silver.VehiculosAzure (VehiculoId)
);
GO


-- ============================================================
-- DEMANDA PARADAS
-- ============================================================

CREATE TABLE silver.DemandaParadasAzure (
    AnioFuente             SMALLINT      NOT NULL,
    DemandaId              NVARCHAR(30)  NOT NULL,
    FechaServicio          DATE          NOT NULL,
    RutaHistoricaId        NVARCHAR(30)  NOT NULL,
    ParadaHistoricaId      NVARCHAR(30)  NOT NULL,
    Franja                 NVARCHAR(20)  NOT NULL,
    ValidacionesTarjeta    INT           NOT NULL,
    Descensos              INT           NOT NULL,
    DemandaNoAtendida      INT           NOT NULL,
    Metodo                 NVARCHAR(30)   NOT NULL,

    CONSTRAINT PK_silver_DemandaParadasAzure
        PRIMARY KEY (DemandaId),

    CONSTRAINT FK_silver_Demanda_Rutas
        FOREIGN KEY (RutaHistoricaId)
        REFERENCES silver.RutasAzure (RutaHistoricaId),

    CONSTRAINT FK_silver_Demanda_Paradas
        FOREIGN KEY (ParadaHistoricaId)
        REFERENCES silver.ParadasAzure (ParadaHistoricaId)
);
GO


-- ============================================================
-- INCIDENTES
-- ============================================================

CREATE TABLE silver.IncidentesAzure (
    AnioFuente          SMALLINT       NOT NULL,
    IncidenteId         NVARCHAR(30)   NOT NULL,
    TipoIncidente       NVARCHAR(30)   NOT NULL,
    Severidad           NVARCHAR(15)   NOT NULL,
    FechaHoraInicio     DATETIME2(0)   NOT NULL,
    FechaHoraFin        DATETIME2(0)   NOT NULL,
    FechaHoraRegistro   DATETIME2(0)   NOT NULL,
    VehiculoId          NVARCHAR(20)   NULL,
    Descripcion         NVARCHAR(200)  NOT NULL,

    CONSTRAINT PK_silver_IncidentesAzure
        PRIMARY KEY (IncidenteId),

    CONSTRAINT FK_silver_Incidentes_Vehiculos
        FOREIGN KEY (VehiculoId)
        REFERENCES silver.VehiculosAzure (VehiculoId)
);
GO


-- ============================================================
-- INCIDENTE - RUTA
-- ============================================================

CREATE TABLE silver.IncidenteRutaAzure (
    AnioFuente        SMALLINT      NOT NULL,
    IncidenteId       NVARCHAR(30)  NOT NULL,
    RutaHistoricaId   NVARCHAR(30)  NOT NULL,
    EsPrincipal       BIT           NOT NULL,

    CONSTRAINT PK_silver_IncidenteRutaAzure
        PRIMARY KEY (IncidenteId, RutaHistoricaId),

    CONSTRAINT FK_silver_IncidenteRuta_Incidente
        FOREIGN KEY (IncidenteId)
        REFERENCES silver.IncidentesAzure (IncidenteId),

    CONSTRAINT FK_silver_IncidenteRuta_Ruta
        FOREIGN KEY (RutaHistoricaId)
        REFERENCES silver.RutasAzure (RutaHistoricaId)
);
GO


-- ============================================================
-- INDICES
-- ============================================================

CREATE INDEX IX_silver_Viajes_FechaRuta
    ON silver.ViajesAzure (FechaServicio, RutaHistoricaId);

CREATE INDEX IX_silver_Demanda_FechaFranja
    ON silver.DemandaParadasAzure (FechaServicio, Franja);
GO