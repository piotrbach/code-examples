-- Description:
--   This SQL script is designed for **Umbraco 8** installations using SQL Server.
--   It selects all media items from the `umbracoMediaVersion` table that match
--   a list of specified file extensions (e.g. `.ai`, `.psd`, `.exe`, etc.).
-- 
-- Usage:
--   1. Define your desired extensions in the @Extensions table variable.
--   2. The script performs a case-insensitive match on the file path.
--   3. Joins with `umbracoContentVersion` to return full media metadata.
--
-- Compatible with:
--   ✅ Umbraco 8.x
--   ✅ SQL Server 2016+
--
-- Example output:
--   - Media ID, Name, File Path, and all related version data.

DECLARE @Extensions TABLE (ext NVARCHAR(10));
INSERT INTO @Extensions (ext)
VALUES
    ('.ai'),
    ('.psd'),
    ('.exe'),
    ('.zip'),
    ('.mov');

SELECT 
    ucv.*,
    umv.*
FROM [dbo].[umbracoMediaVersion] umv
INNER JOIN [dbo].[umbracoContentVersion] ucv ON umv.id = ucv.id
INNER JOIN @Extensions e ON RIGHT(LOWER(umv.[path]), LEN(e.ext)) = e.ext
