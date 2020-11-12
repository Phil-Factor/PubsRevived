CREATE TABLE [dbo].[Limbo]
(
[Soul_ID] [int] NOT NULL IDENTITY(1, 1),
[JSON] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Version] [nvarchar] (20) COLLATE Latin1_General_CI_AS NULL,
[SourceName] [sys].[sysname] NOT NULL,
[InsertionDate] [datetime2] NOT NULL DEFAULT (getdate())
)
GO
