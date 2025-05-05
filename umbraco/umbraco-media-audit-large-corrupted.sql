/*
  Created by: Piotr Bach
  Compatible with: Umbraco 8

  Description:
    This SQL script audits media items in Umbraco 8 with selected file extensions,
    identifying large files and potentially corrupted ones (with 0 or NULL size).
    It calculates file sizes, flags large files using a configurable threshold,
    and isolates the latest version per media item.

  Features:
    - Filters by extension (e.g., .tiff, .ai, .webp)
    - Computes size in bytes and megabytes
    - Flags:
        • IsLargeFile (based on @LargeFileThreshold)
        • IsCorrupted (size missing or zero)
    - Helps with content cleanup and performance tuning

  Related service:
    🔧 Umbraco Performance Tuning & Optimization  
    https://umbracare.net/services/umbraco-performance-tuning-and-optimization/
*/


-- List of file extensions to include
DECLARE @Extensions TABLE (ext NVARCHAR(10));
INSERT INTO @Extensions (ext)
VALUES
	('.png'),
    ('.jfif'),
    ('.tif'),
    ('.eps'),
    ('.xcf'),
    ('.tiff'),
    ('.webp'),
    ('.ai');

-- Minimum file size filter (in bytes)
DECLARE @MinFileSizeBytes BIGINT = 0;

-- Threshold above which a file is considered "large". 5,000,000 bytes ≈ 4.77 MB
DECLARE @LargeFileThreshold BIGINT = 5000000;

;WITH MediaWithSize AS (
	SELECT
		n.id AS MediaNodeId,
		n.text AS MediaName,
		ucv.id AS ContentVersionId,
		umv.id AS MediaVersionId,
		umv.path,

		-- Extract and cast file size
		CAST(pd.varcharValue AS BIGINT) AS FileSizeBytes,
		CAST(pd.varcharValue AS FLOAT) / 1024 / 1024 AS FileSizeMB,

		-- Flag: is the file larger than the defined threshold?
		CASE 
			WHEN CAST(pd.varcharValue AS BIGINT) >= @LargeFileThreshold THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
		END AS IsLargeFile,

		-- Flag: is the file corrupted (null or size = 0)?
		CASE 
			WHEN TRY_CAST(pd.varcharValue AS BIGINT) IS NULL OR TRY_CAST(pd.varcharValue AS BIGINT) = 0 THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
		END AS IsCorrupted,

		-- Only get the latest version per media node
		ROW_NUMBER() OVER (PARTITION BY n.id ORDER BY ucv.id DESC) AS RowNum
	FROM dbo.umbracoMediaVersion umv
	INNER JOIN dbo.umbracoContentVersion ucv ON umv.id = ucv.id
	INNER JOIN dbo.umbracoNode n ON ucv.nodeId = n.id
	INNER JOIN @Extensions e ON RIGHT(LOWER(umv.path), LEN(e.ext)) = e.ext
	INNER JOIN dbo.umbracoPropertyData pd ON pd.versionId = umv.id
	INNER JOIN dbo.cmsPropertyType pt ON pt.id = pd.propertyTypeId AND pt.alias = 'umbracoBytes'
	--WHERE n.id = 2749 -- Optional: remove this line to check all media items
)
SELECT *
FROM MediaWithSize
WHERE RowNum = 1
  AND FileSizeBytes >= @MinFileSizeBytes
  --AND IsLargeFile = 1
ORDER BY FileSizeBytes DESC;
