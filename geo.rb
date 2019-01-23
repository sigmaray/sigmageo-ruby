require 'optparse'
require 'active_support/core_ext/object/blank'

def parse_args
  options = {}
  options[:iso2] = ''
  options[:near_coordinate] = nil
  options[:near_file] = false
  options[:distance] = 0.1

  OptionParser.new do |opts|
    opts.banner = "Usage: geo.rb COUNTRY_ISO2 [options]"

    # opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    #   options[:verbose] = v
    # end

    opts.on("-f", "--near-file", "Find near coordinates that can be found in COUNTRY_ISO2.csv.") do |nf|
      options[:near_file] = nf
    end

    opts.on("-c", "--near-coordinate COORD", "Find near coordinates that can be found near COORD. In 'lat,lng' format. Example: geo.rb US -c 45.2796196,-91.8236504.") do |coord|
      options[:near_coordinate] = coord.split(',').map(&:to_f)
      abort('Wrong options passed for --near_coordinate. Example: geo.rb US -c 45.2796196,-91.8236504  ') if options[:near_coordinate].count != 2
    end

    opts.on("-d", "--distance DISTANCE", "To be used in pair with --near-file or --near-coordinate. Specifies distance of lat/lng neighbourhood. Default value is 0.1.") do |delta|
      options[:distance] = delta
    end
  end.parse!

  options[:iso2] = ARGV.select{ |item| !item.start_with?('-') }.first
  options[:help] = ARGV.select{ |item| item.include?('-h') }.present?

  p [__LINE__, options]

  if options[:iso2].blank? && options[:help].blank?
    abort 'COUNTRY_ISO2 is required'
    # abort("Where is my hat?!") 
  end

  
  if (options[:near_file] && options[:near_coordinate])
    abort("--near-file and --near-coordinate can't be used at the same time")
  end

  if options[:delta] && !options[:near_file] && !options[:near_coordinate]
    abort("--delta should be used in pair with --near-file or --near-coordinate.")
  end

  options
end

$args = parse_args

tries = 0
succesfull = 0
last_succesfull = nil

require 'rubygems'
require 'rgeo'
require 'rgeo/shapefile'
require 'http'
require 'rmagick'
require 'rubygems'
require 'geocoder'

def load_csv
  p [__LINE__, 'Loading CSV']
  delta_file = "rec/#{$args[:iso2]}.csv"
  abort 'no delta file, exiting' if !File.file?(delta_file)
  csv_arr = []
  CSV.foreach(delta_file, headers: false) do |row|
    csv_arr << row
  end
  csv_arr
end

p [__LINE__, "Loading borders"]

SHAPE_FILE = "TM_WORLD_BORDERS_SIMPL-0.3.shp"
if !File.file?(SHAPE_FILE)
  abort("Cannot find " + SHAPE_FILE + ". Please download it from " + "http://thematicmapping.org/downloads/world_borders.php " + "and try again.")
end

def get_borders(iso2)
  RGeo::Shapefile::Reader.open('TM_WORLD_BORDERS-0.3.shp') do |file|
    puts "File contains #{file.num_records} records."
    file.each do |record|
      if record.attributes['ISO2'] == iso2
        return  RGeo::Cartesian::BoundingBox.create_from_geometry(record.geometry)
      end
    end
  end
end

def random_coord_within_borders(borders)
  factory = RGeo::Cartesian.factory  
  rand_x = rand_y = nil

  while true
    if $args[:near_coordinate]
      rand_x = rand(($args[:near_coordinate][1].to_f - $args[:distance])..($args[:near_coordinate][1].to_f + $args[:distance]))
      rand_y = rand(($args[:near_coordinate][0].to_f - $args[:distance])..($args[:near_coordinate][0].to_f + $args[:distance]))
    elsif $args[:near_file]
      delta_rand = load_csv.sample
      rand_x = rand((delta_rand[1].to_f - $args[:distance])..(delta_rand[1].to_f + $args[:distance]))
      rand_y = rand((delta_rand[0].to_f - $args[:distance])..(delta_rand[0].to_f + $args[:distance]))
    else
      rand_x = rand(borders.min_x..borders.max_x)
      rand_y = rand(borders.min_y..borders.max_y)
    end
    point = factory.point(rand_x, rand_y)
    if borders.contains?(point)
      break
    end
  end
  return [rand_y, rand_x]
end

# # There are limits in this approach. I don'w exact limits. But it seems google will allow only 2000 requests per day
# API_KEY = 'AIzaSyDpFdOYgaCQZCPNeiP0NhnXofDYmCJFaiY';
# def test_google(rand_y, rand_x)
#   country_hits = 0
  
#   print("  In country")
#   country_hits += 1
#   lat_long = "#{rand_y},#{rand_x}"
#   url = ("http://maps.googleapis.com/maps/api/streetview?sensor=false&" + "size=640x640&key=" + API_KEY) + "&location=" + lat_long
#   p [__LINE__, {url: url}]

