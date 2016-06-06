require 'nokogiri'

require '../util/util.rb'

# TARGET_DIR = 'test'
TARGET_DIR = 'raw/ndlopac'

FAIL_DIR = 'fail'
EMPTY_DIR = 'empty'

# For speed, we are making up the lookup's id using the offset + sorted isbn index.
ID_OFFSET = 200000

INPUT_FILE_PATTERN = 'ndlopac_*.html'
INPUT_ID_REGEX = /^.+ndlopac_(\d+)\.html$/

`mkdir -p #{FAIL_DIR}`
`mkdir -p #{EMPTY_DIR}`

# DEBUG = true
DEBUG = false

def cleanData(data)
   cleanData = {}

   debug("Start Clean")

   # タイトル (Title)
   cleanData['titles'] = []
   if (data.has_key?('タイトル'))
      cleanData['titles'] << getText(data['タイトル'].css('a')).sub(/\s*\.$/, '').sub(/\/$/, '').strip()
   end
   debug("Finished Clean: タイトル (Title)")

   # タイトルよみ (Title reading)
   if (data.has_key?('タイトルよみ'))
      cleanData['titles'] << getText(data['タイトルよみ']).sub(/\s*\.$/, '').sub(/\/$/, '').strip()
   end
   debug("Finished Clean: タイトルよみ (Title reading)")

   # Author format: "<author>(, <author>)* || <author reading>(, <author reading>)*"

   # 個人著者標目 (Personal author)
   cleanData['authors'] = []
   if (data.has_key?('個人著者標目'))
      cleanData['authors'] += getText(data['個人著者標目'].css('a')).sub(/\s*\.$/, '').split(/,|\|\|/).map{|name| name.strip()}
   end
   debug("Finished Clean: 個人著者標目 (Personal author)")

   # 団体著者標目 (Original author)
   if (data.has_key?('団体著者標目'))
      cleanData['authors'] += getText(data['団体著者標目'].css('a')).sub(/\s*\.$/, '').split(/,|\|\|/).map{|name| name.strip()}
   end
   debug("Finished Clean: 団体著者標目 (Personal author)")

   cleanData['authors'].delete_if{|name| name.match(/^\d{4}-(\d{4})?$/)}

   # ISBN
   getText(data['ISBN']).split(':').each{|isbn|
      if (isbn.include?('(エラーコード)'))
         next
      end

      cleanData['isbn'] = isbn.gsub(/[\-\s]/, '')

      if (cleanData['isbn'].length() == 10)
         cleanData['isbn10'] = cleanData['isbn']
      elsif (cleanData['isbn'].length() == 13)
         cleanData['isbn13'] = cleanData['isbn']
      else
         raise("Unknown ISBN length (#{cleanData['isbn']})")
      end
   }
   debug("Finished Clean: ISBN")

   # シリーズ (serialized magazine)
   if (data.has_key?('シリーズ'))
      cleanData['serializtion'] = getText(data['シリーズ'].css('a')).sub(/\s*\.$/, '') 
   end
   debug("Finished Clean: シリーズ (series)")

   # 国名コード (Country code)
   if (data.has_key?('国名コード'))
      cleanData['country'] = langCountryReplacement(getText(data['国名コード']))
   end
   debug("Finished Clean: 国名コード (Country code)")

   # 本文の言語 (the body of the language)
   if (data.has_key?('本文の言語'))
      cleanData['lang'] = langCountryReplacement(getText(data['本文の言語']))
   end
   debug("Finished Clean: 本文の言語 (the body of the language)")

   # 出版事項 (publishing matters)
   if (data.has_key?('出版事項'))
      match = getText(data['出版事項']).match(/(\d{4})\.(\d{1,2})\.$/)
      if (match)
         cleanData['publishedDate'] = "#{match[1]}/#{"%02d" % match[2]}"
      end
   end
   debug("Finished Clean: 出版事項 (publishing matters)")

   # 形態/付属資料 (form / Annex)
   if (data.has_key?('形態/付属資料'))
      match = getText(data['形態/付属資料']).match(/^(\d+)p\s+;\s+(\d+)cm\.$/)
      if (match)
         cleanData['pageCount'] = match[1]
         cleanData['sizeCM'] = match[2]
      end
   end
   debug("Finished Clean: 形態/付属資料 (form / Annex)")
   
   if (DEBUG)
      cleanData.each_pair{|key, val|
         puts key
         puts val
         puts "---"
      }
   end

   debug("Finished Clean")

   return cleanData

   # Other keys
   # 責任表示 (responsibility display)
   # 資料種別 (material designation)
   # 請求記号 (Billing symbol)
   # 書誌ID (bibliography ID)
   # -所蔵場所ごと (- each of Fine location)
   # 全国書誌番号 (national bibliography number)
   # 価格等 (price, etc.)
   # NDLC
   # NDC(9)
end

def parseFile(path)
   debug(path)

   docString = IO.read(path)

   if (docString.include?('一致するデータは見つかりませんでした。'))
      debug("#{path} - Empty")
      `cp '#{path}' #{EMPTY_DIR}/`
      return nil
   end

   # Nokogiri freaks out on <br> when they are not self ending.
   docString.gsub!('<BR>', '<br />')
   docString.gsub!('<br>', '<br />')

   docString.gsub!(' width=180 ', ' ')
   docString.gsub!('<div id=h></div>', '')
   docString.gsub!('HREF=', "href=")
   docString.gsub!('<A ', "<a ")
   docString.gsub!('</A>', "</a>")

   # There are many unquoted links.
   docString.gsub!('href=http', "href='http")
   docString.gsub!('sub_library=>', "sub_library='>")
   docString.gsub!('sub_library=ILSJ>', "sub_library=ILSJ'>")
   docString.gsub!('sub_library=KSBU>', "sub_library=KSBU'>")
   docString.gsub!('sub_library=TMTS>', "sub_library=TMTS'>")

   debug("Finished Empty Check")

   doc = Nokogiri::XML(docString)

   debug("Finished Doc parse")

   data = Hash.new()

   doc.css('table.borderColor2 table tr').each{|ele|
      if (ele.element_children.size() != 2)
         raise("tr does not have two children")
      end

      label = getText(ele.element_children[0].css('b'))
      if (label == '')
         next
      end

      data[label] = ele.element_children[1]
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
puts empties.sort().map{|id| "      (#{ids[id]}, 'ndlopac', #{id}, FALSE)"}.join(",\n")
puts ";"

# Volumes
puts "
   INSERT INTO LookupAttempts
      (id, informationSource, identifier, identifierFormat, success, language, country, pages, isbn10, isbn13, publishedDate)
   VALUES
"

volumes.sort().each_with_index{|(key, volume), i|
   puts "      (#{ids[key]}, 'ndlopac', #{key}, 'EAN_13', TRUE, #{stringOrNull(volume['lang'])}, #{stringOrNull(volume['country'])}, #{intOrNull(volume['pageCount'])}, #{stringOrNull(volume['isbn10'])}, #{stringOrNull(volume['isbn13'])}, #{stringOrNull(volume['publishedDate'])})#{i == volumes.size() - 1 ? ';' : ','}"
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
