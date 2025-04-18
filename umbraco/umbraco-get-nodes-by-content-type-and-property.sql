/*
    Script: umbraco-get-nodes-by-content-type-and-property.sql
    Description:
    This script retrieves all Umbraco nodes from the database 
    that belong to a specific content type (e.g., 'message') 
    and contain a property with a specific alias (e.g., 'text').

    It joins umbracoNode, umbracoContent, umbracoContentVersion,
    cmsPropertyType, and umbracoPropertyData to extract the current 
    version of each content node along with the value of the specified property.

    Compatible with: Umbraco 13
*/

DECLARE @ContentTypeAlias NVARCHAR(255) = 'message';
DECLARE @PropertyAlias NVARCHAR(255) = 'text';

-- Get contentTypeId
DECLARE @ContentTypeId INT = (
    SELECT TOP 1 nodeId
    FROM [cmsContentType]
    WHERE alias = @ContentTypeAlias
);

-- Get propertyTypeId
DECLARE @PropertyTypeId INT = (
    SELECT TOP 1 id
    FROM [cmsPropertyType]
    WHERE contentTypeId = @ContentTypeId
      AND alias = @PropertyAlias
);

-- Final query
SELECT 
    un.id AS NodeId,
    un.[text] AS NodeName,
    cv.versionDate,
    pt.alias AS PropertyAlias,
    pd.[textValue] AS Value
FROM [umbracoNode] un
JOIN [umbracoContent] uc ON uc.nodeId = un.id
JOIN [umbracoContentVersion] cv ON cv.nodeId = un.id AND cv.[current] = 1
JOIN [cmsPropertyType] pt ON pt.contentTypeId = @ContentTypeId AND pt.alias = @PropertyAlias
JOIN [umbracoPropertyData] pd ON pd.versionId = cv.id AND pd.propertyTypeId = pt.id
WHERE uc.contentTypeId = @ContentTypeId
ORDER BY cv.versionDate DESC;
