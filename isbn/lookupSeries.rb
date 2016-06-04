require 'mysql'

def linkVolume(db, lookupId, seriesId)
   sql = "
      INSERT INTO Volumes
         (series, isbn10, isbn13, language, country, seriesOrdinal, pages, publishedDate, lookupAttempt)
      SELECT
         #{seriesId},
         isbn10,
         COALESCE(isbn13, CASE WHEN identifierFormat = 'EAN_13' THEN identifier ELSE NULL END),
         language,
         country,
         seriesOrdinal,
         pages,
         publishedDate,
         #{lookupId}
      FROM LookupAttempts
      WHERE id = #{lookupId}
   "
   db.query(sql)

   volumeId = db.insert_id()

   sql = "
      UPDATE
         PhysicalScans P
         JOIN LookupAttempts L ON
            L.identifier = P.rawIdentifier
            AND L.identifierFormat = P.rawFormatGuess
      SET P.volume = #{volumeId}
      WHERE L.id = #{lookupId}
   "
   db.query(sql)
end

def lookupTitleAuthorExact(db)
   sql = "
      SELECT
         LT.lookupId,
         MIN(T.seriesId)
      FROM
         LookupAttemptsTitles LT
         JOIN Titles T ON T.title = LT.title
         JOIN LookupAttemptsAuthors LA ON LA.lookupId = LT.lookupId
         JOIN AuthorNames A ON A.name = LA.name
         JOIN Authorship ASP ON
            ASP.authorId = A.authorId
            AND ASP.seriesId = T.seriesId
      WHERE NOT EXISTS (SELECT * FROM Volumes WHERE lookupAttempt = LT.lookupId)
      GROUP BY LT.lookupId
      HAVING COUNT(DISTINCT T.seriesId) = 1
   "
   res = db.query(sql)

   rtn = []
   res.each{|lookupId, seriesId|
      rtn << {:lookupId => lookupId, :seriesId => seriesId}
   }
   res.free()

   return rtn
end

db = Mysql::new("localhost", "", "", "manga", 3306, '/media/media/mysql/mysql.sock')

ids = lookupTitleAuthorExact(db)
ids.each{|idSet|
   # puts "#{idSet[:lookupId]} -- #{idSet[:seriesId]}"
   linkVolume(db, idSet[:lookupId], idSet[:seriesId])
}
