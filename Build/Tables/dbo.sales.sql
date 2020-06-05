CREATE TABLE [dbo].[sales]
(
[stor_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[ord_num] [nvarchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[ord_date] [datetime] NOT NULL,
[qty] [smallint] NOT NULL,
[payterms] [varchar] (12) COLLATE Latin1_General_CI_AS NOT NULL,
[title_id] [dbo].[tid] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [UPKCL_sales] PRIMARY KEY CLUSTERED  ([stor_id], [ord_num], [title_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[sales] ([title_id]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesStores] FOREIGN KEY ([stor_id]) REFERENCES [dbo].[stores] ([stor_id])
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesTitles] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
