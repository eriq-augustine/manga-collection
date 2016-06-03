require 'nokogiri'

require '../util/util.rb'

# Targets:
#  Title (Primary)
#  Alternate Names
#  Type (What are the types beside manga?)
#  Related Series (Parse out id)
#  Genres
#  Categories
#  Image (link)
#  Authors
#  Artists
#  Publisher
#  Year
#  Serialized In (magazine)
#  Licensed in English
#  English Publisher

# Maybe Targets:
#  Ratings
#  Status in origin country
#  Scantalized Status
#  Anime Start/End

# TARGET_DIR = 'test'
TARGET_DIR = 'raw/series'

FAIL_DIR = 'fail'
EMPTY_DIR = 'empty'

`mkdir -p #{FAIL_DIR}`
`mkdir -p #{EMPTY_DIR}`

# DEBUG = true
DEBUG = false

# TODO(eriq): Some lists should be distincted. (like authors (nick names make dups))
def cleanData(data)
   cleanData = Hash.new()

   debug("Start Clean")

   # Description
   if (getText(data['Description']) != 'N/A')
      cleanData['description'] = getText(data['Description'])
   end
   debug("Finished Clean: description")

   # Type
   cleanData['type'] = getText(data['Type']).downcase()
   debug("Finished Clean: type")

   # Titles
   cleanData['titles'] = [{:primary => true, :val => getText(data['title'])}]
   debug("Finished Clean: base title")

   # TODO(eriq): Check for single length ['N/A']
   # Associated Names
   cleanData['titles'] += getText(data['Associated Names']).split("\n").map{|title| {:primary => false, :val => title.strip()}}
   debug("Finished Clean: alt titles")

   # Genres
   cleanData['genres'] = []
   cleanData['genres'] += data['Genre'].css('a u').map{|ele| getText(ele).downcase()}.delete_if{|ele| ele == 'search for series of same genre(s)'}
   debug("Finished Clean: genres")

   # Image
   if (!['[Image Disabled for this Series]', 'N/A', 'You must login to see Hentai related images.'].include?(data['Image'].text().strip()))
      cleanData['image'] = data['Image'].css('img').attr('src').text().strip()
   end
   debug("Finished Clean: image")

   # Hentai?
   cleanData['hentai'] = false
   if (data['Image'].text().strip() == 'You must login to see Hentai related images.')
      cleanData['hentai'] = true
   end
   debug("Finished Clean: hentai")

   # Categories
   cleanData['categories'] = []
   cleanData['categories'] += data['Categories'].css('li.tag_normal a').map{|ele| getText(ele).downcase()}
   debug("Finished Clean: categories")

   # Year
   year = getText(data['Year'])
   if (year != 'N/A' && match = year.match(/^(\d{4})/))
      cleanData['year'] = match[1]
   end
   debug("Finished Clean: year")

   # Publisher
   # Get Id, not name.
   cleanData['publishers'] = []
   cleanData['publishers'] += data['Original Publisher'].css('a').map{|ele| ele.attr('href').strip().sub(/^.*\.html\?id=(\d+)$/, '\1')}
   debug("Finished Clean: publisher")

   # Serialized Magazine
   cleanData['serializations'] = []
   if (data['Serialized In (magazine)'].text().strip() != 'N/A')
      cleanData['serializations'] += data['Serialized In (magazine)'].css('a').map{|ele|
         {
            :idString => ele.attr('href').strip().sub(/^.*\.html\?pubname=(.+)$/, '\1'),
            :name => getText(ele.css('u'))
         }
      }
   end
   debug("Finished Clean: serialized in")

   # English License Status
   status = getText(data['Licensed (in English)']).downcase()
   if (status == 'no')
      cleanData['engLicense'] = false
   elsif (status == 'yes')
      cleanData['engLicense'] = true
   else
      $stderr.puts "Unknown license status: #{status}"
      exit
   end
   debug("Finished Clean: eng license")

   # English Publisher
   if (getText(data['English Publisher']) != 'N/A')
      cleanData['publishers'] += data['English Publisher'].css('a').map{|ele| ele.attr('href').strip().sub(/^.*\.html\?id=(\d+)$/, '\1')}
   end

   # Clean out publishers that are not actually in the db.
   cleanData['publishers'].delete_if{|publisher| publisher.include?('act=add_publisher')}

   debug("Finished Clean: end publisher")

   # Authors
   # Fetch ids, not names.
   cleanData['authors'] = data['Author(s)'].css('a[title="Author Info"]').map{|ele| ele.attr('href').strip().sub(/^.*\.html\?id=(\d+)$/, '\1')}
   debug("Finished Clean: authors")

   # Artists
   # Fetch ids, not names.
   cleanData['artists'] = data['Artist(s)'].css('a[title="Author Info"]').map{|ele| ele.attr('href').strip().sub(/^.*\.html\?id=(\d+)$/, '\1')}
   debug("Finished Clean: artists")

   # Related Series
   # Fetch ids, not names.
   cleanData['relatedSeries'] = []
   if (data['Related Series'].css('a').size() > 0)
      getText(data['Related Series']).split("\n").each{|ele|
         match = ele.match(/^<a href="series\.html\?id=(\d+)"><u>.+<\/u><\/a>\s*\((.+)\)/i)
         next if match == nil

         cleanData['relatedSeries'] << {
            :id => match[1],
            :relation => match[2].downcase()
         }
      }
   end
   debug("Finished Clean: related series")

   debug("Finished Clean")

   return cleanData
