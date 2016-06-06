require './crawl.rb'

SOURCE = 'webcat'
URL_BASE = 'http://webcatplus.nii.ac.jp/webcatplus/details/book/isbn/'

# http://webcatplus.nii.ac.jp/webcatplus/details/book/isbn/9784901926126.html
crawl(SOURCE, Proc.new{|isbn| "#{URL_BASE}#{isbn}.html"})
