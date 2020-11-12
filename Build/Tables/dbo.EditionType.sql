CREATE TABLE [dbo].[EditionType]
(
[TheType] [nvarchar] (20) COLLATE Latin1_General_CI_AS NOT NULL
)
GO
ALTER TABLE [dbo].[EditionType] ADD CONSTRAINT [pk_EditionType] PRIMARY KEY CLUSTERED  ([TheType])
GO
