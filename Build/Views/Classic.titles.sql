SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [Classic].[titles]
AS
SELECT titles.title_id, titles.title, Coalesce(TN.Tag, 'Undecided') AS type,
  titles.pub_id, titles.price, titles.advance, titles.royalty,
  titles.ytd_sales, titles.notes, titles.pubdate
  FROM dbo.titles AS titles
    LEFT OUTER JOIN dbo.TagTitle Tagtitle
      ON TagTitle.title_id = titles.title_id
    INNER JOIN dbo.TagName AS TN
      ON TN.TagName_ID = TagTitle.TagName_ID
  WHERE TagTitle.Is_Primary = 1;
GO
