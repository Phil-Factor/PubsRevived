CREATE TABLE [dbo].[sales]
(
[stor_id] [char] (8) NOT NULL,
[ord_num] [nvarchar] (40) NOT NULL,
[ord_date] [datetime] NOT NULL,
[qty] [smallint] NOT NULL,
[payterms] [varchar] (12) NOT NULL,
[Publication_id] [dbo].[tid] NOT NULL
)
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [UPKCL_sales] PRIMARY KEY CLUSTERED  ([stor_id], [ord_num], [Publication_id])
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[sales] ([Publication_id])
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesStores] FOREIGN KEY ([stor_id]) REFERENCES [dbo].[stores] ([stor_id])
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesTitles] FOREIGN KEY ([Publication_id]) REFERENCES [dbo].[publications] ([Publication_id]) ON DELETE CASCADE
GO