#   begin
#     source = Magick::Image.read(url).first
#     color =  source.to_color(source.pixel_color(1,1))
#     source.destroy!
#     return (color != '#E4E3DF' && color != '#E0E0E0') ? [lat, lng] : false
#   rescue Exception => err
#     p [__LINE__, {err: err}]
#     return false
#   end
# end

# There are no limits in this approach.
def test_google2(lat, lng)
  url = "https://maps.googleapis.com/maps/api/js/GeoPhotoService.SingleImageSearch?pb=!1m5!1sapiv3!5sUS!11m2!1m1!1b0!2m4!1m2!3d#{lat}!4d#{lng}!2d100!3m18!2m2!1sen!2sUS!9m1!1e2!11m12!1m3!1e2!2b1!3e2!1m3!1e3!2b1!3e2!1m3!1e10!2b1!3e2!4m6!1e1!1e2!1e3!1e4!1e8!1e6&callback=_xdc_._2kz7bz"

  begin
    response = HTTP.get(url).to_s
    if response.include? "Search returned no images."
      p [__LINE__, 'Google returned no.', {lat: lat, lng: lng, combined: "#{lat},#{lng}", url: url}]
      return false
    else
      p [__LINE__, 'Google returned yes.', {lat: lat, lng: lng, combined: "#{lat},#{lng}"}]
      ###############
      # Trying to find in response
      splitted = lat.to_s.split('.')
      reg_expr = splitted[0] + '\.' + splitted [1][0..1] + '.+\]'
      reg_results = Regexp.new(reg_expr).match(response)[0]
      if !reg_results.blank
        p [__LINE__, 'Found by regex.']
        ar = reg_results.chomp(']').split(',')
        return [ar[0].to_f, ar[1].to_f]
        # return true
      else
        p [__LINE__, 'Not found by regex.']
        return false
      end
    end
  rescue Exception => err
    p [__LINE__, {err: err}]
    return false
  end
end

p [__LINE__, "Finding country borders"]
borders = get_borders($args[:iso2])

while true
  tries += 1
  coord = random_coord_within_borders(borders)
  # r = test_google(coord[0], coord[1])
  r = test_google2(coord[0], coord[1])
  if r
    coord = r

    uuu = "http://maps.google.com/maps?q=&layer=c&cbll=#{coord[0]},#{coord[1]}"

    geocode_country_code = nil
    geocode_json = nil
    geocode_address = nil
    d = nil
    geocode_country_code_upcase = nil
    begin
      d = Geocoder.search(coord).first.data
      geocode_json = d.to_json
      geocode_country_code = d['address']['country_code']
      geocode_address = d['address']['geocode_address']
      geocode_country_code_upcase = d['address']['country_code'].upcase
    rescue Exception => err
      p [__LINE__, 'Failed to do reverse geocoding.', {err: err}]
      next
    end

    if geocode_country_code_upcase != $args[:iso2]
      p [__LINE__, 'Reverse geocode returned different country code: ' + geocode_country_code_upcase.to_s]
    else
      p [__LINE__, '!!! Found !!!']
      succesfull += 1
      last_succesfull = Time.new
      near_coordinate = $args[:near_coordinate].blank? ? '' : '.near-coordinate'
      near_file = $args[:near_file].blank? ? '' : '.near-file'
      File.open("rec/#{$args[:iso2]}#{near_coordinate}#{near_file}.csv",'a') { |file|
        l = [
          coord[0],
          coord[1],
          $args[:near_coordinate],
          DateTime.now.new_offset(0).to_s,
          geocode_country_code,
          d["display_name"]]
        file.puts CSV.generate_line(l)
      }
      File.open("rec/#{$args[:iso2]}#{near_coordinate}#{near_file}.json",'a') { |file|      
        tj = {
          lat: coord[0],
          lng: coord[1],
          near: $args[:near_coordinate],
          geocode_country_code: geocode_country_code,
          geocode_display_name: d["display_name"],
          created_at: DateTime.now.new_offset(0).to_s,
          geocode_json: geocode_json
        }
        file.puts tj.to_json
      }
      File.open("rec/#{$args[:iso2]}#{near_coordinate}#{near_file}.htm",'a') {|file| file.puts "<p>#{d["display_name"]}: <a href=\"#{uuu}\">#{uuu}</a></p>\r\n" }
    end
  end
  succes_rate = (succesfull.to_f / tries.to_f * 100).to_i.to_s + '%'
  p [__LINE__, ['$args[:iso2]', '$args[:near_coordinate]', 'tries', 'succesfull', 'succes_rate', 'last_succesfull'].map{ |e| { e => eval(e) } }.inject(:merge)]
  sleep 1
end
