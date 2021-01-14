--SELECT  *  FROM [cmsContentType]

 declare @dateFrom datetime = '2021-01-01 00:00:01.947'

 /* List all current versions of documents newer than @dateFrom  */
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
 order by umbContentVersion.versionDate desc
 
 /* Trimmed view */
 select 
 umbdocument.nodeId,
 umbContentVersion.versionDate, 
 umbContentVersion.[text], 
 umbcontentType.alias,
 umbracoUser.userEmail  
 from [umbracoDocument] umbdocument
 join [umbracoContent] umbContent on umbdocument.nodeId = umbContent.nodeId
 join [cmsContentType] umbcontentType on umbContent.contentTypeId = umbcontentType.nodeId
 join [umbracoContentVersion] umbContentVersion on umbContent.nodeId = umbContentVersion.nodeId 
 join [umbracoUser] umbracoUser on umbContentVersion.userId = umbracoUser.id
 where umbContentVersion.[current] = 1 
 and umbContentVersion.versionDate > @dateFrom
 order by umbContentVersion.versionDate desc