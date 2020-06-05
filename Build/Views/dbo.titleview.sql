SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[titleview]
AS
SELECT t.title, ta.au_ord, a.au_lname, t.price, t.ytd_sales, t.pub_id
  FROM dbo.authors AS a
    INNER JOIN dbo.titleauthor AS ta
      ON a.au_id = ta.au_id
    INNER JOIN dbo.titles AS t
      ON t.title_id = ta.title_id;

GO