end

def parseFile(path)
   debug(path)

   docString = IO.read(path)

   if (docString.include?('You specified an invalid series id.'))
      debug("#{path} - Empty")
      `cp '#{path}' #{EMPTY_DIR}/`
      return nil
   end

   # Nokogiri freaks out on <br> when they are not self ending.
   docString.gsub!('<BR>', '<br />')
   docString.gsub!('<br>', '<br />')

   debug("Finished Empty Check")

   doc = Nokogiri::XML(docString)

   debug("Finished Doc parse")

   header = nil
   data = Hash.new()

   headers = doc.css('div.sCat > b').map{|ele| ele.text().strip()}
   contents = doc.css('div.sContent')

   if (headers.size() != contents.size())
      raise "Number of data headers (#{headers.size()}) does not match number of contents (#{contents.size()})"
   end

   headers.each_index{|i|
      data[headers[i]] = contents[i]
   }

   data['title'] = doc.css('span.releasestitle')

   debug("Finished Base Parse")

   return cleanData(data)
end

# {name => id}
genresMap = {}
categoriesMap = {}

# {id => data}
series = {}
titles = {}
genres = {}
categories = {}
publishers = {}
authors = {}
artists = {}
serializations = {}
relatedSeries = {}

Dir.glob("#{TARGET_DIR}/*.html").sort().each{|path|
   begin
      id = path.sub(/^.+\/(\d+)\.html$/, '\1')
      data = parseFile(path)
      if (data == nil)
         next
      end

      series[id] = data

      data['genres'].each{|genre|
         next if (genresMap.has_key?(genre))
         genresMap[genre] = genresMap.size() + 1
      }

      data['categories'].each{|category|
         next if (categoriesMap.has_key?(category))
         categoriesMap[category] = categoriesMap.size() + 1
      }

      if (data['titles'].size() > 0)
         titles[id] = data['titles'].uniq()
      end

      if (data['genres'].size() > 0)
         genres[id] = data['genres'].uniq()
      end

      if (data['categories'].size() > 0)
         categories[id] = data['categories'].uniq()
      end

      if (data['publishers'].size() > 0)
         publishers[id] = data['publishers'].uniq()
      end

      if (data['authors'].size() > 0)
         authors[id] = data['authors'].uniq()
      end

      if (data['artists'].size() > 0)
         artists[id] = data['artists'].uniq()
      end

      if (data['serializations'].size() > 0)
         serializations[id] = data['serializations'].uniq()
      end

      if (data['relatedSeries'].size() > 0)
         relatedSeries[id] = data['relatedSeries'].uniq()
      end
   rescue => ex
      debug("#{path} - Fail")
      $stderr.puts ex
      `cp '#{path}' #{FAIL_DIR}/`
   end
}

# Output

# Genres
puts "
   INSERT INTO Genres
      (id, name)
   VALUES
"

genresMap.each_with_index{|(name, key), i|
   puts "      (#{key}, #{stringOrNull(name)})#{i == genresMap.size() - 1 ? ';' : ','}"
}

# Categories
puts "
   INSERT INTO Categories
      (id, name)
   VALUES
"

categoriesMap.each_with_index{|(name, key), i|
   puts "      (#{key}, #{stringOrNull(name)})#{i == categoriesMap.size() - 1 ? ';' : ','}"
}

