CREATE TABLE [dbo].[roysched]
(
[title_id] [dbo].[tid] NOT NULL,
[lorange] [int] NULL,
[hirange] [int] NULL,
[royalty] [int] NULL
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[roysched] ([title_id]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[roysched] ADD CONSTRAINT [FK__roysched__title___15502E78] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
