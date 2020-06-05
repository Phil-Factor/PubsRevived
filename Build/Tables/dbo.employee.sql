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
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
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
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [CK_emp_id] CHECK (([emp_id] like '[A-Z][A-Z][A-Z][1-9][0-9][0-9][0-9][0-9][FM]' OR [emp_id] like '[A-Z]-[A-Z][1-9][0-9][0-9][0-9][0-9][FM]'))
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [PK_emp_id] PRIMARY KEY NONCLUSTERED  ([emp_id]) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [employee_ind] ON [dbo].[employee] ([lname], [fname], [minit]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [FK_EmployeeJobs] FOREIGN KEY ([job_id]) REFERENCES [dbo].[jobs] ([Job_id])
GO
ALTER TABLE [dbo].[employee] ADD CONSTRAINT [FK_EmployeePublishers] FOREIGN KEY ([pub_id]) REFERENCES [dbo].[publishers] ([pub_id])
GO
