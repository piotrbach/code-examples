 declare @contentType NVARCHAR(MAX) = 'article';
 declare @contentTypeId int =  (SELECT TOP 1 nodeId  FROM [cmsContentType]  where alias = @contentType)
 
 declare @dateFrom datetime = '2020-10-23 00:33:17.947'

 /* List all current versions of documents by content type - older than @dateFrom  */
 select 
 umbdocument.*,
 umbContentVersion.*, 
 umbcontentType.*,
 umbracoUser.userEmail  
 from [umbracoDocument] umbdocument
 join [umbracoContent] umbContent on umbdocument.nodeId = umbContent.nodeId
 join [cmsContentType] umbcontentType on umbContent.contentTypeId = umbcontentType.nodeId
 join [umbracoContentVersion] umbContentVersion on umbContent.nodeId = umbContentVersion.nodeId 
 join [umbracoUser] umbracoUser on umbContentVersion.userId = umbracoUser.id
 where umbContentVersion.[current] = 1 
 and umbContentVersion.versionDate > @dateFrom
 and umbContent.contentTypeId = @contentTypeId
 order by umbContentVersion.versionDate desc