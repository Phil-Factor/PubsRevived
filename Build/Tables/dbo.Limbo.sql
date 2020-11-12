CREATE TABLE [dbo].[Limbo]
(
[Soul_ID] [int] NOT NULL IDENTITY(1, 1),
[JSON] [nvarchar] (max) NOT NULL,
[Version] [nvarchar] (20) NOT NULL,
[SourceName] [sys].[sysname] NOT NULL,
[InsertionDate] [datetime2] NOT NULL DEFAULT (getdate())
)
GO
