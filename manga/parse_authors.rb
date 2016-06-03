require 'nokogiri'

require '../util/util.rb'

# TARGET_DIR = 'test'
TARGET_DIR = 'raw/authors'

FAIL_DIR = 'fail'
EMPTY_DIR = 'empty'

`mkdir -p #{FAIL_DIR}`
`mkdir -p #{EMPTY_DIR}`

# DEBUG = true
DEBUG = false

def cleanData(data)
   cleanData = Hash.new()

   debug("Start Clean")

   if (data.has_key?('image') && data['image'] != nil && data['image'].size() > 0 && getText(data['image']) != 'N/A')
      cleanData['image'] = data['image'].attr('src').content().strip()
   end
   debug("Finished Clean: image")

   cleanData['names'] = []

   cleanData['names'] << {
      :primary => true,
      :native => false,
      :val => getText(data['name'])
   }
   debug("Finished Clean: primary name")

   if (getText(data['altNames']) != 'N/A')
      cleanData['names'] += getText(data['altNames']).split("\n").map{|name|
         {
            :primary => false,
            :native => false,
            :val => name.strip()
         }
      }
   end
   debug("Finished Clean: alt names")

   if (data.has_key?('nativeName') && getText(data['nativeName']) != 'N/A')
      cleanData['names'] << {
         :primary => false,
         :native => true,
         :val => getText(data['nativeName'])
      }
   end
   debug("Finished Clean: native name")

   if (getText(data['birthPlace']) != 'N/A')
      cleanData['birthPlace'] = getText(data['birthPlace'])
   end
   debug("Finished Clean: birth place")

   if (getText(data['birthDay']) != 'N/A')
      cleanData['birthDay'] = getText(data['birthDay'])
   end
   debug("Finished Clean: birth day")

   if (getText(data['zodiac']) != 'N/A')
      cleanData['zodiac'] = getText(data['zodiac'])
   end
   debug("Finished Clean: zodiac")

   comments = getText(data['comments'])
   if (comments != 'N/A')
      cleanData['comments'] = comments
   end
   debug("Finished Clean: comments")

   if (getText(data['bloodType']) != 'N/A')
      cleanData['bloodType'] = getText(data['bloodType'])
   end
   debug("Finished Clean: blood type")

   if (getText(data['gender']) != 'N/A')
      cleanData['gender'] = getText(data['gender']).downcase()
   end
   debug("Finished Clean: gender")

   if (data.has_key?('website') && data['website'] != nil && data['website'].size() > 0)
      if (data['website'].size() > 1)
         raise "Too many websites"
      end

      cleanData['website'] = data['website'].attr('href').content().strip()
   end
   debug("Finished Clean: website")

   if (data.has_key?('twitter') && data['twitter'] != nil && data['twitter'].size() > 0)
      if (data['twitter'].size() > 1)
         raise "Too many twitters"
      end

      cleanData['twitter'] = data['twitter'].attr('href').content().strip()
   end
   debug("Finished Clean: twitter")

   if (data.has_key?('facebook') && data['facebook'] != nil && data['facebook'].size() > 0)
      if (data['facebook'].size() > 1)
         raise "Too many facebooks"
      end

      cleanData['facebook'] = data['facebook'].attr('href').content().strip()
   end
   debug("Finished Clean: facebook")

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
   debug("Start read")

   docString = IO.read(path)

   debug("End read")

   if (docString.include?('You specified an invalid author id.'))
      debug("#{path} - Empty")
      `cp '#{path}' #{EMPTY_DIR}/`
      return nil
   end

   debug("Finished Empty Check")

   # Nokogiri freaks out on <br> when they are not self ending.
   docString.gsub!('<BR>', '<br />')
   docString.gsub!('<br>', '<br />')

   # Also freaks out when the img is not closed.
   docString.gsub!('.jpg\'></center>', '.jpg\' /></center>')
   docString.gsub!('.png\'></center>', '.png\' /></center>')
   docString.gsub!('.gif\'></center>', '.png\' /></center>')

   # emojis are weird.
   # Ideally we would replace the emoji, but doing a regex before the document parse can
   # fail because of encoding issues, so just close the emoji image so nokogiri doesn't freak out.
   docString.gsub!('\'><!--emo_end-->', '\' /><!--emo_end-->')

   debug("Finished String Replacements")

   doc = Nokogiri::XML(docString)

   debug("Finished Doc parse")

   data = Hash.new()

   data['name'] = doc.css('span.tabletitle b')

   leftElements = doc.css('tr > td.text[bgcolor="#E4E7EB"]')[0].parent().parent().element_children()

   # 01 -- Image
   data['image'] = leftElements[1].css('img')

   # 04 -- Alt Names
   data['altNames'] = leftElements[4].css('td')

   # 07 -- Native Name
   data['nativeName'] = leftElements[7].css('td')

   # 10 -- Birth Place
   data['birthPlace'] = leftElements[10].css('td')

   # 13 -- Birth Day (not year)
   data['birthDay'] = leftElements[13].css('td')

   # 16 -- Zodiac
   data['zodiac'] = leftElements[16].css('td')

   # 19 -- Last Updated
   data['lastUpdated'] = leftElements[19].css('td')

   rightElements = doc.css('tr > td.text[bgcolor="#E4E7EB"]')[7].parent().parent().element_children()

   # 01 -- Comments
   data['comments'] = rightElements[1].css('td')

   # 04 -- Blood Type
   data['bloodType'] = rightElements[4].css('td')

   # 07 -- Gender
   data['gender'] = rightElements[7].css('td')

   # 13 -- Website
   data['website'] = rightElements[13].css('td > a')

   # 16 -- Twitter
   data['twitter'] = rightElements[16].css('td > a')

   # 19 -- Facebook
   data['facebook'] = rightElements[19].css('td > a')

   debug("Finished Base Parse")

   return cleanData(data)
end

authors = {}
names = {}

Dir.glob("#{TARGET_DIR}/author_*.html").sort().each{|path|
   begin
      id = path.sub(/^.+author_(\d+)\.html$/, '\1')
      data = parseFile(path)
      if (data == nil)
         next
      end

      authors[id] = data

      if (data['names'].size() > 0)
         names[id] = data['names'].uniq()
      end
   rescue => ex
      debug("#{path} - Fail")
      $stderr.puts ex
      `cp '#{path}' #{FAIL_DIR}/`
   end
}

# Output

puts "
   INSERT INTO Authors
      (id, image, birthPlace, birthDay, zodiac, comments, bloodType, gender, website, twitter, facebook)
   VALUES
"

authors.sort().each_with_index{|(key, author), i|
   puts "      (#{key}, #{stringOrNull(author['image'])}, #{stringOrNull(author['birthPlace'])}, #{stringOrNull(author['birthDay'])}, #{stringOrNull(author['zodiac'])}, #{stringOrNull(author['comments'])}, #{stringOrNull(author['bloodType'])}, #{stringOrNull(author['gender'])}, #{stringOrNull(author['website'])}, #{stringOrNull(author['twitter'])}, #{stringOrNull(author['facebook'])})#{i == authors.size() - 1 ? ';' : ','}"
}

puts "
   INSERT INTO AuthorNames
      (authorId, name, isPrimary, isNative)
   VALUES
"

names.sort().each_with_index{|(key, authorNames), i|
   authorNames.each_with_index{|authorName, j|
      lineEnd = (i == names.size() - 1 && j == authorNames.size() - 1) ? ';' : ','
      puts "      (#{key}, #{stringOrNull(authorName[:val])}, #{boolOrNull(authorName[:primary])}, #{boolOrNull(authorName[:native])})#{lineEnd}"
   }
}
