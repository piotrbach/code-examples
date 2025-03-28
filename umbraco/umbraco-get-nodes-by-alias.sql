/*
    This script retrieves all Umbraco nodes from the database
    that belong to a specific document type alias (e.g., 'article').
    It joins umbracoNode, umbracoContent, and cmsContentType tables
    to return core node information for the matching content type.
*/

DECLARE @Alias VARCHAR(255) = 'article'

SELECT UN.*
FROM umbracoContent UC WITH(NOLOCK)
JOIN cmsContentType CT WITH(NOLOCK) ON CT.nodeId = UC.contentTypeId
JOIN umbracoNode UN WITH(NOLOCK) ON UN.id = UC.nodeId
WHERE CT.Alias = @Alias
