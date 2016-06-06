require 'mysql'

require_relative './html_escape.rb'

def debug(str)
   if (DEBUG)
      puts str
   end
end

JPN_CHN_PATTERN = '[\p{Han}\p{Hiragana}\p{Katakana}]'

# Nokogiri can be pretty fussy and text() is not always sufficient to get all the correct text from a node.
# What is done in here is not fully html compliant, but should usually yield better results than what Nokogiri gives.
# This assumes that |node| is a text node and only contains text and maybe <br>s.
def getText(node)
   # Specially replace <br>s.
   text = node.inner_html().gsub(/(<\s*br\s*\/?>\s*)+/i, "\n")

   # Sub out emojis.
   text = text.gsub(/\<!--emo\[(.+)\]--\>\<img src="([^"]+)" alt="([^"]+)"\>\<!--emo_end--\>/, '\1')

   # Some unicide characters got encoded as hex unicode html escape sequences.
   text = text.gsub(/&#x[0-9A-Fa-f]{4};/){|match| [match.sub(/&#x([0-9A-Fa-f]{4});/, '\1').hex()].pack("U")}

   # Replace extended HTML escape sequences.
   text = text.gsub(/&[0-9a-zA-Z#]{2,6};/, HTML_REPLACEMENTS).strip()

   text.gsub("\t", ' ').gsub(/ {2,}/, ' ')

   # Japanese/Chinese characters should not have spaces between them.
   text = text.gsub(/(#{JPN_CHN_PATTERN}) (#{JPN_CHN_PATTERN})/i, '\1\2')

   return text
end

LANG_REPLACEMENT = {
   # Countries
   '日本' => 'JPN',
   'ja' => 'JPN',
   'アメリカ合衆国' => 'USA',
   'アメリカ' => 'USA',
   'フランス' => 'FRA',
   # Languages
   'jpn' => 'JPN',
   '日本語' => 'JPN',
   '英語' => 'ENG',
   'フランス語' => 'FRA',
}

def langCountryReplacement(text)
   LANG_REPLACEMENT.each{|key, val| text.gsub!(/\b#{key}\b/i, val)}
   return text
end

def intOrNull(val)
   if (val == nil)
      return "NULL"
   end

   return "#{val}"
end

def stringOrNull(val)
   if (val == nil)
      return "NULL"
   end

   return "'#{Mysql.escape_string(val)}'"
end

def boolOrNull(val)
   if (val == nil)
      return "NULL"
   end

   return val ? 'TRUE' : 'FALSE'
end
