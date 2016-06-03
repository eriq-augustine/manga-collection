require 'nokogiri'

require '../util/util.rb'

# TARGET_DIR = 'test'
TARGET_DIR = 'raw/publishers'

FAIL_DIR = 'fail'
EMPTY_DIR = 'empty'

`mkdir -p #{FAIL_DIR}`
`mkdir -p #{EMPTY_DIR}`

# DEBUG = true
DEBUG = false

def cleanData(data)
   cleanData = {}

   debug("Start Clean")

   cleanData['names'] = [{:primary => true, :val => getText(data['title'].css('b'))}]
   debug("Finished Clean: base title")

   cleanData['names'] += getText(data['altNames'].css('td')).split("\n").map{|title| {:primary => false, :val => title.strip()}}
   debug("Finished Clean: alt names")

   if (getText(data['type'].css('td')) != 'N/A')
      cleanData['type'] = getText(data['type'].css('td')).downcase()
   end
   debug("Finished Clean: type")

   notes = getText(data['notes'].css('td'))
   if (notes != 'N/A')
      cleanData['notes'] = notes
   end
   debug("Finished Clean: notes")

   website = data['website'].css('a')
   if (getText(data['website']) != 'N/A' && data['website'].css('a').size() > 0)
      cleanData['website'] = data['website'].css('a')[0].attr('href').strip()
   end
   debug("Finished Clean: website")

   cleanData['publications'] = data['publications'].map{|ele|
      {
         :id => ele.attr('href').strip().sub(/^.*\.html\?pubname=(.+)$/, '\1'),
         :name => getText(ele.css('u'))
      }
   }
   debug("Finished Clean: publications")

   debug("Finished Clean")

   return cleanData
end

def parseFile(path)
   debug(path)

   docString = IO.read(path)

   if (docString.include?('You specified an invalid publisher id.'))
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

   data = Hash.new()

   # Remove some empty nodes that throw off counting.
   doc.css('tr > td.text[height="12"]').each{|ele| ele.parent().remove()}

   data['title'] = doc.css('span.tabletitle')

   # 0 -- Alt Names and Type
   ele = doc.css('tr > td.text[bgcolor="#E4E7EB"]')[0].parent().parent()
   data['altNames'] = ele.element_children()[1]
   data['type'] = ele.element_children()[3]

   # 2 -- Notes, Website, and Last Updated
   ele = doc.css('tr > td.text[bgcolor="#E4E7EB"]')[2].parent().parent()
   data['notes'] = ele.element_children()[1]
   data['website'] = ele.element_children()[3]
   data['lastUpdate'] = ele.element_children()[5]

   # Publications and Series
   data['publications'] = doc.css('td.text[bgcolor=""] > a[href^="publishers.html"]')
   data['series'] = doc.css('td.text[bgcolor=""] > a[href^="series.html"]')

   debug("Finished Base Parse")

   return cleanData(data)
end

publications = {}
names = {}
publishers = {}

Dir.glob("#{TARGET_DIR}/publisher_*.html").sort().each{|path|
   begin
      id = path.sub(/^.+publisher_(\d+)\.html$/, '\1')
      data = parseFile(path)
      if (data == nil)
         next
      end

      publishers[id] = data

      if (data['names'] != nil && data['names'].size() > 0)
         names[id] = data['names'].uniq()
      end

      if (data['publications'] != nil && data['publications'].size() > 0)
         publications[id] = data['publications'].uniq()
      end
   rescue => ex
      debug("#{path} - Fail")
      $stderr.puts ex
      `cp '#{path}' #{FAIL_DIR}/`
   end
}

# Output

puts "
   INSERT INTO Publishers
      (id, type, notes, website)
   VALUES
"

publishers.sort().each_with_index{|(key, publisher), i|
   puts "      (#{key}, #{stringOrNull(publisher['type'])}, #{stringOrNull(publisher['notes'])}, #{stringOrNull(publisher['website'])})#{i == publishers.size() - 1 ? ';' : ','}"
}

puts "
   INSERT IGNORE INTO Publications
      (publisherId, idString, name)
   VALUES
"

publications.sort().each_with_index{|(key, pubNames), i|
   pubNames.each_with_index{|pubName, j|
      lineEnd = (i == publications.size() - 1 && j == pubNames.size() - 1) ? ';' : ','
      puts "      (#{key}, #{stringOrNull(pubName[:id])}, #{stringOrNull(pubName[:name])})#{lineEnd}"
   }
}
