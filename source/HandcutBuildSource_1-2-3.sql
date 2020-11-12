USE master;
GO
/*if the database doesn't exist, then build it */
IF NOT EXISTS (SELECT databases.name FROM sys.databases WHERE databases.name LIKE 'pubsBuild')
  /* a fresh build of the old PUBS database from the Dark Ages, updated slightly  but
  still in the spirit of a simple practice database. This build script also inserts
  the data, taken where possible from the original */
 CREATE DATABASE PubsBuild;
GO

USE PubsBuild;
GO
--
SET NOEXEC OFF;
/*--The Tear-down Phase --*/

/* We start by mopping up. We test to see if objects exist and if
 necessary delete them*/
IF Object_Id('tempdb..#titles') IS NOT NULL DROP TABLE #titles

--delete the views and procedures
IF Object_Id('dbo.titleView') IS NOT NULL DROP VIEW dbo.titleview;
IF Object_Id('dbo.titles','v') IS NOT NULL DROP view dbo.titles;
IF Object_Id('dbo.ByRoyalty') IS NOT NULL DROP PROCEDURE dbo.byroyalty;
IF Object_Id('classic.titles') IS NOT NULL DROP VIEW classic.titles;
IF Object_Id('dbo.reptq1') IS NOT NULL DROP PROCEDURE dbo.reptq1;
IF Object_Id('dbo.reptq2') IS NOT NULL DROP PROCEDURE dbo.reptq2;
IF Object_Id('dbo.reptq3') IS NOT NULL DROP PROCEDURE dbo.reptq3;
IF Object_Id('dbo.TitlesFromTags') IS NOT NULL DROP function dbo.TitlesFromTags;

--delete the tables in order
IF Object_Id('dbo.employee') IS NOT NULL DROP TABLE dbo.employee;
IF Object_Id('dbo.roysched') IS NOT NULL DROP TABLE dbo.roysched;
IF Object_Id('dbo.sales') IS NOT NULL DROP TABLE dbo.sales;
IF Object_Id('dbo.pub_info') IS NOT NULL DROP TABLE dbo.pub_info;
IF Object_Id('dbo.titleauthor') IS NOT NULL DROP TABLE dbo.titleauthor;
IF Object_Id('dbo.discounts') IS NOT NULL DROP TABLE dbo.discounts;
IF Object_Id('dbo.TagTitle') IS NOT NULL DROP TABLE dbo.TagTitle;
IF Object_Id('dbo.Prices') IS NOT NULL DROP TABLE dbo.Prices;
IF Object_Id('dbo.editions') IS NOT NULL DROP TABLE dbo.Editions;
IF Object_Id('dbo.titles','u') IS NOT NULL DROP TABLE dbo.titles;
IF Object_Id('dbo.EditionType') IS NOT NULL DROP TABLE dbo.EditionType;
IF Object_Id('dbo.TagName') IS NOT NULL DROP TABLE dbo.TagName;
IF Object_Id('dbo.authors') IS NOT NULL DROP TABLE dbo.authors;
IF Object_Id('dbo.jobs') IS NOT NULL DROP TABLE dbo.jobs;
IF Object_Id('dbo.publications') IS NOT NULL DROP TABLE dbo.publications;
IF Object_Id('dbo.publishers') IS NOT NULL DROP TABLE dbo.publishers;
IF Object_Id('dbo.stores') IS NOT NULL DROP TABLE dbo.stores;
IF Object_Id('dbo.limbo') IS NOT NULL DROP TABLE dbo.limbo;

-- now we can drop the types
DROP TYPE IF EXISTS dbo.id;
DROP TYPE IF EXISTS dbo.tid;
DROP TYPE IF EXISTS dbo.empid;
DROP TYPE IF EXISTS dbo.dollars;

--and schema collections
IF EXISTS (SELECT * FROM sys.xml_schema_collections WHERE name = 'ObjectListParameter')
Drop XML SCHEMA COLLECTION ObjectListParameter

--finally, we drop schemas
IF EXISTS (SELECT schemas.name FROM sys.schemas WHERE schemas.name = 'classic')
  DROP SCHEMA classic;



-- and re-create types
CREATE TYPE dbo.Dollars FROM  NUMERIC(9, 2) NOT NULL;
CREATE TYPE dbo.id FROM NVARCHAR(11) NOT NULL;
CREATE TYPE dbo.tid FROM NVARCHAR(8) NOT NULL;
CREATE TYPE dbo.empid FROM CHAR(9) NOT NULL;

-- and schema collecion.
CREATE XML SCHEMA COLLECTION dbo.ObjectListParameter 
AS N'<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:element name="Object">
    <xsd:simpleType>
      <xsd:list itemType="xsd:string" />
    </xsd:simpleType>
  </xsd:element>
</xsd:schema>'
GO

/*--The (re)Build Phase --*/

GO
CREATE TABLE dbo.Limbo
/* this is used for rollback scripts if the current version has data 
that needs to be preserved but for which the version schema has no place
where it can be put. The data is inserted as JSON arrays */
  (
  Soul_ID INT IDENTITY(1, 1),
  JSON NVARCHAR(MAX) NOT null,
  Version NVARCHAR(20)  NOT NULL,
  SourceName sysname NOT NULL,
  InsertionDate DATETIME2 NOT NULL DEFAULT GetDate()
  );

/* table of book authors together with their phone numbers and addresses */
CREATE TABLE authors
  (
  au_id id
    CONSTRAINT CheckAu_ID_Numeric --
    CHECK (au_id LIKE '[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]') CONSTRAINT UPKCL_auidind PRIMARY KEY CLUSTERED,
  au_lname NVARCHAR(80) NOT NULL,
  au_fname NVARCHAR(40) NOT NULL,
  phone VARCHAR(12) NOT NULL CONSTRAINT PhoneNotKnown DEFAULT ('UNKNOWN'),
  address NVARCHAR(100) NULL,
  city NVARCHAR(40) NULL,
  state CHAR(2) NULL,
  zip CHAR(5) NULL CONSTRAINT checkZip --
                   CHECK (zip LIKE '[0-9][0-9][0-9][0-9][0-9]'),
  contract BIT NOT NULL
  );
GO

/* Table of publishers and their location */
CREATE TABLE dbo.publishers
(
pub_id char (8) COLLATE Latin1_General_CI_AS NOT NULL --
   CONSTRAINT UPKCL_pubind PRIMARY KEY CLUSTERED  (pub_id),
   CONSTRAINT GetPubidright CHECK ((pub_id='1756' OR pub_id='1622' OR pub_id='0877'
                                      OR pub_id='0736' OR pub_id='1389' OR pub_id like '99[0-9][0-9]')),
pub_name nvarchar (80) COLLATE Latin1_General_CI_AS NULL,
city nvarchar (40) COLLATE Latin1_General_CI_AS NULL,
state char (2) COLLATE Latin1_General_CI_AS NULL,
country varchar (30) COLLATE Latin1_General_CI_AS NULL CONSTRAINT godsOwnCountry DEFAULT ('USA')
)
GO

go
CREATE TABLE dbo.publications

/* Formerly the Titles table but it was split out
Contains titles, when published, who published them, when and notes */
(
Publication_id dbo.tid NOT NULL --
  CONSTRAINT PK_Publication PRIMARY KEY CLUSTERED  (Publication_id),
title varchar (80) COLLATE Latin1_General_CI_AS NOT NULL,
pub_id char (8) COLLATE Latin1_General_CI_AS NULL --
  CONSTRAINT fkPublishers FOREIGN KEY (pub_id) REFERENCES dbo.publishers (pub_id),
notes varchar (200) COLLATE Latin1_General_CI_AS NULL,
pubdate datetime NOT NULL CONSTRAINT pub_NowDefault DEFAULT (getdate())
)
GO

CREATE TABLE dbo.EditionType
/*basically a list of all the types of edition used in order to publish something */
(
TheType nvarchar (20) NOT NULL CONSTRAINT pk_EditionType PRIMARY KEY )
GO

