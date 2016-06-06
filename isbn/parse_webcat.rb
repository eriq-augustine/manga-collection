require 'nokogiri'

require '../util/util.rb'

# TARGET_DIR = 'test'
TARGET_DIR = 'raw/webcat'

FAIL_DIR = 'fail'
EMPTY_DIR = 'empty'

# For speed, we are making up the lookup's id using the offset + sorted isbn index.
ID_OFFSET = 100000

INPUT_FILE_PATTERN = 'webcat_*.html'
INPUT_ID_REGEX = /^.+webcat_(\d+)\.html$/

`mkdir -p #{FAIL_DIR}`
`mkdir -p #{EMPTY_DIR}`

# DEBUG = true
DEBUG = false

def cleanData(data)
   cleanData = {}

   debug("Start Clean")

   # title (書名)
   cleanData['titles'] = [getText(data['書名'])]
   debug("Finished Clean: title")

   # author (著作者等)
   cleanData['authors'] = []
   if (data.has_key?('著作者等'))
      if (data['著作者等'].css('a').size() > 0)
         text = getText(data['著作者等'].css('a'))
      else
         text = getText(data['著作者等'])
      end

      cleanData['authors'] += text.split("\n").map{|name|
         # Non-English (usually Japanese) names should not have spaces.
         # name.match(/[a-z]/i) ? name.strip() : name.gsub(/\s/, '')
         name.strip()
      }
   end
   debug("Finished Clean: author")

   # reading title (書名ヨミ)
   if (data.has_key?('書名ヨミ'))
      cleanData['seriesTitle'] = getText(data['書名ヨミ'])
      cleanData['titles'] << getText(data['書名ヨミ'])
   end
   debug("Finished Clean: reading title")

   # alias (書名別名)
   if (data.has_key?('書名別名'))
      cleanData['titles'] += getText(data['書名別名']).split("\n").map{|name| name.strip()}
   end
   debug("Finished Clean: alias")

   # serialized magazine (シリーズ名)
   if (data.has_key?('シリーズ名'))
      cleanData['serializtion'] = getText(data['シリーズ名'].css('u'))
   end
   debug("Finished Clean: serialized magazine")

   # order in series (巻冊次)
   if (data.has_key?('巻冊次'))
      text = getText(data['巻冊次']).gsub(/[第巻]/, '').sub(/^\D*(\d+)\D*$/, '\1')

      if (text.length() < 4 && text.match(/^\d+$/) && !text.include?("\n"))
         cleanData['orderInSeries'] = text
      end
   end
   debug("Finished Clean: order in series")

   # publisher (出版元)
   if (data.has_key?('出版元'))
      cleanData['publisher'] = getText(data['出版元'])
   end
   debug("Finished Clean: publisher")

   # issue date (刊行年月)
   if (data.has_key?('刊行年月'))
      cleanData['issueDate'] = getText(data['刊行年月'])
   end
   debug("Finished Clean: issue date")

   # page count (ページ数)
   if (data.has_key?('ページ数'))
      pages = getText(data['ページ数'])
      if (match = pages.match(/^(\d+)\s*p?$/))
         cleanData['pageCount'] = match[1]
      end
   end
   debug("Finished Clean: page count")

   # physical size (大きさ)
   if (data.has_key?('大きさ'))
      cleanData['physicalSize'] = getText(data['大きさ'])
   end
   debug("Finished Clean: physical size")

   # isbn (ISBN)
   if (data.has_key?('ISBN'))
      cleanData['isbn'] = getText(data['ISBN'])

      if (cleanData['isbn'].length() == 10)
         cleanData['isbn10'] = cleanData['isbn']
      elsif (cleanData['isbn'].length() == 13)
         cleanData['isbn13'] = cleanData['isbn']
      end
   end
   debug("Finished Clean: isbn")

   # national bibliography number (全国書誌番号)
   if (data.has_key?('全国書誌番号'))
      cleanData['nationalBibNumber'] = getText(data['全国書誌番号'].css('a span.nbn'))
   end
   debug("Finished Clean: national bibliography number")

   # language of origin (言語)
   if (data.has_key?('言語'))
      cleanData['originLang'] = langCountryReplacement(getText(data['言語']).gsub("\n", ', '))
   end
   debug("Finished Clean: language of origin")

   # country of origin (出版国)
   if (data.has_key?('出版国'))
      cleanData['originCountry'] = langCountryReplacement(getText(data['出版国']).gsub("\n", ', '))
   end
   debug("Finished Clean: country of origin")

   if (DEBUG)
      cleanData.each_pair{|key, val|
         puts key
         puts val
         puts "---"
      }
   end

   debug("Finished Clean")

   return cleanData
