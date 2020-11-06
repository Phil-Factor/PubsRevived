CREATE TABLE [dbo].[publications]
(
[Publication_id] [dbo].[tid] NOT NULL,
[title] [varchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NULL,
[notes] [varchar] (200) COLLATE Latin1_General_CI_AS NULL,
[pubdate] [datetime] NOT NULL CONSTRAINT [pub_NowDefault] DEFAULT (getdate())
)
GO
ALTER TABLE [dbo].[publications] ADD CONSTRAINT [PK_Publication] PRIMARY KEY CLUSTERED  ([Publication_id])
GO
ALTER TABLE [dbo].[publications] ADD CONSTRAINT [fkPublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
