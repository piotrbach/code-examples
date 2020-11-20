BEGIN TRAN

/* SQL: Delete Umbraco user by email */

DECLARE @userId INT = (
		SELECT id
		FROM [dbo].[umbracoUser]
		WHERE userLogin = 'hello@piotrbach.com'
		);

UPDATE [dbo].[umbracoContentVersion]
SET userId = NULL
WHERE userId = @userId;

UPDATE [dbo].[umbracoNode]
SET nodeUser = NULL
WHERE nodeUser = @userId;

UPDATE [dbo].[umbracoLog]
SET userId = NULL
WHERE userId = @userId;

DELETE
FROM [dbo].[umbracoUser2UserGroup]
WHERE userId = @userId;

DELETE
FROM [dbo].[umbracoUserLogin]
WHERE userId = @userId;

DELETE
FROM [dbo].[umbracoUser2NodeNotify]
WHERE userId = @userId;

DELETE
FROM [dbo].[umbracoUserStartNode]
WHERE userId = @userId;

DELETE
FROM [dbo].[umbracoUser]
WHERE id = @userId;

ROLLBACK TRAN -- COMMIT TRAN