CREATE TABLE dbo.editions
/*The editions that have been made for each title. The obvious one is a book, but there
will be others but each will have a different date of issue and price */
(
Edition_id int NOT NULL IDENTITY(1, 1),
publication_id dbo.tid NOT NULL,
PublicationName NVARCHAR(255) NULL,
Publication_type nvarchar (20) COLLATE Latin1_General_CI_AS NOT NULL DEFAULT ('book'),
EditionDate datetime2 NOT NULL DEFAULT (getdate()),
EditionReplacedDate Datetime2
)
GO
ALTER TABLE dbo.editions ADD CONSTRAINT PK_editions PRIMARY KEY CLUSTERED  (Edition_id)
GO
ALTER TABLE dbo.editions ADD CONSTRAINT fk_edition FOREIGN KEY (publication_id) REFERENCES dbo.publications (Publication_id)
GO
ALTER TABLE dbo.editions ADD CONSTRAINT FK_EditionType FOREIGN KEY (Publication_type) REFERENCES dbo.EditionType (TheType)
GO
;
CREATE TABLE dbo.prices
/*each edition weill have only one current price but may have several historical prices
the end-date of one shouldn't overlap the start date of any other. */
(
Price_id int NOT NULL  IDENTITY(1, 1) 
  CONSTRAINT PK_Prices PRIMARY KEY CLUSTERED  (Price_id),
Edition_id int NOT NULL --
  CONSTRAINT fk_prices FOREIGN KEY (Edition_id) REFERENCES dbo.editions (Edition_id),
name NVARCHAR(80) NULL,
price dbo.Dollars NOT NULL,
advance dbo.Dollars NULL,
royalty int NULL,
ytd_sales int NULL,
PriceStartDate datetime2 NOT NULL DEFAULT (getdate()),
PriceEndDate datetime2 NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
Create view dbo.titles
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

GO
/* the unique collection of types of book, with one primary tag, showing where
they should be displayed. No book can have more than one tag and should have at
least one.*/
CREATE TABLE TagName --
  (TagName_ID INT IDENTITY(1, 1) CONSTRAINT TagnameSurrogate PRIMARY KEY, 
     Tag VARCHAR(20) NOT NULL CONSTRAINT Uniquetag UNIQUE);

GO
CREATE TABLE dbo.TagTitle
(
TagTitle_ID int NOT NULL IDENTITY(1, 1),
title_id dbo.tid NOT NULL,
Is_Primary bit NOT NULL CONSTRAINT NotPrimary DEFAULT ((0)),
TagName_ID int NOT NULL
)
GO
ALTER TABLE dbo.TagTitle ADD CONSTRAINT PK_TagNameTitle PRIMARY KEY CLUSTERED  (title_id, TagName_ID)
GO
ALTER TABLE dbo.TagTitle ADD CONSTRAINT fkTagname FOREIGN KEY (TagName_ID) REFERENCES dbo.TagName (TagName_ID)
GO
ALTER TABLE dbo.TagTitle ADD CONSTRAINT FKTitle_id FOREIGN KEY (title_id) REFERENCES dbo.publications (Publication_id) ON DELETE CASCADE
GO
;

/* relationship table allowing more than one author per book, each author
being allowed a different royalty percentage, and a different order in the 
list */
CREATE TABLE dbo.titleauthor
(
au_id dbo.id NOT NULL,
title_id dbo.tid NOT NULL,
au_ord tinyint NULL,
royaltyper int NULL
)
GO
ALTER TABLE dbo.titleauthor ADD CONSTRAINT UPKCL_taind PRIMARY KEY CLUSTERED  (au_id, title_id)
GO
CREATE NONCLUSTERED INDEX auidind ON dbo.titleauthor (au_id)
GO
CREATE NONCLUSTERED INDEX titleidind ON dbo.titleauthor (title_id)
GO
ALTER TABLE dbo.titleauthor ADD CONSTRAINT FK_TitleauthorAuthors FOREIGN KEY (au_id) REFERENCES dbo.authors (au_id)
GO
ALTER TABLE dbo.titleauthor ADD CONSTRAINT FK_TitleauthorTitles FOREIGN KEY (title_id) REFERENCES dbo.publications (Publication_id) ON DELETE CASCADE
GO
;

GO
/*  stores that are known to order copies of the publications */
CREATE TABLE stores
  (
  stor_id CHAR(8) NOT NULL CONSTRAINT UPK_storeid PRIMARY KEY CLUSTERED,
  stor_name NVARCHAR(80) NULL,
  stor_address NVARCHAR(80) NULL,
  city NVARCHAR(40) NULL,
  state CHAR(2) NULL,
  zip CHAR(5) NULL
  );

GO
/*  record of sales to book stores. These are for each publication but only for books */
CREATE TABLE dbo.sales
(
stor_id char (8) COLLATE Latin1_General_CI_AS NOT NULL,
ord_num nvarchar (40) COLLATE Latin1_General_CI_AS NOT NULL,
ord_date datetime NOT NULL,
qty smallint NOT NULL,
payterms varchar (12) COLLATE Latin1_General_CI_AS NOT NULL,
Publication_id dbo.tid NOT NULL
)
GO
ALTER TABLE dbo.sales ADD CONSTRAINT UPKCL_sales PRIMARY KEY CLUSTERED  (stor_id, ord_num, Publication_id)
GO
CREATE NONCLUSTERED INDEX titleidind ON dbo.sales (publication_id)
GO
ALTER TABLE dbo.sales ADD CONSTRAINT FK_salesStores FOREIGN KEY (stor_id) REFERENCES dbo.stores (stor_id)
GO
ALTER TABLE dbo.sales ADD CONSTRAINT FK_salesTitles FOREIGN KEY (Publication_id) REFERENCES dbo.publications (Publication_id) ON DELETE CASCADE
GO
;

GO
/* the schedule of royalties for individual books */
CREATE TABLE dbo.roysched
(
title_id dbo.tid NOT NULL,
lorange int NULL,
hirange int NULL,
royalty int NULL
)
GO
CREATE NONCLUSTERED INDEX titleidind ON dbo.roysched (title_id)
GO
ALTER TABLE dbo.roysched ADD CONSTRAINT FK_RoySchedTitles FOREIGN KEY (title_id) REFERENCES dbo.publications (Publication_id) ON DELETE CASCADE
GO
;

GO

CREATE TABLE discounts
  (
  discounttype NVARCHAR(80) NOT NULL,
  stor_id CHAR(8) NULL CONSTRAINT FK_DiscountsStore --
                       FOREIGN KEY REFERENCES dbo.stores (stor_id),
  lowqty SMALLINT NULL,
  highqty SMALLINT NULL,
  discount DEC(4, 2) NOT NULL
  );

GO
/*This table specifies the salary range for the various jobs for employees*/
CREATE TABLE jobs
  (
  Job_id INT IDENTITY(1,1) CONSTRAINT JobsKey PRIMARY KEY,
  job_desc VARCHAR(50) NOT NULL
    CONSTRAINT UndecidedJobDesc DEFAULT 'New Position - title not formalized yet',
  min_lvl TINYINT NOT NULL CONSTRAINT UndecidedMinSalary CHECK (min_lvl >= 10),
  max_lvl TINYINT NOT NULL CONSTRAINT UndecidedMaxSalary CHECK (max_lvl <= 250)
  
  );

GO
/* extra info about each publisher */
CREATE TABLE dbo.pub_info
(
pub_id char (8) COLLATE Latin1_General_CI_AS NOT NULL,
logo varbinary (max) NULL,
pr_info nvarchar (max) COLLATE Latin1_General_CI_AS NULL
)
GO
ALTER TABLE dbo.pub_info ADD CONSTRAINT UPKCL_pubinfo PRIMARY KEY CLUSTERED  (pub_id)
GO
ALTER TABLE dbo.pub_info ADD CONSTRAINT FK_Pub_infoPublishers FOREIGN KEY (pub_id) REFERENCES dbo.publishers (pub_id)
GO
;

GO
/* employee information for each publisher */
CREATE TABLE dbo.employee
(
emp_id dbo.empid NOT NULL,
fname nvarchar (40) COLLATE Latin1_General_CI_AS NOT NULL,
minit char (1) COLLATE Latin1_General_CI_AS NULL,
lname varchar (30) COLLATE Latin1_General_CI_AS NOT NULL,
job_id int NOT NULL CONSTRAINT LetsMakeItOne DEFAULT ((1)),
job_lvl tinyint NULL CONSTRAINT DefaultToTen DEFAULT ((10)),
pub_id char (8) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT HighNumber DEFAULT ('9952'),
hire_date datetime NOT NULL CONSTRAINT CouldBeToday DEFAULT (getdate())
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER dbo.employee_insupd
ON dbo.employee
FOR INSERT, UPDATE
AS
--Get the range of level for this job type from the jobs table.
DECLARE @min_lvl TINYINT, @max_lvl TINYINT, @emp_lvl TINYINT, @job_id SMALLINT;
SELECT @min_lvl = j.min_lvl, @max_lvl = j.max_lvl, @emp_lvl = i.job_lvl,
  @job_id = i.job_id
  FROM dbo.employee AS e
    INNER JOIN inserted AS i
      ON e.emp_id = i.emp_id
    INNER JOIN dbo.jobs AS j
      ON i.job_id = j.job_id;
IF (@job_id = 1) AND (@emp_lvl <> 10)
  BEGIN
    RAISERROR('Job id 1 expects the default level of 10.', 16, 1);
    ROLLBACK TRANSACTION;
  END;
ELSE IF NOT (@emp_lvl BETWEEN @min_lvl AND @max_lvl)
       BEGIN
         RAISERROR(
                    'The level for job_id:%d should be between %d and %d.',
                    16,
                    1,
                    @job_id,
                    @min_lvl,
                    @max_lvl
                  );
         ROLLBACK TRANSACTION;
       END;

GO
ALTER TABLE dbo.employee ADD CONSTRAINT CK_emp_id CHECK ((emp_id like '[A-Z][A-Z][A-Z][1-9][0-9][0-9][0-9][0-9][FM]' OR emp_id like '[A-Z]-[A-Z][1-9][0-9][0-9][0-9][0-9][FM]'))
GO
ALTER TABLE dbo.employee ADD CONSTRAINT PK_emp_id PRIMARY KEY NONCLUSTERED  (emp_id)
GO
CREATE CLUSTERED INDEX employee_ind ON dbo.employee (lname, fname, minit)
GO
ALTER TABLE dbo.employee ADD CONSTRAINT FK_EmployeeJobs FOREIGN KEY (job_id) REFERENCES dbo.jobs (Job_id)
GO
ALTER TABLE dbo.employee ADD CONSTRAINT FK_EmployeePublishers FOREIGN KEY (pub_id) REFERENCES dbo.publishers (pub_id)
GO

CREATE NONCLUSTERED INDEX aunmind ON dbo.authors (au_lname, au_fname);
GO


PRINT 'Now at the create view section ....';

GO

CREATE VIEW titleview
AS
SELECT t.title, ta.au_ord, a.au_lname, t.price, t.ytd_sales, t.pub_id
  FROM dbo.authors AS a
    INNER JOIN dbo.titleauthor AS ta
      ON a.au_id = ta.au_id
    INNER JOIN dbo.titles AS t
      ON t.title_id = ta.title_id;

GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


PRINT 'Now at the create procedure section ....';

GO

CREATE PROCEDURE byroyalty @percentage INT
AS
  BEGIN
    SELECT titleauthor.au_id
      FROM dbo.titleauthor AS titleauthor
      WHERE titleauthor.royaltyper = @percentage;
  END;
GO

CREATE PROCEDURE reptq1
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

CREATE PROCEDURE dbo.reptq2
AS
  BEGIN
    SELECT CASE WHEN Grouping(TN.tag) = 1 THEN 'ALL' ELSE TN.Tag END AS type,
      CASE WHEN Grouping(titles.pub_id) = 1 THEN 'ALL' ELSE titles.pub_id END AS pub_id,
      Avg(titles.ytd_sales) AS avg_ytd_sales
      FROM dbo.titles AS titles
        INNER JOIN dbo.TagTitle AS TagTitle
          ON TagTitle.title_id = titles.title_id
        INNER JOIN dbo.TagName AS TN
          ON TN.TagName_ID = TagTitle.TagName_ID
      WHERE titles.pub_id IS NOT NULL AND TagTitle.Is_Primary = 1
      GROUP BY titles.pub_id, TN.Tag WITH ROLLUP;
  END;

GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE PROCEDURE dbo.reptq3 @lolimit dbo.Dollars, @hilimit dbo.Dollars,
  @type CHAR(12)
AS
  BEGIN
    SELECT CASE WHEN Grouping(titles.pub_id) = 1 THEN 'ALL' ELSE titles.pub_id END AS pub_id,
      CASE WHEN Grouping(TN.tag) = 1 THEN 'ALL' ELSE TN.Tag END AS type,
      Count(titles.title_id) AS cnt
      FROM dbo.titles AS titles
        INNER JOIN dbo.TagTitle AS TagTitle
          ON TagTitle.title_id = titles.title_id
        INNER JOIN dbo.TagName AS TN
          ON TN.TagName_ID = TagTitle.TagName_ID
      WHERE titles.price > @lolimit
        AND TagTitle.Is_Primary = 1
        AND titles.price < @hilimit
        AND TN.Tag = @type
         OR TN.Tag LIKE '%cook%'
      GROUP BY titles.pub_id, TN.Tag WITH ROLLUP;
  END;
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_NULLS ON
GO
CREATE FUNCTION dbo.TitlesFromTags
/**
Summary: >
 List out the title with one or more of a list of tags
Author: Phil Factor
Date: 16/07/2020
Database: Pubs
Examples:
   - Select * from TitlesFromTags('business,psychology')
   - Select top 100 percent stuff
Returns: >
  nothing
**/
(
     @CategoryList nvarchar(500)
)
RETURNS @returntable TABLE 
(
tag VARCHAR(20), title VARCHAR(80), price NUMERIC(9,2), notes VARCHAR(200) , title_id NVARCHAR(8) 
)
AS 
	BEGIN
    Declare @Separator varchar(10) =',',
	 @XMLList XML = NULL
 SELECT @XMLlist='<list><y>'+replace(@CategoryList,@Separator,'</y><y>')+'</y></list>';
 INSERT INTO @returntable
 		Select tagname.tag, title, price, notes, titles.title_id 
		FROM dbo.TagName
		INNER JOIN dbo.TagTitle ON TagTitle.TagName_ID = TagName.TagName_ID
		INNER JOIN dbo.titles ON titles.title_id = TagTitle.title_id
        INNER JOIN (   SELECT x.y.value('.','varchar(80)') AS IDs
              FROM @XMLList.nodes('/list/y/text()') AS x ( y )
           )  as Wanted_Tags(Tag) 
         ON tagname.tag =  Wanted_Tags.Tag
		return
 END
GO
IF EXISTS  (SELECT * FROM sys.extended_properties WHERE name='Database_info' AND major_id=0 AND minor_id=0)
  EXEC sp_dropextendedproperty N'Database_Info', NULL, NULL, NULL, NULL, NULL, NULL


EXEC sp_addextendedproperty N'Database_Info', N'[{"Name":"Pubs","Version":"1.2.2","Description":"The Pubs (publishing) Database supports a fictitious publisher.","Modified":"2020-06-05T15:28:19.100","by":"sa"}]', NULL, NULL, NULL, NULL, NULL, NULL
GO

INSERT authors
VALUES
( N'172-32-1176', N'White', N'Johnson', '408 496-7223', N'10932 Bigge Rd.', N'Menlo Park', 'CA', '94025', 1 ), 
( N'213-46-8915', N'Green', N'Marjorie', '415 986-7020', N'309 63rd St. #411', N'Oakland', 'CA', '94618', 1 ), 
( N'238-95-7766', N'Carson', N'Cheryl', '415 548-7723', N'589 Darwin Ln.', N'Berkeley', 'CA', '94705', 1 ), 
( N'267-41-2394', N'O''Leary', N'Michael', '408 286-2428', N'22 Cleveland Av. #14', N'San Jose', 'CA', '95128', 1 ), 
( N'274-80-9391', N'Straight', N'Dean', '415 834-2919', N'5420 College Av.', N'Oakland', 'CA', '94609', 1 ), 
( N'341-22-1782', N'Smith', N'Meander', '913 843-0462', N'10 Mississippi Dr.', N'Lawrence', 'KS', '66044', 0 ), 
( N'409-56-7008', N'Bennet', N'Abraham', '415 658-9932', N'6223 Bateman St.', N'Berkeley', 'CA', '94705', 1 ), 
( N'427-17-2319', N'Dull', N'Ann', '415 836-7128', N'3410 Blonde St.', N'Palo Alto', 'CA', '94301', 1 ), 
( N'472-27-2349', N'Gringlesby', N'Burt', '707 938-6445', N'PO Box 792', N'Covelo', 'CA', '95428', 1 ), 
( N'486-29-1786', N'Locksley', N'Charlene', '415 585-4620', N'18 Broadway Av.', N'San Francisco', 'CA', '94130', 1 ), 
( N'527-72-3246', N'Greene', N'Morningstar', '615 297-2723', N'22 Graybar House Rd.', N'Nashville', 'TN', '37215', 0 ), 
( N'648-92-1872', N'Blotchet-Halls', N'Reginald', '503 745-6402', N'55 Hillsdale Bl.', N'Corvallis', 'OR', '97330', 1 ), 
( N'672-71-3249', N'Yokomoto', N'Akiko', '415 935-4228', N'3 Silver Ct.', N'Walnut Creek', 'CA', '94595', 1 ), 
( N'712-45-1867', N'del Castillo', N'Innes', '615 996-8275', N'2286 Cram Pl. #86', N'Ann Arbor', 'MI', '48105', 1 ), 
( N'722-51-5454', N'DeFrance', N'Michel', '219 547-9982', N'3 Balding Pl.', N'Gary', 'IN', '46403', 1 ), 
( N'724-08-9931', N'Stringer', N'Dirk', '415 843-2991', N'5420 Telegraph Av.', N'Oakland', 'CA', '94609', 0 ), 
( N'724-80-9391', N'MacFeather', N'Stearns', '415 354-7128', N'44 Upland Hts.', N'Oakland', 'CA', '94612', 1 ), 
( N'756-30-7391', N'Karsen', N'Livia', '415 534-9219', N'5720 McAuley St.', N'Oakland', 'CA', '94609', 1 ), 
( N'807-91-6654', N'Panteley', N'Sylvia', '301 946-8853', N'1956 Arlington Pl.', N'Rockville', 'MD', '20853', 1 ), 
( N'846-92-7186', N'Hunter', N'Sheryl', '415 836-7128', N'3410 Blonde St.', N'Palo Alto', 'CA', '94301', 1 ), 
( N'893-72-1158', N'McBadden', N'Heather', '707 448-4982', N'301 Putnam', N'Vacaville', 'CA', '95688', 0 ), 
( N'899-46-2035', N'Ringer', N'Anne', '801 826-0752', N'67 Seventh Av.', N'Salt Lake City', 'UT', '84152', 1 ), 
( N'998-72-3567', N'Ringer', N'Albert', '801 826-0752', N'67 Seventh Av.', N'Salt Lake City', 'UT', '84152', 1 )


GO

RAISERROR('Now at the inserts to publishers ....', 0, 1);

GO

INSERT publishers VALUES
( '0736    ', N'New Moon Books', N'Boston', 'MA', 'USA' ), 
( '0877    ', N'Binnet & Hardley', N'Washington', 'DC', 'USA' ), 
( '1389    ', N'Algodata Infosystems', N'Berkeley', 'CA', 'USA' ), 
( '1622    ', N'Five Lakes Publishing', N'Chicago', 'IL', 'USA' ), 
( '1756    ', N'Ramona Publishers', N'Dallas', 'TX', 'USA' ), 
( '9901    ', N'GGG&G', N'M?nchen', NULL, 'Germany' ), 
( '9952    ', N'Scootney Books', N'New York', 'NY', 'USA' ), 
( '9999    ', N'Lucerne Publishing', N'Paris', NULL, 'France' )

GO

RAISERROR('Now at the inserts to pub_info ....', 0, 1);

GO

INSERT pub_info
VALUES
  ('0736',
0x474946383961D3001F00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000D3001F004004FFF0C949ABBD38EBCDBBFF60288E245001686792236ABAB03BC5B055B3F843D3B99DE2AB532A36FB15253B19E5A6231A934CA18CB75C1191D69BF62AAD467F5CF036D8243791369F516ADEF9304AF8F30A3563D7E54CFC04BF24377B5D697E6451333D8821757F898D8E8F1F76657877907259755E5493962081798D9F8A846D9B4A929385A7A5458CA0777362ACAF585E6C6A84AD429555BAA9A471A89D8E8BA2C3C7C82DC9C8AECBCECF1EC2D09143A66E80D3D9BC2C41D76AD28FB2CD509ADAA9AAC62594A3DF81C65FE0BDB5B0CDF4E276DEF6DD78EF6B86FA6C82C5A2648A54AB6AAAE4C1027864DE392E3AF4582BF582DFC07D9244ADA2480BD4C6767BFF32AE0BF3EF603B3907490A4427CE21A7330A6D0584B810664D7F383FA25932488FB96D0F37BDF9491448D1A348937A52CAB4A9D3784EF5E58B4A5545D54BC568FABC9A68DD526ED0A6B8AA17331BD91E5AD9D1D390CED23D88F54A3ACB0A955ADDAD9A50B50D87296E3EB9C76A7CDAABC86B2460040DF34D3995515AB9FF125F1AFA0DAB20A0972382CCB9F9E5AEBC368B21EEDB66EDA15F1347BE2DFDEBB44A7B7C6889240D9473EB73322F4E8D8DBBE14D960B6519BCE5724BB95789350E97EA4BF3718CDD64068D751A261D8B1539D6DCDE3C37F68E1FB58E5DCED8A44477537049852EFD253CEE38C973B7E9D97A488C2979FB936FBAFF2CF5CB79E35830400C31860F4A9BE925D4439F81B6A073BEF1575F593C01A25B26127255D45D4A45B65B851A36C56154678568A20E1100003B,
'This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.

This is sample text data for New Moon Books, publisher 0736 in the pubs database. New Moon Books is located in Boston, Massachusetts.');

INSERT pub_info
VALUES
  ('0877',
0x4749463839618B002F00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C000000008B002F004004FFF0C949ABBD38EBCDBBFFA0048464089CE384A62BD596309CC6F4F58A287EBA79ED73B3D26A482C1A8FC8A47249FCCD76BC1F3058D94135579C9345053D835768560CFE6A555D343A1B6D3FC6DC2A377E66DBA5F8DBEBF6EEE1FF2A805B463A47828269871F7A3D7C7C8A3E899093947F666A756567996E6C519E167692646E7D9C98A42295ABAC24A092AD364C737EB15EB61B8E8DB58FB81DB0BE8C6470A0BE58C618BAC365C5C836CEA1BCBBC4C0D0AAD6D14C85CDD86FDDDFAB5F43A580DCB519A25B9BAE989BC3EEA9A7EBD9BF54619A7DF8BBA87475EDA770D6C58B968C59A27402FB99E2378FC7187010D5558948B15CC58B4E20CE9A762E62B558CAB86839FC088D24AB90854662BCD60D653E832BBD7924F49226469327FDEC91C6AD2538972E6FFEE429720D4E63472901251A33A9D28DB47A5A731A7325D56D50B36ADDAA2463D5AF1EAE82F5F84FAA946656AA21AC31D0C4BF85CBA87912D6D194D4B535C5DDDBA93221CB226D022E9437D89C594305FD321C0CB7DFA5C58223036E088F3139B9032563DD0BE66D2ACD8B2BCB9283CEDEE3C6A53EE39BA7579A62C1294917DC473035E0B9E3183F9A3BB6F7ABDE608B018800003B,
'This is sample text data for Binnet & Hardley, publisher 0877 in the pubs database. Binnet & Hardley is located in Washington, D.C.

This is sample text data for Binnet & Hardley, publisher 0877 in the pubs database. Binnet & Hardley is located in Washington, D.C.

This is sample text data for Binnet & Hardley, publisher 0877 in the pubs database. Binnet & Hardley is located in Washington, D.C.

This is sample text data for Binnet & Hardley, publisher 0877 in the pubs database. Binnet & Hardley is located in Washington, D.C.

This is sample text data for Binnet & Hardley, publisher 0877 in the pubs database. Binnet & Hardley is located in Washington, D.C.');

INSERT pub_info
VALUES
  ('1389',
0x474946383961C2001D00B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000C2001D004004FFF0C949ABBD38EBCDBBFF60288E1C609E2840AE2C969E6D2CCFB339D90F2CE1F8AEE6BC9FEF26EC01413AA3F2D76BAA96C7A154EA7CC29C449AC7A8ED7A2FDC2FED25149B29E4D479FD55A7CBD931DC35CFA4916171BEFDAABC51546541684C8285847151537F898A588D89806045947491757B6C9A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A95A6A3E64169923B0901A775B7566B25D7F8C888A5150BE7B8F93847D8DC3C07983BEBDC1878BCFAF6F44BBD0AD71C9CBD653BFD5CEC7D1C3DFDB8197D8959CB9AAB8B7EBEEEFF0BA92F1B6B5F4A0F6F776D3FA9EBCFD748C01DCB4AB5DBF7C03CF1454070F61423D491C326BA18E211081250C7AB12867619825F37F2ECE1168AC242B6A274556D121D28FA46C11E78564C5B295308F21BBF5CAD6CCE52C7018813932C4ED5C517346B7C1C2683368349D49A19D0439D31538A452A916135A0B19A59AAB9E6A835A0EABD00E5CD11D1D478C1C59714053AA4C4955AB4B9956879AB497F62E1CBA2373DA25B752239F8787119390AB5806C74E1100003B,
'This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.

This is sample text data for Algodata Infosystems, publisher 1389 in the pubs database. Algodata Infosystems is located in Berkeley, California.');

INSERT pub_info
VALUES
  ('1622',
0x474946383961F5003400B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000F50034004004FFF0C949ABBD38EBCDBBFF60288E64D90166AA016CEBBEB02ACF746D67E82DC2ACEEFFC0A02997B31027C521EF25698D8E42230E049D3E8AD8537385BC4179DB6B574C26637BE58BF38A1EB393DF2CE55CA52731F77918BE9FAFCD6180817F697F5F6E6C7A836D62876A817A79898A7E31524D708E7299159C9456929F9044777C6575A563A68E827D9D4C8D334BB3B051B6B7B83A8490B91EB4B3BDC1C251A1C24BC3C8C9C8C5C4BFCCCAD0D135ACC36B2E3BBCB655AD1CDB8F6921DEB8D48AA9ADA46046D7E0DC829B9D98E9988878D9AAE5AEF875BC6DEFF7E7A35C9943F18CCA3175C0A4295C48625F3B8610234A0C17D159C289189515CC7531A3C7891BFF9B59FA4812634820F24AAA94882EA50D8BBB3E8813598B8A3D7C0D6F12CB8710E5BA7536D9ED3C458F8B509CF17CE94CEA658F254D944889528306E83C245089629DDA4F8BD65885049ACBB7ADAB2A5364AFDAF344902752409A6085FA39105EBB3C2DAB2E52FA8611B7ACFA060956CB1370598176DB3E74FB956CCCA77207BB6B8CAAAADEA3FFBE01A48CD871D65569C37E25A458C5C9572E57AADE59F7F40A98B456CB36560F730967B3737B74ADBBB7EFDABF830BE70B11F6C8E1C82F31345E33B9F3A5C698FB7D4E9D779083D4B313D7985ABB77E0C9B07F1F0F3EFA71F2E8ED56EB98BEBD7559306FC72C6995EA7499F3B5DDA403FF17538AB6FD20C9FF7D463D531681971888E0104E45069D7C742D58DB7B29B45454811B381420635135B5D838D6E487612F876D98D984B73D2820877DFD871523F5E161D97DD7FCB4C82E31BEC8176856D9D8487D95E1E5D711401AE2448EF11074E47E9D69359382E8A8871391880C28E5861636399950FEFCA55E315D8279255C2C6AA89899B68588961C5B82C366693359F1CA89ACACB959971D76F6E6607B6E410E9D57B1A9196A52BDD56636CC08BA519C5E1EDA8743688906DA9D53F2E367999656A96292E2781397A6264E62A04E25FE49A59354696958409B11F527639DEAC84E7795553A9AACA85C68E8977D2A7919A5A7F83329A46F0D79698BF60D98688CCC118A6C3F8F38E6D89C8C12F635E49145F6132D69DCCE684725FC0546C3B40875D79E70A5867A8274E69E8BAEAC1FEEC02E92EE3AA7ADA015365BEFBE83F2EB6F351100003B,
'This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.

This is sample text data for Five Lakes Publishing, publisher 1622 in the pubs database. Five Lakes Publishing is located in Chicago, Illinois.');

INSERT pub_info
VALUES
  ('1756',
0x474946383961E3002500B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000E30025004004FFF0C949ABBD38EBCDBBFF60288E240858E705A4D2EA4E6E0CC7324DD1EB9CDBBAFCE1AC878DE7ABBD84476452C963369F2F288E933A595B404DB27834E67A5FEC37ACEC517D4EB24E5C8D069966361A5E8ED3C3DCA5AA54B9B2AE2D423082817F848286898386858754887B8A8D939094947E918B7D8780959E9D817C18986FA2A6A75A7B22A59B378E1DACAEB18F1940B6A8B8A853727AB5BD4E76676A37BFB9AF2A564D6BC0776E635BCE6DCFD2C3C873716879D4746C6053DA76E0DAB3A133D6D5B290929F9CEAEDEB6FA0C435EF9E97F59896EC28EEFA9DFF69A21C1BB4CA1E3E63084DB42B970FD6407D05C9E59298B0A2C58B18337AA0E88DA3468DC3FFD0692187A7982F5F2271B152162DE54795CEB0F0DAF8EBDA2A932F1FF203B38C484B6ED07674194ACD639679424B4EDB36279B4D3852FE1095266743955138C5209ADA6D5CB26DCDFC644DD351EACF804BCD32421A562DB6965F25AADD11B056BD7BA436C903E82A1D4A3D024769BAE777B0BB7887F51A0E022E9589BCFCE0DD6527597223C4917502ACBCF8D5E6C49F0B6FA60751A7C2748A3EE7DD6B70B5628F9A5873C6DB5936E57EB843C726043B95EBDE394F3584EC7096ED8DA60D86001EBCB9F3E72F99439F0E7DEC7297BA84D9924EFDB11A65566B8EFB510C7CC258DBB7779F7834A9756E6C97D114F95E5429F13CE5F7F9AAF51C996928604710FF544AFDC79717C10CD85157C6EDD75F7EB49C81D45C5EA9674E5BBBA065941BFB45F3D62D5E99E11488516568A15D1292255F635E8045E0520F3E15A0798DB5C5A08105EE52E3884C05255778E6F5C4A287CCB4D84D1D41CE08CD913C56656482EAEDE8E38D71B974553C199EC324573C3669237C585588E52D1ACE049F85521648659556CD83445D27C9F4D68501CE580E31748ED4948C0E3E88959B257C87E39D0A8EC5D812559234996A9EE5B6E864FE31BA5262971DE40FA5B75D9A487A9A79975C6AB5DD06EA6CCA9DB94FA6A1568AD8A4C33DBA6A5995EE5450AC0AA24A9C6DBAE9F6883CB48976D0ABA8D90AA9A88D6246C2ABA3FE8A1B43CA229B9C58AFC11E071AB1D1BE366DB5C9AE85DCA48595466B83AC95C61DA60D1146EEB3BB817ADA40A08CFBDBB2EB9972EB6EDB66D26D71768D5B2B1FEFC65B11AFA5FA96C93AF50AA6AFBEFE263C1DC0FCA2AB8AC210472C310A1100003B,
'This is sample text data for Ramona Publishers, publisher 1756 in the pubs database. Ramona Publishers is located in Dallas, Texas.');

INSERT pub_info
VALUES
  ('9901',
0x4749463839615D002200B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C000000005D0022004004FFF0C949ABBD38EBCDFB03DF078C249895A386AA68BB9E6E0ACE623ABD1BC9E9985DFFB89E8E366BED782C5332563ABA4245A6744AAD5AAF4D2276CBED5EA1D026C528B230CD38B2C92721D78CC4772526748F9F611EB28DE7AFE25E818283604A1E8788898A7385838E8F55856F6C2C1D86392F6B9730708D6C5477673758A3865E92627E94754E173697A6A975809368949BB2AE7B9A6865AA734F80A2A17DA576AA5BB667C290CDCE4379CFD2CE9ED3D6A7CCD7DAA4D9C79341C8B9DF5FC052A8DEBA9BB696767B9C7FD5B8BBF23EABB9706BCAE5F05AB7E6C4C7488DDAF7251BC062530EFE93638C5B3580ECD4951312C217C425E73E89D38709D79D810D393BD20A528CE0AA704AA2D4D3082E583C89BD2C2D720753E1C8922697D44CF6AE53BF6D4041750B4AD467C54548932A1D7374A9D3A789004400003B,
'This is sample text data for GGG&G, publisher 9901 in the pubs database. GGG&G is located in Mï¿½nchen, Germany.');

INSERT pub_info
VALUES
  ('9952',
0x47494638396107012800B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000070128004004FFF0C949ABBD38EBCDBBFF60288E6469660005AC2C7BB56D05A7D24C4F339E3F765FC716980C3824F28418E4D1A552DA8ACCA5517A7B526F275912690D2A9BD11D14AB8B8257E7E9776BDEE452C2279C47A5CBEDEF2B3C3FBF9FC85981821D7D76868588878A898C8B838F1C8D928E733890829399949B979D9E9FA074A1A3A4A5A6A7458F583E69803F53AF4C62AD5E6DB13B6B3DAEAC6EBA64B365B26BB7ABBEB5C07FB428BCC4C8C1CCC7BBB065637C7A9B7BBE8CDADBDA8B7C31D9E1D88E2FA89E9AE9E49AE7EDA48DA2EEF2F3F4F597AEF6F9FAFBFC805D6CD28C0164C64D18BE3AAD88D87AA5C1DBC07FD59CE54293F0E0882AC39ED9CA2886E3308FB3FF262EBC726D591823204F2E0C09A4A3B32CFEACBC24198D86C48FD3E208D43832E3C0671A2D89737167281AA333219AC048D061499A3C83BEC8090BD84E5A99DE808B730DE9516B727CE85AE7C122BF73EAD29255CB76ADDBB6EC549C8504F7AD5DB37343A98D97576EDDBF7CFB0AEE8457EF5D4E83132BAEB1B8B1E3C749204B9EACB830E5CB984DE1F339A4E1CC88C93CB7D989D72234D1D3A672FEF85055C483C80A06742ADB664F3563119E417D5A8F52DFB1512AEC5D82E9C8662A477FB19A72B6F2E714413F8D0654AA75A8C4C648FDBC346ACDCD5487AFC439BE8BC8E8AA7F6BD77D2B7DF4E6C5882E57DFBDE2F56AEE6D87DFB8BFE06BE7E8F1C6CBCE4D2DC15751803C5956567EFA1D47A041E5F1176183CC1D571D21C2850396565CF5B1D5571D8AC21D08E099A15E85269E87207B1736B31E6FE620324E582116F5215178C86763518A9068DF7FE8C9C6207DCD0104A47B6B717388901EFA27238E3482454E43BB61E8D388F7FD44DD32473E79D43A527633232561E6F86536660256891699D175989A6F1A020A9C75C9D5E68274C619D79D91B5C5189F7906CA67297129D88F9E881A3AA83E8AB623E85E8B0EDAE89C892216E9A584B80318A69C7E3269A7A046FA69A8A4B6094004003B,
'This is sample text data for Scootney Books, publisher 9952 in the pubs database. Scootney Books is located in New York City, New York.');

INSERT pub_info
VALUES
  ('9999',
0x474946383961A9002400B30F00000000800000008000808000000080800080008080808080C0C0C0FF000000FF00FFFF000000FFFF00FF00FFFFFFFFFF21F9040100000F002C00000000A90024004004FFF0C949ABBD38EBCDBBFF60F8011A609E67653EA8D48A702CCFF44566689ED67CEFFF23D58E7513B686444A6EA26B126FC8E74AC82421A7ABE5F4594D61B7BBF0D6F562719A68A07ACDC6389925749AFC6EDBEFBCA24D3E96E2FF803D7A1672468131736E494A8B5C848D8633834B916E598B657E4A83905F7D9B7B56986064A09BA2A68D63603A2E717C9487B2B3209CA7AD52594751B4BD80B65D75B799BEC5BFAF7CC6CACB6638852ACC409F901BD33EB6BCCDC1D1CEA9967B23C082C3709662A69FA4A591E7AE84D87A5FA0AB502F43AC5D74EB9367B0624593FA5CB101ED144173E5F4315AE8485B4287FCBE39E446B1624173FEAC59DC2809594623D9C3388A54E4ACD59C642353E2F098E919319530DD61C405C7CBCB9831C5E5A2192C244E983A3FFE1CDA21282CA248ABB18C25336952A389D689E489B0D24483243B66CD8775A315801AA5A60A6B2DAC074E3741D6BBA8902BA687E9A6D1A3B6D6D15C7460C77AA3E3E556D79EBAF4AAAAB2CFCF578671DFDE657598305D51F7BE5E5A25361ED3388EED0A84B2B7535D6072C1D62DB5588BE5CCA5B1BDA377B99E3CBE9EDA31944A951ADF7DB15263A1429B37BB7E429D8EC4D754B87164078F2B87012002003B,
'This is sample text data for Lucerne Publishing, publisher 9999 in the pubs database. Lucerne publishing is located in Paris, France.

This is sample text data for Lucerne Publishing, publisher 9999 in the pubs database. Lucerne publishing is located in Paris, France.

This is sample text data for Lucerne Publishing, publisher 9999 in the pubs database. Lucerne publishing is located in Paris, France.

This is sample text data for Lucerne Publishing, publisher 9999 in the pubs database. Lucerne publishing is located in Paris, France.');
GO


RAISERROR('Now at the inserts to titles ....', 0, 1);



INSERT into dbo.publications (Publication_id, title, pub_id, notes, pubdate)

VALUES
( N'BU1032', 'The Busy Executive''s Database Guide', '1389    ', 'An overview of available database systems with emphasis on common business applications. Illustrated.', N'1991-06-12T00:00:00' ), 
( N'BU1111', 'Cooking with Computers: Surreptitious Balance Sheets', '1389    ', 'Helpful hints on how to use your electronic resources to the best advantage.', N'1991-06-09T00:00:00' ), 
( N'BU2075', 'You Can Combat Computer Stress!', '0736    ', 'The latest medical and psychological techniques for living with the electronic office. Easy-to-understand explanations.', N'1991-06-30T00:00:00' ), 
( N'BU7832', 'Straight Talk About Computers', '1389    ', 'Annotated analysis of what computers can do for you: a no-hype guide for the critical user.', N'1991-06-22T00:00:00' ), 
( N'MC2222', 'Silicon Valley Gastronomic Treats', '0877    ', 'Favorite recipes for quick, easy, and elegant meals.', N'1991-06-09T00:00:00' ), 
( N'MC3021', 'The Gourmet Microwave', '0877    ', 'Traditional French gourmet recipes adapted for modern microwave cooking.', N'1991-06-18T00:00:00' ), 
( N'MC3026', 'The Psychology of Computer Cooking', '0877    ', NULL, N'2020-06-05T12:41:13.163' ), 
( N'PC1035', 'But Is It User Friendly?', '1389    ', 'A survey of software for the naive user, focusing on the ''friendliness'' of each.', N'1991-06-30T00:00:00' ), 
( N'PC8888', 'Secrets of Silicon Valley', '1389    ', 'Muckraking reporting on the world''s largest computer hardware and software manufacturers.', N'1994-06-12T00:00:00' ), 
( N'PC9999', 'Net Etiquette', '1389    ', 'A must-read for computer conferencing.', N'2020-06-05T12:41:13.163' ), 
( N'PS1372', 'Computer Phobic AND Non-Phobic Individuals: Behavior Variations', '0877    ', 'A must for the specialist, this book examines the difference between those who hate and fear computers and those who don''t.', N'1991-10-21T00:00:00' ), 
( N'PS2091', 'Is Anger the Enemy?', '0736    ', 'Carefully researched study of the effects of strong emotions on the body. Metabolic charts included.', N'1991-06-15T00:00:00' ), 
( N'PS2106', 'Life Without Fear', '0736    ', 'New exercise, meditation, and nutritional techniques that can reduce the shock of daily interactions. Popular audience. Sample menus included, exercise video available separately.', N'1991-10-05T00:00:00' ), 
( N'PS3333', 'Prolonged Data Deprivation: Four Case Studies', '0736    ', 'What happens when the data runs dry?  Searching evaluations of information-shortage effects.', N'1991-06-12T00:00:00' ), 
( N'PS7777', 'Emotional Security: A New Algorithm', '0736    ', 'Protecting yourself and your loved ones from undue emotional stress in the modern world. Use of computer and nutritional aids emphasized.', N'1991-06-12T00:00:00' ), 
( N'TC3218', 'Onions, Leeks, and Garlic: Cooking Secrets of the Mediterranean', '0877    ', 'Profusely illustrated in color, this makes a wonderful gift book for a cuisine-oriented friend.', N'1991-10-21T00:00:00' ), 
( N'TC4203', 'Fifty Years in Buckingham Palace Kitchens', '0877    ', 'More anecdotes from the Queen''s favorite cook describing life among English royalty. Recipes, techniques, tender vignettes.', N'1991-06-12T00:00:00' ), 
( N'TC7777', 'Sushi, Anyone?', '0877    ', 'Detailed instructions on how to make authentic Japanese sushi in your spare time.', N'1991-06-12T00:00:00' )

GO

INSERT INTO dbo.EditionType (TheType)
VALUES
( N'AudioBook' ), 
( N'Book' ), 
( N'Calendar' ), 
( N'Ebook' ), 
( N'Hardback' ), 
( N'Map' ), 
( N'Paperback' )
SET IDENTITY_INSERT dbo.editions on
INSERT INTO dbo.editions 
(Edition_id, publication_id, PublicationName, Publication_type, EditionDate, EditionReplacedDate)
VALUES
( 1, N'PS3333', NULL, N'Map', N'2019-06-11T00:15:28.8407881', NULL ), 
( 2, N'PS7777', NULL, N'Paperback', N'2020-03-27T19:18:13.8412796', NULL ), 
( 4, N'PS1372', NULL, N'Hardback', N'2019-08-29T14:47:56.8488476', NULL ), 
( 5, N'BU7832', NULL, N'Book', N'2019-05-29T09:33:37.5660591', NULL ), 
( 7, N'TC4203', NULL, N'Paperback', N'2020-09-27T07:53:53.2489281', NULL ), 
( 8, N'PC1035', NULL, N'Hardback', N'2019-10-17T17:28:42.8821079', NULL ), 
( 9, N'TC7777', NULL, N'Paperback', N'2020-06-09T23:12:01.2160962', NULL ), 
( 10, N'MC2222', NULL, N'Book', N'2020-03-01T00:14:39.2925556', NULL ), 
( 11, N'MC3021', NULL, N'Book', N'2019-08-27T03:21:30.6173464', NULL ), 
( 12, N'PC8888', NULL, N'Hardback', N'2020-06-04T05:29:01.3284573', NULL ), 
( 13, N'PS2091', NULL, N'Map', N'2020-03-10T04:33:33.3972811', NULL ), 
( 16, N'BU1032', NULL, N'AudioBook', N'2020-11-04T14:08:49.404287', NULL ), 
( 17, N'TC3218', NULL, N'Paperback', N'2019-01-14T17:46:45.3225055', NULL ), 
( 19, N'PS2106', NULL, N'Map', N'2019-05-25T22:28:58.7021203', NULL ), 
( 26, N'PC9999', NULL, N'Hardback', N'2020-05-22T02:04:06.0706999', NULL ), 
( 30, N'BU1111', NULL, N'AudioBook', N'2020-09-29T18:00:22.3887642', NULL ), 
( 31, N'BU7832', NULL, N'AudioBook', N'2019-09-28T14:11:06.6359305', NULL ), 
( 38, N'MC3026', NULL, N'Book', N'2019-04-09T14:36:13.6301309', NULL ), 
( 39, N'MC3026', NULL, N'Calendar', N'2020-02-28T23:44:26.2244167', NULL ), 
( 43, N'BU2075', NULL, N'AudioBook', N'2020-03-08T00:58:39.6741717', NULL ), 
( 44, N'MC2222', NULL, N'map', N'2019-09-30T03:45:12.8012243', NULL ), 
( 46, N'PS7777', NULL, N'Map', N'2020-12-21T17:03:19.3547845', NULL ), 
( 47, N'MC3026', NULL, N'Hardback', N'2019-04-06T17:10:24.57175', NULL ), 
( 50, N'BU7832', NULL, N'map', N'2019-08-08T12:10:22.2570757', NULL ), 
( 62, N'BU7832', NULL, N'Calendar', N'2019-09-25T17:46:43.8593069', NULL ), 
( 70, N'BU7832', NULL, N'Hardback', N'2020-12-12T21:43:01.3861958', NULL ), 
( 98, N'MC2222', NULL, N'Calendar', N'2020-06-27T19:47:00.8468397', NULL ), 
( 105, N'BU7832', NULL, N'AudioBook', N'2019-09-15T12:53:38.3473609', NULL ), 
( 113, N'PS1372', NULL, N'Map', N'2020-02-27T06:07:28.4511687', NULL ), 
( 119, N'MC2222', NULL, N'Hardback', N'2020-05-02T01:16:00.7260591', NULL ), 
( 122, N'MC3026', NULL, N'AudioBook', N'2020-11-15T11:40:04.5198011', NULL ), 
( 125, N'MC3021', NULL, N'map', N'2019-08-25T07:21:56.7794589', NULL ), 
( 129, N'MC3026', NULL, N'Ebook', N'2020-07-13T17:08:23.6507402', NULL ), 
( 131, N'MC3021', NULL, N'Calendar', N'2020-03-18T13:53:54.4989414', NULL ), 
( 135, N'MC3021', NULL, N'Hardback', N'2019-10-15T20:34:48.2777574', NULL ), 
( 152, N'MC2222', NULL, N'AudioBook', N'2020-03-26T13:24:02.7598761', NULL ), 
( 156, N'MC2222', NULL, N'Ebook', N'2019-10-12T23:56:43.6057725', NULL ), 
( 171, N'MC3021', NULL, N'AudioBook', N'2019-02-03T18:39:50.4192924', NULL ), 
( 175, N'BU7832', NULL, N'Ebook', N'2020-07-03T18:21:45.3963299', NULL ), 
( 177, N'MC2222', NULL, N'Paperback', N'2019-04-02T17:36:19.7726494', NULL ), 
( 182, N'MC3026', NULL, N'Paperback', N'2020-07-02T06:25:31.3009787', NULL ), 
( 184, N'BU7832', NULL, N'Paperback', N'2020-06-26T23:39:17.4542949', NULL ), 
( 192, N'MC3021', NULL, N'Ebook', N'2019-01-31T16:07:10.9811802', NULL ), 
( 196, N'MC3021', NULL, N'Paperback', N'2019-03-01T19:10:50.2296843', NULL ), 
( 197, N'BU1032', NULL, N'book', N'1991-07-12T00:00:00', NULL ), 
( 198, N'BU1111', NULL, N'book', N'1991-07-09T00:00:00', NULL ), 
( 199, N'BU2075', NULL, N'book', N'1991-07-30T00:00:00', NULL ), 
( 200, N'PC1035', NULL, N'book', N'1991-07-30T00:00:00', NULL ), 
( 201, N'PC8888', NULL, N'book', N'1994-07-12T00:00:00', NULL ), 
( 202, N'PC9999', NULL, N'book', N'2020-07-05T12:41:13.1633333', NULL ), 
( 203, N'PS1372', NULL, N'book', N'1991-11-21T00:00:00', NULL ), 
( 204, N'PS2091', NULL, N'book', N'1991-07-15T00:00:00', NULL ), 
( 205, N'PS2106', NULL, N'book', N'1991-11-05T00:00:00', NULL ), 
( 206, N'PS3333', NULL, N'book', N'1991-07-12T00:00:00', NULL ), 
( 207, N'PS7777', NULL, N'book', N'1991-07-12T00:00:00', NULL ), 
( 208, N'TC3218', NULL, N'book', N'1991-11-21T00:00:00', NULL ), 
( 209, N'TC4203', NULL, N'book', N'1991-07-12T00:00:00', NULL ), 
( 210, N'TC7777', NULL, N'book', N'1991-07-12T00:00:00', NULL )
SET IDENTITY_INSERT dbo.editions OFF

SET IDENTITY_INSERT dbo.prices on
INSERT INTO prices  (Price_id, Edition_id, name, price, advance, royalty, ytd_sales, PriceStartDate, PriceEndDate)
VALUES
( 8, 7, NULL, 13.39, 21.03, 17, 651, N'2019-07-19T13:13:29.21984', N'2019-04-04T08:19:39.1763311' ), 
( 12, 7, NULL, 6.79, 970.61, 21, 11888, N'2019-05-06T12:32:07.8842331', NULL ), 
( 15, 17, NULL, 18.61, 480.40, 12, 19598, N'2019-08-07T08:52:16.4097714', NULL ), 
( 20, 192, NULL, 14.47, 960.81, 15, 16385, N'2019-03-01T11:29:54.2359655', NULL ), 
( 27, 98, NULL, 11.98, 308.57, 12, 733, N'2019-11-22T02:10:19.3107999', NULL ), 
( 31, 44, NULL, 6.83, 560.71, 23, 6731, N'2019-09-06T21:07:41.8882563', NULL ), 
( 34, 129, NULL, 17.90, 769.99, 21, 18265, N'2019-11-07T06:47:56.6333322', NULL ), 
( 35, 44, NULL, 8.07, 602.61, 24, 6773, N'2019-08-31T14:23:26.3230473', N'2020-11-10T10:45:33.1066667' ), 
( 40, 182, NULL, 5.11, 673.33, 13, 16338, N'2019-05-28T17:29:56.8568425', NULL ), 
( 55, 19, NULL, 19.84, 41.82, 13, 18287, N'2019-08-28T22:52:23.9868744', NULL ), 
( 58, 30, NULL, 16.39, 18.97, 15, 9736, N'2019-02-10T13:29:42.9804408', N'2019-02-15T20:46:56.328687' ), 
( 62, 171, NULL, 6.91, 24.30, 22, 14172, N'2019-07-13T20:23:07.2092604', NULL ), 
( 64, 192, NULL, 13.34, 835.28, 12, 15190, N'2019-10-19T05:59:30.4200458', N'2020-11-10T10:45:30.8433333' ), 
( 76, 122, NULL, 18.72, 640.83, 17, 1087, N'2019-03-30T11:16:54.5097176', NULL ), 
( 78, 13, NULL, 4.97, 154.33, 13, 7878, N'2019-05-09T16:23:52.4912584', NULL ), 
( 85, 135, NULL, 4.86, 782.43, 17, 5240, N'2019-11-08T22:30:02.5265177', NULL ), 
( 88, 44, NULL, 9.32, 514.48, 20, 15738, N'2019-02-25T01:21:02.9738264', N'2020-11-10T10:45:30.8433333' ), 
( 89, 47, NULL, 21.07, 728.16, 18, 4956, N'2019-03-29T07:55:32.6464577', NULL ), 
( 91, 4, NULL, 15.51, 544.48, 16, 8474, N'2019-05-02T12:50:17.5563357', NULL ), 
( 96, 131, NULL, 16.79, 628.45, 18, 2277, N'2019-06-21T19:52:24.5935851', NULL ), 
( 101, 1, NULL, 9.43, 1477.42, 11399, 14369, N'2019-06-25T16:26:35.0985841', NULL ), 
( 102, 2, NULL, 12.47, 1246.20, 41470, 2326, N'2019-10-26T15:59:38.10148', NULL ), 
( 103, 5, NULL, 24.62, 438.79, 24835, 18546, N'2019-10-04T10:55:08.8529084', NULL ), 
( 104, 8, NULL, 31.64, 830.90, 39008, 5464, N'2020-07-19T06:56:09.5473355', NULL ), 
( 105, 9, NULL, 35.87, 414.43, 8371, 5139, N'2019-10-05T12:35:30.4047602', NULL ), 
( 106, 10, NULL, 12.29, 1358.51, 48456, 6740, N'2020-05-29T21:11:07.3265306', NULL ), 
( 107, 11, NULL, 31.74, 1211.41, 13705, 19613, N'2020-06-07T15:26:38.0625307', NULL ), 
( 108, 12, NULL, 29.41, 1178.43, 14827, 972, N'2020-08-27T22:10:36.4550307', NULL ), 
( 109, 16, NULL, 37.81, 1301.91, 11034, 16258, N'2019-11-16T04:42:30.2068822', NULL ), 
( 110, 26, NULL, 16.33, 1977.09, 32186, 5451, N'2020-10-30T02:48:03.4634769', NULL ), 
( 111, 30, NULL, 18.10, 715.11, 2110, 16156, N'2020-03-23T12:09:17.5579296', NULL ), 
( 112, 31, NULL, 24.58, 1905.26, 16878, 13587, N'2019-02-05T06:31:16.686794', NULL ), 
( 113, 38, NULL, 13.91, 1072.26, 32644, 6408, N'2019-01-02T00:53:01.7189335', NULL ), 
( 114, 39, NULL, 34.20, 1931.08, 10706, 7062, N'2020-01-18T10:27:16.8791964', NULL ), 
( 115, 43, NULL, 10.94, 1850.90, 10862, 18190, N'2019-12-18T13:03:59.804944', NULL ), 
( 116, 46, NULL, 30.50, 1380.33, 8717, 7568, N'2019-07-08T18:56:37.8407045', NULL ), 
( 117, 50, NULL, 14.44, 547.19, 11105, 13736, N'2020-08-20T16:22:06.641219', NULL ), 
( 118, 62, NULL, 22.39, 461.71, 35885, 19926, N'2020-08-25T01:14:31.4006535', NULL ), 
( 119, 70, NULL, 11.72, 959.80, 31442, 3699, N'2020-09-05T22:56:51.2392975', NULL ), 
( 120, 105, NULL, 37.94, 1329.50, 33772, 18734, N'2019-07-29T06:58:21.7635566', NULL ), 
( 121, 113, NULL, 38.05, 519.25, 6466, 15302, N'2019-02-10T17:00:17.7287327', NULL ), 
( 122, 119, NULL, 12.19, 1369.75, 20739, 18924, N'2020-06-03T12:48:19.7929028', NULL ), 
( 123, 125, NULL, 19.11, 1533.84, 31648, 1393, N'2020-07-04T07:06:21.6017509', NULL ), 
( 124, 152, NULL, 8.95, 1980.58, 21344, 14066, N'2020-11-11T18:52:44.5265807', NULL ), 
( 125, 156, NULL, 10.28, 606.22, 21634, 7571, N'2019-02-17T04:35:52.6340636', NULL ), 
( 126, 175, NULL, 38.23, 870.73, 30416, 12710, N'2019-02-21T01:09:30.9648256', NULL ), 
( 127, 177, NULL, 22.50, 909.80, 37558, 17310, N'2020-08-09T22:52:49.5624348', NULL ), 
( 128, 184, NULL, 25.81, 775.58, 7485, 202, N'2020-04-01T00:15:10.7175712', NULL ), 
( 129, 196, NULL, 24.62, 490.80, 29778, 14262, N'2020-07-07T05:16:39.1179987', NULL ), 
( 136, 197, NULL, 19.99, 5000.00, 10, 4095, N'1991-06-12T00:00:00', NULL ), 
( 137, 198, NULL, 11.95, 5000.00, 10, 3876, N'1991-06-09T00:00:00', NULL ), 
( 138, 199, NULL, 2.99, 10125.00, 24, 18722, N'1991-06-30T00:00:00', NULL ), 
( 139, 200, NULL, 22.95, 7000.00, 16, 8780, N'1991-06-30T00:00:00', NULL ), 
( 140, 201, NULL, 20.00, 8000.00, 10, 4095, N'1994-06-12T00:00:00', NULL ), 
( 141, 202, NULL, 10.00, NULL, NULL, NULL, N'2020-11-12T12:24:01.2166667', NULL ), 
( 142, 203, NULL, 21.59, 7000.00, 10, 375, N'1991-10-21T00:00:00', NULL ), 
( 143, 204, NULL, 10.95, 2275.00, 12, 2045, N'1991-06-15T00:00:00', NULL ), 
( 144, 205, NULL, 7.00, 6000.00, 10, 111, N'1991-10-05T00:00:00', NULL ), 
( 145, 206, NULL, 19.99, 2000.00, 10, 4072, N'1991-06-12T00:00:00', NULL ), 
( 146, 207, NULL, 7.99, 4000.00, 10, 3336, N'1991-06-12T00:00:00', NULL ), 
( 147, 208, NULL, 20.95, 7000.00, 10, 375, N'1991-10-21T00:00:00', NULL ), 
( 148, 209, NULL, 11.95, 4000.00, 14, 15096, N'1991-06-12T00:00:00', NULL ), 
( 149, 210, NULL, 14.99, 8000.00, 10, 4095, N'1991-06-12T00:00:00', NULL )
SET IDENTITY_INSERT dbo.prices off

RAISERROR('Now at the inserts to titleauthor ....', 0, 1);
INSERT titleauthor VALUES
( N'172-32-1176', N'PS3333', 1, 100 ), ( N'213-46-8915', N'BU1032', 2, 40 ), 
( N'213-46-8915', N'BU2075', 1, 100 ), ( N'238-95-7766', N'PC1035', 1, 100 ), 
( N'267-41-2394', N'BU1111', 2, 40 ), ( N'267-41-2394', N'TC7777', 2, 30 ), 
( N'274-80-9391', N'BU7832', 1, 100 ), ( N'409-56-7008', N'BU1032', 1, 60 ), 
( N'427-17-2319', N'PC8888', 1, 50 ), ( N'472-27-2349', N'TC7777', 3, 30 ), 
( N'486-29-1786', N'PC9999', 1, 100 ), ( N'486-29-1786', N'PS7777', 1, 100 ), 
( N'648-92-1872', N'TC4203', 1, 100 ), ( N'672-71-3249', N'TC7777', 1, 40 ), 
( N'712-45-1867', N'MC2222', 1, 100 ), ( N'722-51-5454', N'MC3021', 1, 75 ), 
( N'724-80-9391', N'BU1111', 1, 60 ), ( N'724-80-9391', N'PS1372', 2, 25 ), 
( N'756-30-7391', N'PS1372', 1, 75 ), ( N'807-91-6654', N'TC3218', 1, 100 ), 
( N'846-92-7186', N'PC8888', 2, 50 ), ( N'899-46-2035', N'MC3021', 2, 25 ), 
( N'899-46-2035', N'PS2091', 2, 50 ), ( N'998-72-3567', N'PS2091', 1, 50 ), 
( N'998-72-3567', N'PS2106', 1, 100 )

GO

RAISERROR('Now at the inserts to stores ....', 0, 1);

GO

INSERT stores VALUES
( '6380    ', N'Eric the Read Books', N'788 Catamaugus Ave.', N'Seattle', 'WA', '98056' ), 
( '7066    ', N'Barnum''s', N'567 Pasadena Ave.', N'Tustin', 'CA', '92789' ), 
( '7067    ', N'News & Brews', N'577 First St.', N'Los Gatos', 'CA', '96745' ), 
( '7131    ', N'Doc-U-Mat: Quality Laundry and Books', N'24-A Avogadro Way', N'Remulade', 'WA', '98014' ), 
( '7896    ', N'Fricative Bookshop', N'89 Madison St.', N'Fremont', 'CA', '90019' ), 
( '8042    ', N'Bookbeat', N'679 Carson St.', N'Portland', 'OR', '89076' )

GO

RAISERROR('Now at the inserts to sales ....', 0, 1);

GO

INSERT sales VALUES
( '6380    ', N'6871', N'1994-09-14T00:00:00', 5, 'Net 60', N'BU1032' ), 
( '6380    ', N'722a', N'1994-09-13T00:00:00', 3, 'Net 60', N'PS2091' ), 
( '7066    ', N'A2976', N'1993-05-24T00:00:00', 50, 'Net 30', N'PC8888' ), 
( '7066    ', N'QA7442.3', N'1994-09-13T00:00:00', 75, 'ON invoice', N'PS2091' ), 
( '7067    ', N'D4482', N'1994-09-14T00:00:00', 10, 'Net 60', N'PS2091' ), 
( '7067    ', N'P2121', N'1992-06-15T00:00:00', 40, 'Net 30', N'TC3218' ), 
( '7067    ', N'P2121', N'1992-06-15T00:00:00', 20, 'Net 30', N'TC4203' ), 
( '7067    ', N'P2121', N'1992-06-15T00:00:00', 20, 'Net 30', N'TC7777' ), 
( '7131    ', N'N914008', N'1994-09-14T00:00:00', 20, 'Net 30', N'PS2091' ), 
( '7131    ', N'N914014', N'1994-09-14T00:00:00', 25, 'Net 30', N'MC3021' ), 
( '7131    ', N'P3087a', N'1993-05-29T00:00:00', 20, 'Net 60', N'PS1372' ), 
( '7131    ', N'P3087a', N'1993-05-29T00:00:00', 25, 'Net 60', N'PS2106' ), 
( '7131    ', N'P3087a', N'1993-05-29T00:00:00', 15, 'Net 60', N'PS3333' ), 
( '7131    ', N'P3087a', N'1993-05-29T00:00:00', 25, 'Net 60', N'PS7777' ), 
( '7896    ', N'QQ2299', N'1993-10-28T00:00:00', 15, 'Net 60', N'BU7832' ), 
( '7896    ', N'TQ456', N'1993-12-12T00:00:00', 10, 'Net 60', N'MC2222' ), 
( '7896    ', N'X999', N'1993-02-21T00:00:00', 35, 'ON invoice', N'BU2075' ), 
( '8042    ', N'423LL922', N'1994-09-14T00:00:00', 15, 'ON invoice', N'MC3021' ), 
( '8042    ', N'423LL930', N'1994-09-14T00:00:00', 10, 'ON invoice', N'BU1032' ), 
( '8042    ', N'P723', N'1993-03-11T00:00:00', 25, 'Net 30', N'BU1111' ), 
( '8042    ', N'QA879.1', N'1993-05-22T00:00:00', 30, 'Net 30', N'PC1035' )

GO

RAISERROR('Now at the inserts to roysched ....', 0, 1);

GO

INSERT roysched VALUES
( N'BU1032', 0, 5000, 10 ), ( N'BU1032', 5001, 50000, 12 ), ( N'PC1035', 0, 2000, 10 ), 
( N'PC1035', 2001, 3000, 12 ), ( N'PC1035', 3001, 4000, 14 ), ( N'PC1035', 4001, 10000, 16 ), 
( N'PC1035', 10001, 50000, 18 ), ( N'BU2075', 0, 1000, 10 ), ( N'BU2075', 1001, 3000, 12 ), 
( N'BU2075', 3001, 5000, 14 ), ( N'BU2075', 5001, 7000, 16 ), ( N'BU2075', 7001, 10000, 18 ), 
( N'BU2075', 10001, 12000, 20 ), ( N'BU2075', 12001, 14000, 22 ), ( N'BU2075', 14001, 50000, 24 ), 
( N'PS2091', 0, 1000, 10 ), ( N'PS2091', 1001, 5000, 12 ), ( N'PS2091', 5001, 10000, 14 ), 
( N'PS2091', 10001, 50000, 16 ), ( N'PS2106', 0, 2000, 10 ), ( N'PS2106', 2001, 5000, 12 ), 
( N'PS2106', 5001, 10000, 14 ), ( N'PS2106', 10001, 50000, 16 ), ( N'MC3021', 0, 1000, 10 ), 
( N'MC3021', 1001, 2000, 12 ), ( N'MC3021', 2001, 4000, 14 ), ( N'MC3021', 4001, 6000, 16 ), 
( N'MC3021', 6001, 8000, 18 ), ( N'MC3021', 8001, 10000, 20 ), ( N'MC3021', 10001, 12000, 22 ), 
( N'MC3021', 12001, 50000, 24 ), ( N'TC3218', 0, 2000, 10 ), ( N'TC3218', 2001, 4000, 12 ), 
( N'TC3218', 4001, 6000, 14 ), ( N'TC3218', 6001, 8000, 16 ), ( N'TC3218', 8001, 10000, 18 ), 
( N'TC3218', 10001, 12000, 20 ), ( N'TC3218', 12001, 14000, 22 ), ( N'TC3218', 14001, 50000, 24 ), 
( N'PC8888', 0, 5000, 10 ), ( N'PC8888', 5001, 10000, 12 ), ( N'PC8888', 10001, 15000, 14 ), 
( N'PC8888', 15001, 50000, 16 ), ( N'PS7777', 0, 5000, 10 ), ( N'PS7777', 5001, 50000, 12 ), 
( N'PS3333', 0, 5000, 10 ), ( N'PS3333', 5001, 10000, 12 ), ( N'PS3333', 10001, 15000, 14 ), 
( N'PS3333', 15001, 50000, 16 ), ( N'BU1111', 0, 4000, 10 ), ( N'BU1111', 4001, 8000, 12 ), 
( N'BU1111', 8001, 10000, 14 ), ( N'BU1111', 12001, 16000, 16 ), ( N'BU1111', 16001, 20000, 18 ), 
( N'BU1111', 20001, 24000, 20 ), ( N'BU1111', 24001, 28000, 22 ), ( N'BU1111', 28001, 50000, 24 ), 
( N'MC2222', 0, 2000, 10 ), ( N'MC2222', 2001, 4000, 12 ), ( N'MC2222', 4001, 8000, 14 ), 
( N'MC2222', 8001, 12000, 16 ), ( N'MC2222', 12001, 20000, 18 ), ( N'MC2222', 20001, 50000, 20 ), 
( N'TC7777', 0, 5000, 10 ), ( N'TC7777', 5001, 15000, 12 ), ( N'TC7777', 15001, 50000, 14 ), 
( N'TC4203', 0, 2000, 10 ), ( N'TC4203', 2001, 8000, 12 ), ( N'TC4203', 8001, 16000, 14 ), 
( N'TC4203', 16001, 24000, 16 ), ( N'TC4203', 24001, 32000, 18 ), ( N'TC4203', 32001, 40000, 20 ), 
( N'TC4203', 40001, 50000, 22 ), ( N'BU7832', 0, 5000, 10 ), ( N'BU7832', 5001, 10000, 12 ), 
( N'BU7832', 10001, 15000, 14 ), ( N'BU7832', 15001, 20000, 16 ), ( N'BU7832', 20001, 25000, 18 ), 
( N'BU7832', 25001, 30000, 20 ), ( N'BU7832', 30001, 35000, 22 ), ( N'BU7832', 35001, 50000, 24 ), 
( N'PS1372', 0, 10000, 10 ), ( N'PS1372', 10001, 20000, 12 ), ( N'PS1372', 20001, 30000, 14 ), 
( N'PS1372', 30001, 40000, 16 ), ( N'PS1372', 40001, 50000, 18 )
GO

PRINT 'Now at the inserts to discounts ....'

GO

INSERT discounts VALUES
( N'Initial Customer', NULL, NULL, NULL, 10.50 ), 
( N'Volume Discount', NULL, 100, 1000, 6.70 ), 
( N'Customer Discount', '8042    ', NULL, NULL, 5.00 )

GO

PRINT 'Now at the inserts to jobs ....';

GO

INSERT jobs (job_desc, min_lvl, max_lvl)
Values
( 'New Hire - Job not specified', 10, 10 ), 
( 'Chief Executive Officer', 200, 250 ), 
( 'Business Operations Manager', 175, 225 ), 
( 'Chief Financial Officier', 175, 250 ), 
( 'Publisher', 150, 250 ), 
( 'Managing Editor', 140, 225 ), 
( 'Marketing Manager', 120, 200 ), 
( 'Public Relations Manager', 100, 175 ), 
( 'Acquisitions Manager', 75, 175 ), 
(  'Productions Manager', 75, 165 ), 
(  'Operations Manager', 75, 150 ), 
(  'Editor', 25, 100 ), 
(  'Sales Representative', 25, 100 ), 
(  'Designer', 25, 100 )
GO

RAISERROR('Now at the inserts to employee ....', 0, 1);

GO

INSERT employee VALUES
( 'PMA42628M', N'Paolo', 'M', 'Accorti', 13, 35, '0877    ', N'1992-08-27T00:00:00' ), 
( 'PSA89086M', N'Pedro', 'S', 'Afonso', 14, 89, '1389    ', N'1990-12-24T00:00:00' ), 
( 'VPA30890F', N'Victoria', 'P', 'Ashworth', 6, 140, '0877    ', N'1990-09-13T00:00:00' ), 
( 'H-B39728F', N'Helen', ' ', 'Bennett', 12, 35, '0877    ', N'1989-09-21T00:00:00' ), 
( 'L-B31947F', N'Lesley', ' ', 'Brown', 7, 120, '0877    ', N'1991-02-13T00:00:00' ), 
( 'F-C16315M', N'Francisco', ' ', 'Chang', 4, 227, '9952    ', N'1990-11-03T00:00:00' ), 
( 'PTC11962M', N'Philip', 'T', 'Cramer', 2, 215, '9952    ', N'1989-11-11T00:00:00' ), 
( 'A-C71970F', N'Aria', ' ', 'Cruz', 10, 87, '1389    ', N'1991-10-26T00:00:00' ), 
( 'AMD15433F', N'Ann', 'M', 'Devon', 3, 200, '9952    ', N'1991-07-16T00:00:00' ), 
( 'ARD36773F', N'Anabela', 'R', 'Domingues', 8, 100, '0877    ', N'1993-01-27T00:00:00' ), 
( 'PHF38899M', N'Peter', 'H', 'Franken', 10, 75, '0877    ', N'1992-05-17T00:00:00' ), 
( 'PXH22250M', N'Paul', 'X', 'Henriot', 5, 159, '0877    ', N'1993-08-19T00:00:00' ), 
( 'CFH28514M', N'Carlos', 'F', 'Hernadez', 5, 211, '9999    ', N'1989-04-21T00:00:00' ), 
( 'PDI47470M', N'Palle', 'D', 'Ibsen', 7, 195, '0736    ', N'1993-05-09T00:00:00' ), 
( 'KJJ92907F', N'Karla', 'J', 'Jablonski', 9, 170, '9999    ', N'1994-03-11T00:00:00' ), 
( 'KFJ64308F', N'Karin', 'F', 'Josephs', 14, 100, '0736    ', N'1992-10-17T00:00:00' ), 
( 'MGK44605M', N'Matti', 'G', 'Karttunen', 6, 220, '0736    ', N'1994-05-01T00:00:00' ), 
( 'POK93028M', N'Pirkko', 'O', 'Koskitalo', 10, 80, '9999    ', N'1993-11-29T00:00:00' ), 
( 'JYL26161F', N'Janine', 'Y', 'Labrune', 5, 172, '9901    ', N'1991-05-26T00:00:00' ), 
( 'M-L67958F', N'Maria', ' ', 'Larsson', 7, 135, '1389    ', N'1992-03-27T00:00:00' ), 
( 'Y-L77953M', N'Yoshi', ' ', 'Latimer', 12, 32, '1389    ', N'1989-06-11T00:00:00' ), 
( 'LAL21447M', N'Laurence', 'A', 'Lebihan', 5, 175, '0736    ', N'1990-06-03T00:00:00' ), 
( 'ENL44273F', N'Elizabeth', 'N', 'Lincoln', 14, 35, '0877    ', N'1990-07-24T00:00:00' ), 
( 'PCM98509F', N'Patricia', 'C', 'McKenna', 11, 150, '9999    ', N'1989-08-01T00:00:00' ), 
( 'R-M53550M', N'Roland', ' ', 'Mendel', 11, 150, '0736    ', N'1991-09-05T00:00:00' ), 
( 'RBM23061F', N'Rita', 'B', 'Muller', 5, 198, '1622    ', N'1993-10-09T00:00:00' ), 
( 'HAN90777M', N'Helvetius', 'A', 'Nagy', 7, 120, '9999    ', N'1993-03-19T00:00:00' ), 
( 'TPO55093M', N'Timothy', 'P', 'O''Rourke', 13, 100, '0736    ', N'1988-06-19T00:00:00' ), 
( 'SKO22412M', N'Sven', 'K', 'Ottlieb', 5, 150, '1389    ', N'1991-04-05T00:00:00' ), 
( 'MAP77183M', N'Miguel', 'A', 'Paolino', 11, 112, '1389    ', N'1992-12-07T00:00:00' ), 
( 'PSP68661F', N'Paula', 'S', 'Parente', 8, 125, '1389    ', N'1994-01-19T00:00:00' ), 
( 'M-P91209M', N'Manuel', ' ', 'Pereira', 8, 101, '9999    ', N'1989-01-09T00:00:00' ), 
( 'MJP25939M', N'Maria', 'J', 'Pontes', 5, 246, '1756    ', N'1989-03-01T00:00:00' ), 
( 'M-R38834F', N'Martine', ' ', 'Rance', 9, 75, '0877    ', N'1992-02-05T00:00:00' ), 
( 'DWR65030M', N'Diego', 'W', 'Roel', 6, 192, '1389    ', N'1991-12-16T00:00:00' ), 
( 'A-R89858F', N'Annette', ' ', 'Roulet', 6, 152, '9999    ', N'1990-02-21T00:00:00' ), 
( 'MMS49649F', N'Mary', 'M', 'Saveley', 8, 175, '0736    ', N'1993-06-29T00:00:00' ), 
( 'CGS88322F', N'Carine', 'G', 'Schmitt', 13, 64, '1389    ', N'1992-07-07T00:00:00' ), 
( 'MAS70474F', N'Margaret', 'A', 'Smith', 9, 78, '1389    ', N'1988-09-29T00:00:00' ), 
( 'HAS54740M', N'Howard', 'A', 'Snyder', 12, 100, '0736    ', N'1988-11-19T00:00:00' ), 
( 'MFS52347M', N'Martin', 'F', 'Sommer', 10, 165, '0736    ', N'1990-04-13T00:00:00' ), 
( 'GHT50241M', N'Gary', 'H', 'Thomas', 9, 170, '0736    ', N'1988-08-09T00:00:00' ), 
( 'DBT39435M', N'Daniel', 'B', 'Tonini', 11, 75, '0877    ', N'1990-01-01T00:00:00' )
SET IDENTITY_INSERT tagname ON
INSERT INTO TagName (TagName_ID, Tag)
VALUES
( 1, 'business    ' ), 
( 2, 'mod_cook    ' ), 
( 3, 'popular_comp' ), 
( 4, 'psychology  ' ), 
( 5, 'trad_cook   ' ), 
( 6, 'UNDECIDED   ' )
SET IDENTITY_INSERT dbo.TagName OFF

SET IDENTITY_INSERT dbo.TagTitle ON
INSERT INTO TagTitle (TagTitle_ID, title_id, Is_Primary, TagName_ID)
VALUES
( 2, N'BU1032', 1, 1 ), 
( 5, N'BU1111', 1, 1 ), 
( 10, N'BU2075', 1, 1 ), 
( 15, N'BU7832', 1, 1 ), 
( 6, N'MC2222', 1, 2 ), 
( 13, N'MC3021', 1, 2 ), 
( 17, N'MC3026', 1, 6 ), 
( 9, N'PC1035', 1, 3 ), 
( 1, N'PC8888', 1, 3 ), 
( 18, N'PC9999', 1, 3 ), 
( 16, N'PS1372', 1, 4 ), 
( 11, N'PS2091', 1, 4 ), 
( 12, N'PS2106', 1, 4 ), 
( 4, N'PS3333', 1, 4 ), 
( 3, N'PS7777', 1, 4 ), 
( 14, N'TC3218', 1, 5 ), 
( 8, N'TC4203', 1, 5 ), 
( 7, N'TC7777', 1, 5 )
SET IDENTITY_INSERT dbo.TagTitle OFF

