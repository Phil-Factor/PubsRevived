--inserted code
/* this script upgrades the database from 1.1.2 to 1.2.1 
First we check that this is a legitimate target to upgrade */
Declare @version varchar(25);
SELECT @version= Coalesce(Json_Value(
 ( SELECT Convert(NVARCHAR(3760), value) 
   FROM sys.extended_properties AS EP
   WHERE major_id = 0 AND minor_id = 0 
    AND name = 'Database_Info'),'$[0].Version'),'that was not recorded');
IF @version <> '1.1.2'
 BEGIN
 RAISERROR ('We could not upgrade this to version 1.2.1. The Target was at version %s, not the correct version (1.1.2)',16,1,@version)
 SET NOEXEC ON;
 END
--end of inserted code
/*
    Generated on 05/Jun/2020 15:28 by Redgate SQL Change Automation v3.2.19130.7523
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
PRINT N'Altering extended properties'
GO
BEGIN TRY
	EXEC sp_updateextendedproperty N'Database_Info', N'[{"Name":"Pubs","Version":"1.2.1","Description":"The Pubs (publishing) Database supports a fictitious publisher.","Modified":"2020-06-05T15:28:19.100","by":"sa"}]', NULL, NULL, NULL, NULL, NULL, NULL
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

