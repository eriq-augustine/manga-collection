DROP INDEX IF EXISTS IX_LookupAttemptsTitles_seriesId ON LookupAttemptsTitles;
DROP INDEX IF EXISTS IX_LookupAttemptsAuthors_seriesId ON LookupAttemptsAuthors;
DROP INDEX IF EXISTS IX_Volumes_lookupAttempt ON Volumes;

CREATE INDEX IX_LookupAttemptsTitles_seriesId ON LookupAttemptsTitles(title, lookupId);
CREATE INDEX IX_LookupAttemptsAuthors_seriesId ON LookupAttemptsAuthors(name, lookupId);

CREATE INDEX IX_Volumes_lookupAttempt ON Volumes(lookupAttempt);
