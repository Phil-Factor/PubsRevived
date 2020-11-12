SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
Create view [dbo].[titles]
/* this view replaces the old TITLES table and shows only those books that represent each publication and only the current price */
as
SELECT publications.Publication_id AS title_id, publications.title, pub_id,
  price, advance, royalty, ytd_sales, notes, pubdate
  FROM publications
    INNER JOIN editions
      ON editions.publication_id = publications.Publication_id
     AND Publication_type = 'book'
    INNER JOIN prices
      ON prices.Edition_id = editions.Edition_id
  WHERE prices.PriceEndDate IS NULL;
GO
