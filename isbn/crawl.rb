require 'mysql'

# Delay in micro seconds
FETCH_DELAY_US = 3000 * 1000
RAW_ROOT = 'raw'

def fetchISBNs()
   db = Mysql::new("localhost", "", "", "manga", 3306, '/media/media/mysql/mysql.sock')

   rows = db.query("
      SELECT DISTINCT rawIdentifier
      FROM PhysicalScans
      WHERE
         volume IS NULL
         AND rawFormatGuess = 'EAN_13'
      ORDER BY rawIdentifier DESC
   ")

   isbns = []
   rows.each{|row|
      isbns << row[0]
   }
   rows.free()
   db.close()

   return isbns
end

def crawl(source, urlFormatter, headers)
   lastFetch = 0
   `mkdir -p #{RAW_ROOT}/#{source}`

   headersString = ''
   if (headers != nil && headers.size() > 0)
      headersString = headers.map{|header| "--header '#{header}'"}.join(' ')
   end

   isbns = fetchISBNs()

   isbns.each{|isbn|
      if (Time.now().usec() - lastFetch < FETCH_DELAY_US)
         percentOfDelay = (FETCH_DELAY_US - (Time.now().usec() - lastFetch)).to_f() / FETCH_DELAY_US
         delaySeconds = (percentOfDelay * FETCH_DELAY_US).to_f() / 1000000.0
         sleep([0, delaySeconds].max())
      end

      puts isbn

      url = urlFormatter.call(isbn)
      begin
         `wget -q -O '#{RAW_ROOT}/#{source}/#{source}_#{isbn}.html' #{headersString} '#{url}'`
      rescue => ex
         puts "   Failed to get #{isbn} (#{ex})."
      end

      lastFetch = Time.now().usec()
   }
end
