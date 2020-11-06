SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
Create view [dbo].[titles]
as
SELECT publications.publication_id, publications.title, pub_id, price,advance,royalty,ytd_sales, notes, pubdate		 
FROM publications
INNER JOIN editions ON editions.Publication_id=publications.publication_id
INNER JOIN prices ON prices.Edition_id=editions.edition_id
GO