end

def parseFile(path)
   debug(path)

   docString = IO.read(path)

   if (docString.include?('/externals/images/txt-notfound-01.gif'))
      debug("#{path} - Empty")
      `cp '#{path}' #{EMPTY_DIR}/`
      return nil
   end

   # Nokogiri freaks out on <br> when they are not self ending.
   docString.gsub!('<BR>', '<br />')
   docString.gsub!('<br>', '<br />')

   docString.gsub!('<div class="separater"><hr /></div>', '<br />')

   debug("Finished Empty Check")

   doc = Nokogiri::XML(docString)

   debug("Finished Doc parse")

   data = Hash.new()

   doc.css('div.table-C table tr').each{|ele|
      data[getText(ele.css('th')[0])] = ele.css('td')[0]
   }

   debug("Finished Base Parse")

   return cleanData(data)
end

empties = []

ids = {}
volumes = {}
titles = {}
authors = {}

count = 0
Dir.glob("#{TARGET_DIR}/#{INPUT_FILE_PATTERN}").sort().each{|path|
   begin
      id = path.sub(INPUT_ID_REGEX, '\1')

      ids[id] = ID_OFFSET + count
      count += 1

      data = parseFile(path)
      if (data == nil)
         empties << id
         next
      end

      volumes[id] = data

      if (data['titles'] != nil && data['titles'].size() > 0)
         titles[id] = data['titles'].uniq()
      end

      if (data['authors'] != nil && data['authors'].size() > 0)
         authors[id] = data['authors'].uniq()
      end
   rescue => ex
      debug("#{path} - Fail")
      $stderr.puts ex
      `cp '#{path}' #{FAIL_DIR}/`
   end
}

# Output

# Empties
puts "
   INSERT INTO LookupAttempts
      (id, informationSource, identifier, success)
   VALUES
"
puts empties.sort().map{|id| "      (#{ids[id]}, 'webcat', #{id}, FALSE)"}.join(",\n")
puts ";"

# Volumes
puts "
   INSERT INTO LookupAttempts
      (id, informationSource, identifier, identifierFormat, success, language, country, seriesOrdinal, pages, isbn10, isbn13, publishedDate)
   VALUES
"

volumes.sort().each_with_index{|(key, volume), i|
   puts "      (#{ids[key]}, 'webcat', #{key}, 'EAN_13', TRUE, #{stringOrNull(volume['originLang'])}, #{stringOrNull(volume['originCountry'])}, #{intOrNull(volume['orderInSeries'])}, #{intOrNull(volume['pageCount'])}, #{stringOrNull(volume['isbn10'])}, #{stringOrNull(volume['isbn13'])}, #{stringOrNull(volume['publishedDate'])})#{i == volumes.size() - 1 ? ';' : ','}"
}

# titles

puts "
   INSERT INTO LookupAttemptsTitles
      (lookupId, title)
   VALUES
"

titles.sort().each_with_index{|(key, seriesTitles), i|
   seriesTitles.each_with_index{|title, j|
      lineEnd = (i == titles.size() - 1 && j == seriesTitles.size() - 1) ? ';' : ','
      puts "      (#{ids[key]}, #{stringOrNull(title)})#{lineEnd}"
   }
}

# authors

puts "
   INSERT INTO LookupAttemptsAuthors
      (lookupId, name)
   VALUES
"

authors.sort().each_with_index{|(key, seriesAuthors), i|
   seriesAuthors.each_with_index{|author, j|
      lineEnd = (i == authors.size() - 1 && j == seriesAuthors.size() - 1) ? ';' : ','
      puts "      (#{ids[key]}, #{stringOrNull(author)})#{lineEnd}"
   }
}
