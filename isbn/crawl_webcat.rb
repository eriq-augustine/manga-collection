require 'mysql'

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

# Delay in micro seconds
FETCH_DELAY_US = 3000 * 1000
TARGET_DIR = 'raw/webcat'
URL_BASE = 'http://webcatplus.nii.ac.jp/webcatplus/details/book/isbn/'
FILE_FORMAT_STR = "webcat_%d.html"

def formatUrl(isbn)
   # http://webcatplus.nii.ac.jp/webcatplus/details/book/isbn/9784901926126.html
   return "#{URL_BASE}#{isbn}.html"
end

lastFetch = 0

`mkdir -p #{TARGET_DIR}`

isbns.each{|isbn|
   if (Time.now().usec() - lastFetch < FETCH_DELAY_US)
      percentOfDelay = (FETCH_DELAY_US - (Time.now().usec() - lastFetch)).to_f() / FETCH_DELAY_US
      delaySeconds = (percentOfDelay * FETCH_DELAY_US).to_f() / 1000000.0
      sleep([0, delaySeconds].max())
   end

   puts isbn

   begin
      `wget -q -O '#{TARGET_DIR}/webcat_#{isbn}.html' '#{formatUrl(isbn)}'`
   rescue => ex
      puts "   Failed to get #{isbn} (#{ex})."
   end

   lastFetch = Time.now().usec()
}
