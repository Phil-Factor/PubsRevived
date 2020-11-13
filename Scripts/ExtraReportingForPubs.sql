CREATE OR ALTER VIEW PublishersByPublicationType
AS
/* A view to provide the number of each type of publication produced
by each publisher*/
SELECT Coalesce(publishers.pub_name, '---All types') AS publisher,
  Sum(CASE WHEN editions.Publication_type = 'AudioBook' THEN 1 ELSE 0 END) AS 'AudioBook',
  Sum(CASE WHEN editions.Publication_type = 'Book' THEN 1 ELSE 0 END) AS 'Book',
  Sum(CASE WHEN editions.Publication_type = 'Calendar' THEN 1 ELSE 0 END) AS 'Calendar',
  Sum(CASE WHEN editions.Publication_type = 'Ebook' THEN 1 ELSE 0 END) AS 'Ebook',
  Sum(CASE WHEN editions.Publication_type = 'Hardback' THEN 1 ELSE 0 END) AS 'Hardback',
  Sum(CASE WHEN editions.Publication_type = 'Map' THEN 1 ELSE 0 END) AS 'Map',
  Sum(CASE WHEN editions.Publication_type = 'Paperback' THEN 1 ELSE 0 END) AS 'PaperBack',
  Count(*) AS total
  FROM dbo.publishers
    INNER JOIN dbo.publications
      ON publications.pub_id = publishers.pub_id
    INNER JOIN editions
      ON editions.publication_id = publications.Publication_id
    INNER JOIN dbo.prices
      ON prices.Edition_id = editions.Edition_id
  WHERE prices.PriceEndDate IS NULL
  GROUP BY publishers.pub_name WITH ROLLUP;
GO

CREATE OR ALTER VIEW TitlesAndEditionsByPublisher
AS
/* A view to provide the number of each type of publication produced
by each publisher*/
SELECT publishers.pub_name AS publisher, title,
  String_Agg
    (
    Publication_type + ' ($' + Convert(VARCHAR(20), price) + ')', ', '
    ) AS ListOfEditions
  FROM dbo.publishers
    INNER JOIN dbo.publications
      ON publications.pub_id = publishers.pub_id
    INNER JOIN editions
      ON editions.publication_id = publications.Publication_id
    INNER JOIN dbo.prices
      ON prices.Edition_id = editions.Edition_id
  WHERE prices.PriceEndDate IS NULL
  GROUP BY publishers.pub_name, title;
SELECT * FROM  TitlesAndEditionsByPublisher