CREATE TABLE [dbo].[jobs]
(
[Job_id] [int] NOT NULL IDENTITY(1, 1),
[job_desc] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL CONSTRAINT [UndecidedJobDesc] DEFAULT ('New Position - title not formalized yet'),
[min_lvl] [tinyint] NOT NULL,
[max_lvl] [tinyint] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [UndecidedMaxSalary] CHECK (([max_lvl]<=(250)))
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [UndecidedMinSalary] CHECK (([min_lvl]>=(10)))
GO
ALTER TABLE [dbo].[jobs] ADD CONSTRAINT [JobsKey] PRIMARY KEY CLUSTERED  ([Job_id]) ON [PRIMARY]
GO
