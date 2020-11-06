SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   FUNCTION [dbo].[MoveForeignKeyReferences]
/*
 Select [dbo].[MoveForeignKeyReferences]('dbo.titles','dbo.publications', 'publication_id', 'ON DELETE CASCADE')
 */

(
    @from Sysname,
	@to sysname,
	@ToColumn sysname,
	@ONClause nvarchar(2000)
)
RETURNS nvarchar(MAX)
AS
BEGIN
DECLARE @Statements nvarchar(MAX)=''
SELECT  @Statements= @Statements+
'
ALTER TABLE '+ Object_Schema_Name( FKC.parent_object_id)+'.'+ Object_Name(FKC.parent_object_id) +' DROP
   CONSTRAINT ' + Object_Name(constraint_object_id)+'
GO
ALTER TABLE '+ Object_Schema_Name( FKC.parent_object_id)+'.'+ Object_Name(FKC.parent_object_id) + ' ADD
   CONSTRAINT  '+ Object_Name(constraint_object_id) +'
       FOREIGN KEY ('+ String_Agg(Col_Name(referenced_object_id,Referenced_column_id),', ')+')
      REFERENCES  '+@to+' ('+@ToColumn+')
     '+@onClause+'
GO'

/*SELECT Object_Name(constraint_object_id),
		Object_Schema_Name( FKC.parent_object_id)+'.'+ Object_Name(FKC.parent_object_id),
		String_Agg(Col_Name(parent_object_id,parent_column_id),', '),
		Object_schema_Name( FKC.referenced_object_id)+'.'+ Object_Name(FKC.referenced_object_id),
		 String_Agg(Col_Name(referenced_object_id,Referenced_column_id),', ')
--SELECT * */
FROM sys.foreign_key_columns 
FKC WHERE Object_schema_Name( FKC.referenced_object_id)+'.'+ Object_Name(FKC.referenced_object_id)=@from
GROUP BY constraint_object_id,parent_object_id, referenced_object_id

   RETURN @statements

END

GO
