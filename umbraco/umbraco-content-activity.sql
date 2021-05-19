--SELECT  *  FROM [cmsContentType]

 declare @now datetime = getdate()
 declare @dateFrom datetime = getdate()
 set @dateFrom = dateadd(day,-7,@now) -- last 7 days

 /* List all current versions of documents newer than @dateFrom Trimmed view */
 select 
 umbdocument.nodeId,
 umbContentVersion.versionDate, 
 umbContentVersion.[text], 
 umbcontentType.alias,
 umbracoUser.userEmail,
 umbracoUser.[username]
 from [umbracoDocument] umbdocument
 join [umbracoContent] umbContent on umbdocument.nodeId = umbContent.nodeId
 join [cmsContentType] umbcontentType on umbContent.contentTypeId = umbcontentType.nodeId
 join [umbracoContentVersion] umbContentVersion on umbContent.nodeId = umbContentVersion.nodeId 
 join [umbracoUser] umbracoUser on umbContentVersion.userId = umbracoUser.id
 where umbContentVersion.[current] = 1 
 and umbContentVersion.versionDate > @dateFrom
 order by umbContentVersion.versionDate desc
 
 /* List all current versions of documents newer than @dateFrom - full view */
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
