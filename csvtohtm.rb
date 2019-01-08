require 'rubygems'
require 'rgeo'
require 'rgeo/shapefile'

COUNTRY = 'US'

delta_file = "rec/#{COUNTRY}.csv"
CSV.foreach(delta_file, headers: false) do |row|
  # $delta_arr << row
  # data << row.to_hash
  uuu = "http://maps.google.com/maps?q=&layer=c&cbll=#{row[0]},#{row[1]}"
  File.open("rec/#{COUNTRY}.htm",'a') {|file| file.puts "<div><a href=\"#{uuu}\">#{uuu}</a></div>\r\n" }
end
