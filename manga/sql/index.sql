DROP INDEX IF EXISTS IX_Titles_seriesId ON Titles;
DROP INDEX IF EXISTS IX_Authorship_seriesId_authorId ON Authorship;
DROP INDEX IF EXISTS IX_Artistship_seriesId_artistId ON Artistship;
DROP INDEX IF EXISTS IX_Publishing_seriesId_publisherId ON Publishing;
DROP INDEX IF EXISTS IX_SeriesGenres_seriesId_genreId ON SeriesGenres;
DROP INDEX IF EXISTS IX_SeriesCategories_seriesId_categoryId ON SeriesCategories;
DROP INDEX IF EXISTS IX_Serializations_seriesId_publication ON Serializations;
DROP INDEX IF EXISTS IX_RelatedSeries_seriesId_relatedSeriesId ON RelatedSeries;
DROP INDEX IF EXISTS IX_Titles_seriesId_title ON Titles;
DROP INDEX IF EXISTS IX_AuthorNames_seriesId_name ON AuthorNames;

-- Base series linker.
-- This will cause some duplicated index prefixes, but these will be better for index merges.
CREATE INDEX IX_Titles_seriesId ON Titles(seriesId);
CREATE INDEX IX_Authorship_seriesId_authorId ON Authorship(seriesId, authorId);
CREATE INDEX IX_Artistship_seriesId_artistId ON Artistship(seriesId, artistId);
CREATE INDEX IX_Publishing_seriesId_publisherId ON Publishing(seriesId, publisherId);
CREATE INDEX IX_SeriesGenres_seriesId_genreId ON SeriesGenres(seriesId, genreId);
CREATE INDEX IX_SeriesCategories_seriesId_categoryId ON SeriesCategories(seriesId, categoryId);
CREATE INDEX IX_Serializations_seriesId_publication ON Serializations(seriesId, publication);
CREATE INDEX IX_RelatedSeries_seriesId_relatedSeriesId ON RelatedSeries(seriesId, relatedSeriesId);

-- Query optimizers.

CREATE INDEX IX_Titles_seriesId_title ON Titles(seriesId, title);

CREATE INDEX IX_AuthorNames_authorId_name ON AuthorNames(authorId, name);
