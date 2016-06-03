START_ID = 1

END_ID = 577
FETCH_DELAY_MS = 200
TARGET_DIR = 'publishers'
URL_BASE = 'https://www.mangaupdates.com/publishers.html?id='
FILE_FORMAT_STR = "publisher_%0#{END_ID.to_s().length()}d.html"

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
