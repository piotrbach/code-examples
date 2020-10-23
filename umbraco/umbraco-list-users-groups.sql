SELECT umbracoUser.id,
       umbracoUser.userLogin,
       umbracoUser.userName,
       umbracoUserGroup.userGroupName,
       umbracoUserGroup.userGroupAlias
FROM [umbracoUser] umbracoUser
JOIN [umbracoUser2UserGroup] umbracoUser2UserGroup ON umbracoUser.id = umbracoUser2UserGroup.userId
JOIN [umbracoUserGroup] umbracoUserGroup ON umbracoUserGroup.id = umbracoUser2UserGroup.userGroupId
ORDER BY umbracoUser.userName ASC