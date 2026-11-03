SET NOCOUNT ON;

IF OBJECT_ID('dbo.IncidenteRutaAzure', 'U') IS NOT NULL DROP TABLE dbo.IncidenteRutaAzure;
IF OBJECT_ID('dbo.IncidentesAzure', 'U') IS NOT NULL DROP TABLE dbo.IncidentesAzure;
IF OBJECT_ID('dbo.DemandaParadasAzure', 'U') IS NOT NULL DROP TABLE dbo.DemandaParadasAzure;
IF OBJECT_ID('dbo.ViajesAzure', 'U') IS NOT NULL DROP TABLE dbo.ViajesAzure;
IF OBJECT_ID('dbo.VehiculosAzure', 'U') IS NOT NULL DROP TABLE dbo.VehiculosAzure;
IF OBJECT_ID('dbo.ParadasAzure', 'U') IS NOT NULL DROP TABLE dbo.ParadasAzure;
IF OBJECT_ID('dbo.RutasAzure', 'U') IS NOT NULL DROP TABLE dbo.RutasAzure;

CREATE TABLE dbo.RutasAzure (
  AnioFuente smallint NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL, CodigoRuta nvarchar(20) NOT NULL,
  NombreRuta nvarchar(120) NOT NULL, Origen nvarchar(80) NOT NULL, Destino nvarchar(80) NOT NULL,
  VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL, Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_RutasAzure PRIMARY KEY (AnioFuente, RutaHistoricaId)
);

CREATE TABLE dbo.ParadasAzure (
  AnioFuente smallint NOT NULL, ParadaHistoricaId nvarchar(30) NOT NULL, CodigoPublicado nvarchar(20) NOT NULL,
  NombreParada nvarchar(120) NOT NULL, Zona nvarchar(40) NOT NULL, Latitud decimal(9,6) NOT NULL, Longitud decimal(9,6) NOT NULL,
  VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL, Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_ParadasAzure PRIMARY KEY (AnioFuente, ParadaHistoricaId)
);

CREATE TABLE dbo.VehiculosAzure (
  AnioFuente smallint NOT NULL, VehiculoId nvarchar(20) NOT NULL, Placa nvarchar(20) NOT NULL, TipoVehiculo nvarchar(30) NOT NULL,
  CapacidadEfectiva int NOT NULL, VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL, Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_VehiculosAzure PRIMARY KEY (AnioFuente, VehiculoId)
);

CREATE TABLE dbo.ViajesAzure (
  AnioFuente smallint NOT NULL, ViajeId nvarchar(30) NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL, VehiculoId nvarchar(20) NOT NULL,
  FechaServicio date NOT NULL, HoraProgramada time NOT NULL, HoraSalida time NOT NULL, HoraLlegada time NOT NULL,
  ValidacionesTarjeta int NOT NULL, KmRecorridos decimal(8,1) NOT NULL, EstadoViaje nvarchar(20) NOT NULL,
  CONSTRAINT PK_ViajesAzure PRIMARY KEY (AnioFuente, ViajeId),
  CONSTRAINT FK_Viajes_Rutas FOREIGN KEY (AnioFuente, RutaHistoricaId) REFERENCES dbo.RutasAzure (AnioFuente, RutaHistoricaId),
  CONSTRAINT FK_Viajes_Vehiculos FOREIGN KEY (AnioFuente, VehiculoId) REFERENCES dbo.VehiculosAzure (AnioFuente, VehiculoId)
);

CREATE TABLE dbo.DemandaParadasAzure (
  AnioFuente smallint NOT NULL, DemandaId nvarchar(30) NOT NULL, FechaServicio date NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL,
  ParadaHistoricaId nvarchar(30) NOT NULL, Franja nvarchar(20) NOT NULL, ValidacionesTarjeta int NOT NULL,
  Descensos int NOT NULL, DemandaNoAtendida int NOT NULL, Metodo nvarchar(30) NOT NULL,
  CONSTRAINT PK_DemandaParadasAzure PRIMARY KEY (AnioFuente, DemandaId),
  CONSTRAINT FK_Demanda_Rutas FOREIGN KEY (AnioFuente, RutaHistoricaId) REFERENCES dbo.RutasAzure (AnioFuente, RutaHistoricaId),
  CONSTRAINT FK_Demanda_Paradas FOREIGN KEY (AnioFuente, ParadaHistoricaId) REFERENCES dbo.ParadasAzure (AnioFuente, ParadaHistoricaId)
);

CREATE TABLE dbo.IncidentesAzure (
  AnioFuente smallint NOT NULL, IncidenteId nvarchar(30) NOT NULL, TipoIncidente nvarchar(30) NOT NULL, Severidad nvarchar(15) NOT NULL,
  FechaHoraInicio datetime2(0) NOT NULL, FechaHoraFin datetime2(0) NOT NULL, FechaHoraRegistro datetime2(0) NOT NULL,
  VehiculoId nvarchar(20) NULL, Descripcion nvarchar(200) NOT NULL,
  CONSTRAINT PK_IncidentesAzure PRIMARY KEY (AnioFuente, IncidenteId),
  CONSTRAINT FK_Incidentes_Vehiculos FOREIGN KEY (AnioFuente, VehiculoId) REFERENCES dbo.VehiculosAzure (AnioFuente, VehiculoId)
);

CREATE TABLE dbo.IncidenteRutaAzure (
  AnioFuente smallint NOT NULL, IncidenteId nvarchar(30) NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL, EsPrincipal bit NOT NULL,
  CONSTRAINT PK_IncidenteRutaAzure PRIMARY KEY (AnioFuente, IncidenteId, RutaHistoricaId),
  CONSTRAINT FK_IncidenteRuta_Incidentes FOREIGN KEY (AnioFuente, IncidenteId) REFERENCES dbo.IncidentesAzure (AnioFuente, IncidenteId),
  CONSTRAINT FK_IncidenteRuta_Rutas FOREIGN KEY (AnioFuente, RutaHistoricaId) REFERENCES dbo.RutasAzure (AnioFuente, RutaHistoricaId)
);

CREATE INDEX IX_ViajesAzure_FechaRuta ON dbo.ViajesAzure (FechaServicio, RutaHistoricaId);
CREATE INDEX IX_DemandaAzure_FechaFranja ON dbo.DemandaParadasAzure (FechaServicio, Franja);
GO
