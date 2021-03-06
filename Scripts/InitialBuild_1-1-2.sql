/*
    Generated on 05/Jun/2020 15:24 by Redgate SQL Change Automation v3.2.19130.7523
*/

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating schemas'
GO
CREATE SCHEMA [Classic]
AUTHORIZATION [dbo]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating types'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
CREATE TYPE [dbo].[tid] FROM nvarchar (8) NOT NULL
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
CREATE TYPE [dbo].[id] FROM nvarchar (11) NOT NULL
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
CREATE TYPE [dbo].[empid] FROM char (9) NOT NULL
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
CREATE TYPE [dbo].[Dollars] FROM numeric (9, 2) NOT NULL
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[authors]'
GO
CREATE TABLE [dbo].[authors]
(
[au_id] [dbo].[id] NOT NULL,
[au_lname] [nvarchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[au_fname] [nvarchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[phone] [varchar] (12) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [PhoneNotKnown] DEFAULT ('UNKNOWN'),
[address] [nvarchar] (100) COLLATE Latin1_General_CI_AS NULL,
[city] [nvarchar] (40) COLLATE Latin1_General_CI_AS NULL,
[state] [char] (2) COLLATE Latin1_General_CI_AS NULL,
[zip] [char] (5) COLLATE Latin1_General_CI_AS NULL,
[contract] [bit] NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_auidind] on [dbo].[authors]'
GO
ALTER TABLE [dbo].[authors] ADD CONSTRAINT [UPKCL_auidind] PRIMARY KEY CLUSTERED  ([au_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [aunmind] on [dbo].[authors]'
GO
CREATE NONCLUSTERED INDEX [aunmind] ON [dbo].[authors] ([au_lname], [au_fname]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[employee]'
GO
CREATE TABLE [dbo].[employee]
(
[emp_id] [dbo].[empid] NOT NULL,
[fname] [nvarchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[minit] [char] (1) COLLATE Latin1_General_CI_AS NULL,
[lname] [varchar] (30) COLLATE Latin1_General_CI_AS NOT NULL,
[job_id] [int] NOT NULL CONSTRAINT [LetsMakeItOne] DEFAULT ((1)),
[job_lvl] [tinyint] NULL CONSTRAINT [DefaultToTen] DEFAULT ((10)),
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [HighNumber] DEFAULT ('9952'),
[hire_date] [datetime] NOT NULL CONSTRAINT [CouldBeToday] DEFAULT (getdate())
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [employee_ind] on [dbo].[employee]'
GO
CREATE CLUSTERED INDEX [employee_ind] ON [dbo].[employee] ([lname], [fname], [minit]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_emp_id] on [dbo].[employee]'
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [PK_emp_id] PRIMARY KEY NONCLUSTERED  ([emp_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[jobs]'
GO
CREATE TABLE [dbo].[jobs]
(
[Job_id] [int] NOT NULL IDENTITY(1, 1),
[job_desc] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [UndecidedJobDesc] DEFAULT ('New Position - title not formalized yet'),
[min_lvl] [tinyint] NOT NULL,
[max_lvl] [tinyint] NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [JobsKey] on [dbo].[jobs]'
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [JobsKey] PRIMARY KEY CLUSTERED  ([Job_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[publishers]'
GO
CREATE TABLE [dbo].[publishers]
(
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[pub_name] [nvarchar] (80) COLLATE Latin1_General_CI_AS NULL,
[city] [nvarchar] (40) COLLATE Latin1_General_CI_AS NULL,
[state] [char] (2) COLLATE Latin1_General_CI_AS NULL,
[country] [varchar] (30) COLLATE Latin1_General_CI_AS NULL CONSTRAINT [godsOwnCountry] DEFAULT ('USA')
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_pubind] on [dbo].[publishers]'
GO
ALTER TABLE [dbo].[publishers] ADD CONSTRAINT [UPKCL_pubind] PRIMARY KEY CLUSTERED  ([pub_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[TagTitle]'
GO
CREATE TABLE [dbo].[TagTitle]
(
[TagTitle_ID] [int] NOT NULL IDENTITY(1, 1),
[title_id] [dbo].[tid] NOT NULL,
[Is_Primary] [bit] NOT NULL CONSTRAINT [NotPrimary] DEFAULT ((0)),
[TagName_ID] [int] NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_TagNameTitle] on [dbo].[TagTitle]'
GO
ALTER TABLE [dbo].[TagTitle] ADD CONSTRAINT [PK_TagNameTitle] PRIMARY KEY CLUSTERED  ([title_id], [TagName_ID]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[titles]'
GO
CREATE TABLE [dbo].[titles]
(
[title_id] [dbo].[tid] NOT NULL,
[title] [varchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NULL,
[price] [dbo].[Dollars] NULL,
[advance] [dbo].[Dollars] NULL,
[royalty] [int] NULL,
[ytd_sales] [int] NULL,
[notes] [varchar] (200) COLLATE Latin1_General_CI_AS NULL,
[pubdate] [datetime] NOT NULL CONSTRAINT [NowDefault] DEFAULT (getdate())
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_titleidind] on [dbo].[titles]'
GO
ALTER TABLE [dbo].[titles] ADD CONSTRAINT [UPKCL_titleidind] PRIMARY KEY CLUSTERED  ([title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [titleind] on [dbo].[titles]'
GO
CREATE NONCLUSTERED INDEX [titleind] ON [dbo].[titles] ([title]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating trigger [dbo].[employee_insupd] on [dbo].[employee]'
GO

CREATE TRIGGER [dbo].[employee_insupd]
ON [dbo].[employee]
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[stores]'
GO
CREATE TABLE [dbo].[stores]
(
[stor_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[stor_name] [nvarchar] (80) COLLATE Latin1_General_CI_AS NULL,
[stor_address] [nvarchar] (80) COLLATE Latin1_General_CI_AS NULL,
[city] [nvarchar] (40) COLLATE Latin1_General_CI_AS NULL,
[state] [char] (2) COLLATE Latin1_General_CI_AS NULL,
[zip] [char] (5) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPK_storeid] on [dbo].[stores]'
GO
ALTER TABLE [dbo].[stores] ADD CONSTRAINT [UPK_storeid] PRIMARY KEY CLUSTERED  ([stor_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[discounts]'
GO
CREATE TABLE [dbo].[discounts]
(
[discounttype] [nvarchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[stor_id] [char] (8) COLLATE Latin1_General_CI_AS NULL,
[lowqty] [smallint] NULL,
[highqty] [smallint] NULL,
[discount] [decimal] (4, 2) NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[pub_info]'
GO
CREATE TABLE [dbo].[pub_info]
(
[pub_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[logo] [varbinary] (max) NULL,
[pr_info] [nvarchar] (max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_pubinfo] on [dbo].[pub_info]'
GO
ALTER TABLE [dbo].[pub_info] ADD CONSTRAINT [UPKCL_pubinfo] PRIMARY KEY CLUSTERED  ([pub_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[roysched]'
GO
CREATE TABLE [dbo].[roysched]
(
[title_id] [dbo].[tid] NOT NULL,
[lorange] [int] NULL,
[hirange] [int] NULL,
[royalty] [int] NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [titleidind] on [dbo].[roysched]'
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[roysched] ([title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[sales]'
GO
CREATE TABLE [dbo].[sales]
(
[stor_id] [char] (8) COLLATE Latin1_General_CI_AS NOT NULL,
[ord_num] [nvarchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[ord_date] [datetime] NOT NULL,
[qty] [smallint] NOT NULL,
[payterms] [varchar] (12) COLLATE Latin1_General_CI_AS NOT NULL,
[title_id] [dbo].[tid] NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_sales] on [dbo].[sales]'
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [UPKCL_sales] PRIMARY KEY CLUSTERED  ([stor_id], [ord_num], [title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [titleidind] on [dbo].[sales]'
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[sales] ([title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[TagName]'
GO
CREATE TABLE [dbo].[TagName]
(
[TagName_ID] [int] NOT NULL IDENTITY(1, 1),
[Tag] [varchar] (20) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [TagnameSurrogate] on [dbo].[TagName]'
GO
ALTER TABLE [dbo].[TagName] ADD CONSTRAINT [TagnameSurrogate] PRIMARY KEY CLUSTERED  ([TagName_ID]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [dbo].[TagName]'
GO
ALTER TABLE [dbo].[TagName] ADD CONSTRAINT [Uniquetag] UNIQUE NONCLUSTERED  ([Tag]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[titleauthor]'
GO
CREATE TABLE [dbo].[titleauthor]
(
[au_id] [dbo].[id] NOT NULL,
[title_id] [dbo].[tid] NOT NULL,
[au_ord] [tinyint] NULL,
[royaltyper] [int] NULL
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [UPKCL_taind] on [dbo].[titleauthor]'
GO
ALTER TABLE [dbo].[titleauthor] ADD CONSTRAINT [UPKCL_taind] PRIMARY KEY CLUSTERED  ([au_id], [title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [auidind] on [dbo].[titleauthor]'
GO
CREATE NONCLUSTERED INDEX [auidind] ON [dbo].[titleauthor] ([au_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [titleidind] on [dbo].[titleauthor]'
GO
CREATE NONCLUSTERED INDEX [titleidind] ON [dbo].[titleauthor] ([title_id]) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[byroyalty]'
GO

CREATE PROCEDURE [dbo].[byroyalty] @percentage INT
AS
  BEGIN
    SELECT titleauthor.au_id
      FROM dbo.titleauthor AS titleauthor
      WHERE titleauthor.royaltyper = @percentage;
  END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[reptq1]'
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[reptq2]'
GO

CREATE PROCEDURE [dbo].[reptq2]
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[reptq3]'
GO

CREATE PROCEDURE [dbo].[reptq3] @lolimit dbo.Dollars, @hilimit dbo.Dollars,
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [Classic].[titles]'
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[titleview]'
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [dbo].[authors]'
GO
ALTER TABLE [dbo].[authors] ADD CONSTRAINT [CheckAu_ID_Numeric] CHECK (([au_id] like '[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [dbo].[authors] ADD CONSTRAINT [checkZip] CHECK (([zip] like '[0-9][0-9][0-9][0-9][0-9]'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [dbo].[employee]'
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [CK_emp_id] CHECK (([emp_id] like '[A-Z][A-Z][A-Z][1-9][0-9][0-9][0-9][0-9][FM]' OR [emp_id] like '[A-Z]-[A-Z][1-9][0-9][0-9][0-9][0-9][FM]'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [dbo].[jobs]'
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [UndecidedMinSalary] CHECK (([min_lvl]>=(10)))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [UndecidedMaxSalary] CHECK (([max_lvl]<=(250)))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [dbo].[publishers]'
GO
ALTER TABLE [dbo].[publishers] ADD CONSTRAINT [GetPubidright] CHECK (([pub_id]='1756' OR [pub_id]='1622' OR [pub_id]='0877' OR [pub_id]='0736' OR [pub_id]='1389' OR [pub_id] like '99[0-9][0-9]'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[TagTitle]'
GO
ALTER TABLE [dbo].[TagTitle] ADD CONSTRAINT [fkTagname] FOREIGN KEY ([TagName_ID]) REFERENCES [dbo].[TagName] ([TagName_ID])
GO
ALTER TABLE [dbo].[TagTitle] ADD CONSTRAINT [FKTitle_id] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[titleauthor]'
GO
ALTER TABLE [dbo].[titleauthor] ADD CONSTRAINT [FK_TitleauthorAuthors] FOREIGN KEY ([au_id]) REFERENCES [dbo].[authors] ([au_id])
GO
ALTER TABLE [dbo].[titleauthor] ADD CONSTRAINT [FK_TitleauthorTitles] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[discounts]'
GO
ALTER TABLE [dbo].[discounts] ADD CONSTRAINT [FK_DiscountsStore] FOREIGN KEY ([stor_id]) REFERENCES [dbo].[stores] ([stor_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[employee]'
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [FK_EmployeeJobs] FOREIGN KEY ([job_id]) REFERENCES [dbo].[jobs] ([Job_id])
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [FK_EmployeePublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[pub_info]'
GO
ALTER TABLE [dbo].[pub_info] ADD CONSTRAINT [FK_Pub_infoPublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[titles]'
GO
ALTER TABLE [dbo].[titles] ADD CONSTRAINT [FK_TitlesPublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[roysched]'
GO
ALTER TABLE [dbo].[roysched] ADD CONSTRAINT [FK_RoySchedTitles] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[sales]'
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesStores] FOREIGN KEY ([stor_id]) REFERENCES [dbo].[stores] ([stor_id])
GO
ALTER TABLE [dbo].[sales] ADD CONSTRAINT [FK_salesTitles] FOREIGN KEY ([title_id]) REFERENCES [dbo].[titles] ([title_id])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating extended properties'
GO
BEGIN TRY
	EXEC sp_addextendedproperty N'Database_Info', N'[{"Name":"Pubs","Version":"1.2.1","Description":"The Pubs (publishing) Database supports a fictitious publisher.","Modified":"2020-06-05T13:50:06","by":"sa"}]', NULL, NULL, NULL, NULL, NULL, NULL
END TRY
BEGIN CATCH
	DECLARE @msg nvarchar(max);
	DECLARE @severity int;
	DECLARE @state int;
	SELECT @msg = ERROR_MESSAGE(), @severity = ERROR_SEVERITY(), @state = ERROR_STATE();
	RAISERROR(@msg, @severity, @state);

	SET NOEXEC ON
END CATCH
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO

