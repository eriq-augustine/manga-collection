require 'csv'

TARGET_DIR = 'raw/scans'

boxId = ARGV[1].to_i()

data = []
Dir.glob("#{TARGET_DIR}/*-*.csv").sort().each{|path|
   boxId = path.sub(/^.+\/(\d{3})-\d{8}\.csv$/, '\1')

   data += CSV.read(path).collect{|row|
      isbn = row[0]
      formatGuess = row[2]
      scanTime = row[3]

      "   (#{boxId}, '#{isbn}', '#{formatGuess}', FROM_UNIXTIME(#{scanTime.to_i() / 1000}))"
   }
}

puts "INSERT INTO PhysicalScans"
puts "   (boxId, rawIdentifier, rawFormatGuess, scanTime)"
puts "VALUES"
puts data.join(",\n")
puts ";"
