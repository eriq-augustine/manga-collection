DROP TABLE IF EXISTS Volumes;
DROP TABLE IF EXISTS LookupAttemptsAuthors;
DROP TABLE IF EXISTS LookupAttemptsTitles;
DROP TABLE IF EXISTS LookupAttempts;

CREATE TABLE LookupAttempts (
   id INT PRIMARY KEY AUTO_INCREMENT,
   informationSource VARCHAR(256) NOT NULL,
   identifier VARCHAR(32) NOT NULL,
   identifierFormat VARCHAR(32) NOT NULL,
   time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
   success BOOLEAN NOT NULL,
   -- Potential data
   language VARCHAR(32),
   country VARCHAR(32),
   seriesOrdinal INT,
   pages INT,
   isbn10 VARCHAR(10),
   isbn13 VARCHAR(13),
   publishedDate VARCHAR(32)
);

CREATE TABLE LookupAttemptsTitles (
   id INT PRIMARY KEY AUTO_INCREMENT,
   lookupId INT NOT NULL REFERENCES LookupAttempts(id),
   title VARCHAR(256) NOT NULL
);

CREATE TABLE LookupAttemptsAuthors (
   id INT PRIMARY KEY AUTO_INCREMENT,
   lookupId INT NOT NULL REFERENCES LookupAttempts(id),
   name VARCHAR(256) NOT NULL
);

CREATE TABLE Volumes (
   id INT PRIMARY KEY AUTO_INCREMENT,
   series INT REFERENCES Series(id),
   isbn10 VARCHAR(10),
   isbn13 VARCHAR(13),
   language VARCHAR(32),
   country VARCHAR(32),
   seriesOrdinal INT,
   pages INT,
   publishedDate VARCHAR(32),
   lookupAttempt INT NOT NULL UNIQUE REFERENCES LookupAttemts(id)
);
