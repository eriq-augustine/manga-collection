DROP TABLE IF EXISTS RelatedSeries;
DROP TABLE IF EXISTS Serializations;
DROP TABLE IF EXISTS SeriesCategories;
DROP TABLE IF EXISTS SeriesGenres;
DROP TABLE IF EXISTS Publishing;
DROP TABLE IF EXISTS Artistship;
DROP TABLE IF EXISTS Authorship;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Genres;
DROP TABLE IF EXISTS PublisherNames;
DROP TABLE IF EXISTS Publications;
DROP TABLE IF EXISTS Publishers;
DROP TABLE IF EXISTS AuthorNames;
DROP TABLE IF EXISTS Authors;
DROP TABLE IF EXISTS Titles;
DROP TABLE IF EXISTS Series;

CREATE TABLE Series (
   id INT PRIMARY KEY AUTO_INCREMENT,
   type ENUM('artbook', 'doujinshi', 'drama cd', 'manga', 'manhua', 'manhwa', 'novel', 'oel'),
   description TEXT,
   image VARCHAR(256),
   isHentai BOOLEAN NOT NULL DEFAULT FALSE,
   year INT NOT NULL,
   licensedInEnglish BOOLEAN
);

CREATE TABLE Titles (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   title VARCHAR(256) NOT NULL,
   isPrimary BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE Authors (
   id INT PRIMARY KEY AUTO_INCREMENT,
   image VARCHAR(256),
   birthPlace VARCHAR(64),
   birthDay VARCHAR(64),
   zodiac ENUM('Aquarius', 'Aries', 'Cancer', 'Capricorn', 'Gemini', 'Leo', 'Libra', 'Pisces', 'Sagittarius', 'Scorpio', 'Taurus', 'Virgo'),
   comments TEXT,
   bloodType ENUM('A', 'B', 'AB', 'O'),
   gender ENUM('female', 'male', 'transgender', 'other'),
   website VARCHAR(256),
   twitter VARCHAR(256),
   facebook VARCHAR(256)
);

CREATE TABLE AuthorNames (
   id INT PRIMARY KEY AUTO_INCREMENT,
   authorId INT NOT NULL REFERENCES Authors(id),
   name VARCHAR(256) NOT NULL,
   isPrimary BOOLEAN NOT NULL DEFAULT FALSE,
   isNative BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE Publishers (
   id INT PRIMARY KEY AUTO_INCREMENT,
   type ENUM('chinese', 'english', 'japanese', 'korean', 'taiwanese'),
   notes TEXT,
   website VARCHAR(256)
);

CREATE TABLE PublisherNames (
   id INT PRIMARY KEY AUTO_INCREMENT,
   publisherId INT NOT NULL REFERENCES Publishers(id),
   name VARCHAR(256) NOT NULL,
   isPrimary BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE Publications (
   id INT PRIMARY KEY AUTO_INCREMENT,
   publisherId INT NOT NULL REFERENCES Publishers(id),
   idString VARCHAR(128) NOT NULL UNIQUE,
   name VARCHAR(256) NOT NULL
);

CREATE TABLE Genres (
   id INT PRIMARY KEY AUTO_INCREMENT,
   name VARCHAR(256) NOT NULL
);

CREATE TABLE Categories (
   id INT PRIMARY KEY AUTO_INCREMENT,
   name VARCHAR(256) NOT NULL
);

CREATE TABLE Authorship (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   authorId INT NOT NULL REFERENCES Authors(id)
);

CREATE TABLE Artistship (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   artistId INT NOT NULL REFERENCES Authors(id)
);

CREATE TABLE Publishing (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   publisherId INT NOT NULL REFERENCES Publishers(id)
);

CREATE TABLE SeriesGenres (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   genreId INT NOT NULL REFERENCES Genres(id)
);

CREATE TABLE SeriesCategories (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   categoryId INT NOT NULL REFERENCES Categories(id)
);

CREATE TABLE Serializations (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   publication VARCHAR(128) REFERENCES Publications(idString)
);

-- Not bidirectional.
CREATE TABLE RelatedSeries (
   id INT PRIMARY KEY AUTO_INCREMENT,
   seriesId INT NOT NULL REFERENCES Series(id),
   relatedSeriesId INT NOT NULL REFERENCES Series(id),
   relation ENUM('adapted from', 'alternate story', 'main story', 'prequel', 'sequel', 'side story', 'spin-off')
);
