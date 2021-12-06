DECLARE @fileName nvarchar(MAX) = 'hello-world.jpg'

SELECT ucv.*,
       umv.*
FROM [dbo].[umbracoMediaVersion] umv
INNER JOIN [dbo].[umbracoContentVersion] ucv ON umv.id = ucv.id
WHERE umv.[path] like '%' + @fileName