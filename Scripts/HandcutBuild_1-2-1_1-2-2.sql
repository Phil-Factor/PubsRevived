
GO
CREATE OR ALTER FUNCTION dbo.MoveForeignKeyReferences
  /*
 Select [dbo].[MoveForeignKeyReferences]('dbo.titles','dbo.publications', 'publication_id', 'ON DELETE CASCADE')
 */

  (@from sysname, @to sysname, @ToColumn sysname, @ONClause NVARCHAR(2000))
RETURNS NVARCHAR(MAX)
AS
  BEGIN
    DECLARE @Statements NVARCHAR(MAX) = N'';
    SELECT @Statements =
      @Statements + N'
ALTER TABLE '            + Object_Schema_Name(FKC.parent_object_id) + N'.'
      + Object_Name(FKC.parent_object_id) + N' DROP
   CONSTRAINT '          + Object_Name(constraint_object_id)
      + N'
GO
ALTER TABLE '            + Object_Schema_Name(FKC.parent_object_id) + N'.'
      + Object_Name(FKC.parent_object_id) + N' ADD
   CONSTRAINT  '         + Object_Name(constraint_object_id)
      + N'
       FOREIGN KEY ('
      + String_Agg(Col_Name(referenced_object_id, referenced_column_id), ', ')
      + N')
      REFERENCES  '      + @to + N' (' + @ToColumn + N')
     '                   + @ONClause + N'
GO'

      /*SELECT Object_Name(constraint_object_id),
		Object_Schema_Name( FKC.parent_object_id)+'.'+ Object_Name(FKC.parent_object_id),
		String_Agg(Col_Name(parent_object_id,parent_column_id),', '),
		Object_schema_Name( FKC.referenced_object_id)+'.'+ Object_Name(FKC.referenced_object_id),
		 String_Agg(Col_Name(referenced_object_id,Referenced_column_id),', ')
--SELECT * */
      FROM sys.foreign_key_columns FKC
      WHERE Object_Schema_Name(FKC.referenced_object_id) + '.'
            + Object_Name(FKC.referenced_object_id) = @from
      GROUP BY constraint_object_id, parent_object_id, referenced_object_id;

    RETURN @Statements;

  END;
GO
DROP TABLE editionType;
CREATE TABLE EditionType (TheType NVARCHAR(20) CONSTRAINT pk_EditionType PRIMARY KEY);
INSERT INTO EditionType (TheType)
  SELECT type
    FROM (VALUES ('Book'), ('AudioBook'), ('Map'), ('Hardback'),
          ('Paperback')
         ) f (type);
ALTER TABLE editions
ADD CONSTRAINT FK_EditionType FOREIGN KEY (Publication_type) REFERENCES dbo.EditionType
                                (TheType);
GO

CREATE TABLE dbo.publications
  (
  --Title_id AS publication_id, pub_id, title ,notes
  Publication_id dbo.tid NOT NULL CONSTRAINT PK_Publication PRIMARY KEY,
  title VARCHAR(80)  NOT NULL,
  pub_id CHAR(8)  NULL CONSTRAINT fkPublishers REFERENCES dbo.publishers,
  notes VARCHAR(200)  NULL,
  pubdate DATETIME NOT NULL
    CONSTRAINT pub_NowDefault DEFAULT (GetDate())
  ) ON [PRIMARY];
GO
DROP TABLE editions;
CREATE TABLE dbo.editions
  (
  Edition_id INT IDENTITY(1, 1) CONSTRAINT PK_editions PRIMARY KEY,
  publication_id dbo.tid CONSTRAINT fk_edition REFERENCES publications,
  Publication_type NVARCHAR(20) NOT NULL DEFAULT 'book',
  EditionDate DATETIME2 NOT NULL DEFAULT GetDate()
  );
GO

CREATE TABLE dbo.prices
  (
  Price_id INT IDENTITY(1, 1) CONSTRAINT PK_Prices PRIMARY KEY,
  Edition_id INT CONSTRAINT fk_prices REFERENCES editions,
  price dbo.Dollars NULL,
  advance dbo.Dollars NULL,
  royalty INT NULL,
  ytd_sales INT NULL,
  PriceStartDate DATETIME2 NOT NULL DEFAULT GetDate(),
  PriceEndDate DATETIME2 NULL
  );

CREATE TABLE dbo.Limbo
  (
  Soul_ID INT IDENTITY(1, 1),
  JSON NVARCHAR(MAX) NOT null,
  Version NOT NULL NVARCHAR(20),
  SourceName NOT NULL sysname,
  InsertionDate DATETIME2 NOT NULL DEFAULT GetDate()
  );

/* do the necessary data migrations.First store the old table */
IF not EXISTS (SELECT name FROM tempdb.sys.tables WHERE name LIKE '#titles%')
SELECT title_id, title, pub_id, price, advance, royalty, ytd_sales, notes,
  pubdate
  INTO #titles
  FROM titles;

INSERT INTO publications (Publication_id, title, pub_id, notes, pubdate)
  SELECT title_id, title, pub_id, notes, pubdate FROM #titles;

INSERT INTO editions (publication_id, Publication_type, EditionDate)
  SELECT title_id, 'book', pubdate FROM #titles;

INSERT INTO dbo.prices (Edition_id, price, advance, royalty, ytd_sales,
PriceStartDate, PriceEndDate)
  SELECT Edition_id, price, advance, royalty, ytd_sales, pubdate, NULL
    FROM #titles t
      INNER JOIN editions
        ON t.title_id = editions.publication_id;


ALTER TABLE dbo.sales DROP CONSTRAINT FK_salesTitles;
GO
ALTER TABLE dbo.sales
ADD CONSTRAINT FK_salesTitles FOREIGN KEY (title_id) REFERENCES dbo.publications
                                (Publication_id) ON DELETE CASCADE;
GO
ALTER TABLE dbo.roysched DROP CONSTRAINT FK_RoySchedTitles;
GO
ALTER TABLE dbo.roysched
ADD CONSTRAINT FK_RoySchedTitles FOREIGN KEY (title_id) REFERENCES dbo.publications
                                   (Publication_id) ON DELETE CASCADE;
GO
ALTER TABLE dbo.TagTitle DROP CONSTRAINT FKTitle_id;
GO
ALTER TABLE dbo.TagTitle
ADD CONSTRAINT FKTitle_id FOREIGN KEY (title_id) REFERENCES dbo.publications
                            (Publication_id) ON DELETE CASCADE;
GO
ALTER TABLE dbo.titleauthor DROP CONSTRAINT FK_TitleauthorTitles;
GO
ALTER TABLE dbo.titleauthor
ADD CONSTRAINT FK_TitleauthorTitles FOREIGN KEY (title_id) REFERENCES dbo.publications
                                      (Publication_id) ON DELETE CASCADE;
GO
DROP TABLE dbo.titles;