# Series
puts "
   INSERT INTO Series
      (id, type, description, image, isHentai, year, licensedInEnglish)
   VALUES
"

series.sort().each_with_index{|(key, seriesVal), i|
   puts "      (#{key}, #{stringOrNull(seriesVal['type'])}, #{stringOrNull(seriesVal['description'])}, #{stringOrNull(seriesVal['image'])}, #{boolOrNull(seriesVal['hentai'])}, #{intOrNull(seriesVal['year'])}, #{boolOrNull(seriesVal['engLicense'])})#{i == series.size() - 1 ? ';' : ','}"
}

# Titles
puts "
   INSERT INTO Titles
      (seriesId, title, isPrimary)
   VALUES
"

titles.sort().each_with_index{|(key, seriesTitles), i|
   seriesTitles.each_with_index{|title, j|
      lineEnd = (i == titles.size() - 1 && j == seriesTitles.size() - 1) ? ';' : ','
      puts "      (#{key}, #{stringOrNull(title[:val])}, #{boolOrNull(title[:primary])})#{lineEnd}"
   }
}

# Series Genres
puts "
   INSERT INTO SeriesGenres
      (seriesId, genreId)
   VALUES
"

genres.sort().each_with_index{|(key, seriesGenres), i|
   seriesGenres.each_with_index{|genre, j|
      lineEnd = (i == genres.size() - 1 && j == seriesGenres.size() - 1) ? ';' : ','
      puts "      (#{key}, #{intOrNull(genresMap[genre])})#{lineEnd}"
   }
}

# Series Authorship
puts "
   INSERT INTO Authorship
      (seriesId, authorId)
   VALUES
"

authors.sort().each_with_index{|(key, seriesAuthors), i|
   seriesAuthors.each_with_index{|author, j|
      lineEnd = (i == authors.size() - 1 && j == seriesAuthors.size() - 1) ? ';' : ','
      puts "      (#{key}, #{intOrNull(author)})#{lineEnd}"
   }
}

# Series Artistship
puts "
   INSERT INTO Artistship
      (seriesId, artistId)
   VALUES
"

artists.sort().each_with_index{|(key, seriesArtists), i|
   seriesArtists.each_with_index{|artist, j|
      lineEnd = (i == artists.size() - 1 && j == seriesArtists.size() - 1) ? ';' : ','
      puts "      (#{key}, #{intOrNull(artist)})#{lineEnd}"
   }
}

# Series Categories
puts "
   INSERT INTO SeriesCategories
      (seriesId, categoryId)
   VALUES
"

categories.sort().each_with_index{|(key, seriesCategories), i|
   seriesCategories.each_with_index{|category, j|
      lineEnd = (i == categories.size() - 1 && j == seriesCategories.size() - 1) ? ';' : ','
      puts "      (#{key}, #{stringOrNull(category)})#{lineEnd}"
   }
}

# Series Publishing
puts "
   INSERT INTO Publishing
      (seriesId, publisherId)
   VALUES
"

publishers.sort().each_with_index{|(key, seriesPublishers), i|
   seriesPublishers.each_with_index{|publisher, j|
      lineEnd = (i == publishers.size() - 1 && j == seriesPublishers.size() - 1) ? ';' : ','
      puts "      (#{key}, #{intOrNull(publisher)})#{lineEnd}"
   }
}

# Serializations
puts "
   INSERT INTO Serializations
      (seriesId, publication)
   VALUES
"

serializations.sort().each_with_index{|(key, seriesSerializations), i|
   seriesSerializations.each_with_index{|serialization, j|
      lineEnd = (i == serializations.size() - 1 && j == seriesSerializations.size() - 1) ? ';' : ','
      puts "      (#{key}, #{stringOrNull(serialization[:idString])})#{lineEnd}"
   }
}

# Related Series
puts "
   INSERT INTO RelatedSeries
      (seriesId, relatedSeriesId, relation)
   VALUES
"

relatedSeries.sort().each_with_index{|(key, seriesRelatedSeries), i|
   seriesRelatedSeries.each_with_index{|relatedSeriesVal, j|
      lineEnd = (i == relatedSeries.size() - 1 && j == seriesRelatedSeries.size() - 1) ? ';' : ','
      puts "      (#{key}, #{intOrNull(relatedSeriesVal[:id])}, #{stringOrNull(relatedSeriesVal[:relation])})#{lineEnd}"
   }
}
