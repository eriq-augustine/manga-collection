require './crawl.rb'

SOURCE = 'ndlopac'
URL_BASE = 'https://ndlopac.ndl.go.jp/F/?func=find-a&find_code=ISBN&request='
COOKIE_HEADER = 'Cookie: ALEPH_SESSION_ID=BMRHF2JTBUYRP7GY4HYJA4JVR66EF2TKM7CABTYK6KL4E49R6N; ndl.go.jp=rd2o00000000000000000000ffffac17a765o8991; TS019589f3=011338590a56872aa9e41051d79910d9fc923ce70459b965c0124fab89c17888acfeb24252faec96f4d2bfe160418def8cfaebfcfad97d14ede47e68cace74d15338ae2a53'

# https://ndlopac.ndl.go.jp/F/?func=find-a&find_code=ISBN&request=9784901926126
crawl(SOURCE, Proc.new{|isbn| "#{URL_BASE}#{isbn}"}, [COOKIE_HEADER])
