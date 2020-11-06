CREATE TABLE [dbo].[editions]
(
[Edition_id] [int] NOT NULL IDENTITY(1, 1),
[publication_id] [dbo].[tid] NOT NULL,
[Publication_type] [nvarchar] (20) COLLATE Latin1_General_CI_AS NOT NULL DEFAULT ('book'),
[EditionDate] [datetime2] NOT NULL DEFAULT (getdate())
)
GO
ALTER TABLE [dbo].[editions] ADD CONSTRAINT [PK_editions] PRIMARY KEY CLUSTERED  ([Edition_id])
GO
ALTER TABLE [dbo].[editions] ADD CONSTRAINT [fk_edition] FOREIGN KEY ([publication_id]) REFERENCES [dbo].[publications] ([Publication_id])
GO
