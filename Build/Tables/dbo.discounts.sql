CREATE TABLE [dbo].[discounts]
(
[discounttype] [nvarchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[stor_id] [char] (8) COLLATE Latin1_General_CI_AS NULL,
[lowqty] [smallint] NULL,
[highqty] [smallint] NULL,
[discount] [decimal] (4, 2) NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[discounts] ADD CONSTRAINT [FK_DiscountsStore] FOREIGN KEY ([stor_id]) REFERENCES [dbo].[stores] ([stor_id])
GO
