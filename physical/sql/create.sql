DROP TABLE IF EXISTS PhysicalScans;

CREATE TABLE PhysicalScans (
   id INT PRIMARY KEY AUTO_INCREMENT,
   boxId INT NOT NULL,
   rawIdentifier VARCHAR(32) NOT NULL,
   rawFormatGuess VARCHAR(32),
   scanTime INT NOT NULL,
   volume INT REFERENCES Volumes(id)
);
