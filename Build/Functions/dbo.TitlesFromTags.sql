SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[TitlesFromTags]
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
