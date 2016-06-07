SELECT *
FROM (
   SELECT 'Attempts' AS recordType, LT.lookupId AS id, LT.title
   FROM LookupAttemptsTitles LT
   WHERE NOT EXISTS (SELECT * FROM Volumes WHERE lookupAttempt = LT.lookupId)

   UNION

   SELECT 'Reference' AS recordType, T.seriesId AS id, T.title
   FROM Titles T
) X
ORDER BY
   title,
   recordType,
   id
;
