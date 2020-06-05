SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[reptq1]
AS
  BEGIN
    SELECT CASE WHEN Grouping(titles.pub_id) = 1 THEN 'ALL' ELSE titles.pub_id END AS pub_id,
      Avg(titles.price) AS avg_price
      FROM dbo.titles AS titles
      WHERE titles.price IS NOT NULL
      GROUP BY titles.pub_id WITH ROLLUP
      ORDER BY pub_id;
  END;
GO
