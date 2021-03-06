CREATE TABLE [dbo].[pub_info]
(
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[logo] [varbinary] (max) NULL,
[pr_info] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[pub_info] ADD CONSTRAINT [UPKCL_pubinfo] PRIMARY KEY CLUSTERED  ([pub_id]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[pub_info] ADD CONSTRAINT [FK_Pub_infoPublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
