#START_ID = 1
START_ID = 83580

END_ID = 132967
FETCH_DELAY_MS = 200
TARGET_DIR = 'crawl'
URL_BASE = 'https://www.mangaupdates.com/series.html?id='
FILE_FORMAT_STR = "%0#{END_ID.to_s().length()}d.html"

lastFetch = 0

`mkdir -p #{TARGET_DIR}`

for i in START_ID..END_ID do
   if (Time.now().usec() - lastFetch < FETCH_DELAY_MS)
      sleep([0, (FETCH_DELAY_MS - (Time.now().usec() - lastFetch)).to_f() / FETCH_DELAY_MS].max())
   end

   puts i

   begin
      `wget -q -O '#{TARGET_DIR}/#{FILE_FORMAT_STR % i}' '#{URL_BASE + i.to_s()}'`
   rescue => ex
      puts "   Failed to get #{i} (#{ex})."
   end

   lastFetch = Time.now().usec()
end
