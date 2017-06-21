-- ********************************************************************************************
-- SETUP Adhoc analytics database with external data source and tables needed for Elastic Query 
-- *********************************************************************************************

-- Create encryption key that will encrypt database logins
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
	CREATE MASTER KEY;
GO

-- Create login credential, used to access the catalog and remote databases
IF NOT EXISTS (SELECT * FROM sys.database_scoped_credentials WHERE name = 'AdhocQueryDBCred')
	CREATE DATABASE SCOPED CREDENTIAL [AdhocQueryDBCred] WITH IDENTITY = N'developer', SECRET = N'P@ssword1';
GO

-- Add catalog database as external data source using credential created above
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'WtpTenantDBs')
BEGIN
	DECLARE @catalogServerName nvarchar(128) = (SELECT @@servername + '.database.windows.net');
	DECLARE @createExternalSource nvarchar(500) =
	N'CREATE EXTERNAL DATA SOURCE [WtpTenantDBs]
	WITH
	(
		TYPE = SHARD_MAP_MANAGER,
		LOCATION = ''' + @catalogServerName + ''',
		DATABASE_NAME = ''tenantcatalog'',
		SHARD_MAP_NAME = ''tenantcatalog'',
		CREDENTIAL = [AdhocQueryDBCred]
	);'
	EXEC(@createExternalSource)
END

-- Add tenant tables that will be used for querying data across all tenants

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER OFF;
GO

CREATE EXTERNAL TABLE [dbo].[VenueEvents]
(
    [VenueId] INT NOT NULL,
    [EventId] INT NOT NULL,
    [EventName] NVARCHAR (50) NOT NULL,
    [Subtitle] NVARCHAR (50) NULL,
    [Date] DATETIME NOT NULL
)
WITH
(
    DATA_SOURCE = [WtpTenantDBs],
    DISTRIBUTION = SHARDED(VenueId)
);
GO

SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER OFF;
GO

CREATE EXTERNAL TABLE [dbo].[VenueTicketPurchases]
(
    [VenueId] INT NOT NULL,
    [TicketPurchaseId] INT NOT NULL,
    [PurchaseDate] DATETIME NOT NULL,
    [PurchaseTotal] MONEY NOT NULL,
    [CustomerId] INT NOT NULL
)
WITH
(
	DATA_SOURCE = [WtpTenantDBs],
	DISTRIBUTION = SHARDED(VenueId)
);
GO

SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER OFF;
GO

CREATE EXTERNAL TABLE [dbo].[VenueTickets]
(
    [VenueId] INT NOT NULL,
    [TicketId] INT NOT NULL,
    [RowNumber] INT NOT NULL,
    [SeatNumber] INT NOT NULL,
    [EventId] INT NOT NULL,
    [SectionId] INT NOT NULL,
    [TicketPurchaseId] INT NOT NULL
)
WITH
(
	DATA_SOURCE = [WtpTenantDBs],
	DISTRIBUTION = SHARDED(VenueId)
);
GO
    
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER OFF;
GO
    
CREATE EXTERNAL TABLE [dbo].[Venues]
(
    [VenueId] INT NOT NULL,
    [VenueName] NVARCHAR (50) NOT NULL,
    [VenueType] CHAR (30) NOT NULL,
    [AdminEmail] NCHAR (30) NOT NULL,
    [PostalCode] CHAR (10) NULL,
    [CountryCode] CHAR (3) NOT NULL,
    [Server] NVARCHAR(128) NOT NULL,
    [DatabaseName] NVARCHAR(128) NOT NULL
)
WITH
(
	DATA_SOURCE = [WtpTenantDBs],
	DISTRIBUTION = SHARDED(VenueId)
);
GO

DROP TABLE IF EXISTS dbo.VenueTypes
CREATE TABLE [dbo].[VenueTypes]
(
    [VenueType] CHAR(30) NOT NULL,
    [VenueTypeName] NCHAR(30) NOT NULL,  
    [EventTypeName] NVARCHAR(30) NOT NULL, 
    [EventTypeShortName] NVARCHAR(20) NOT NULL,
    [EventTypeShortNamePlural] NVARCHAR(20) NOT NULL,
    [Language] CHAR(8) NOT NULL,
    PRIMARY KEY CLUSTERED ([VenueType] ASC)
)
GO

-- Create local venuetypes table that will store the types of venues available on the Wingtips tickets platform

CREATE UNIQUE INDEX IX_VENUETYPES_VENUETYPE ON [dbo].[VenueTypes] ([VenueType])
GO

CREATE UNIQUE INDEX IX_VENUETYPES_VENUETYPENAME_LANGUAGE ON [dbo].[VenueTypes] ([VenueTypeName], [Language])
GO

INSERT INTO [dbo].[VenueTypes]
    ([VenueType],[VenueTypeName],[EventTypeName],[EventTypeShortName],[EventTypeShortNamePlural],[Language])
VALUES
    ('multipurpose','Multi-Purpose','Event', 'Event','Events','en-us'),
    ('classicalmusic','Classical Music ','Classical Concert','Concert','Concerts','en-us'),
    ('jazz','Jazz','Jazz Session','Session','Sessions','en-us'),
    ('judo','Judo','Judo Tournament','Tournament','Tournaments','en-us'),
    ('soccer','Soccer','Soccer Match', 'Match','Matches','en-us'),
    ('motorracing','Motor Racing','Car Race', 'Race','Races','en-us'),
    ('dance', 'Dance', 'Performance', 'Performance', 'Performances','en-us'),
    ('blues', 'Blues', 'Blues Session', 'Session','Sessions','en-us' ),
    ('rockmusic','Rock Music','Rock Concert','Concert', 'Concerts','en-us'),
    ('opera','Opera','Opera','Opera','Operas','en-us');      
GO

--- Verify that the external data source and tables exist in the adhoc analytics database
select * from sys.external_data_sources;
select * from sys.external_tables;
GO

PRINT N'Initialization complete.';
GO