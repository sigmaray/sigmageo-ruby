require 'rubygems'
require 'optparse'
require 'active_support/core_ext/object/blank'
require 'rgeo'
require 'rgeo/shapefile'
require 'http'
require 'rmagick'
require 'rubygems'
require 'geocoder'

SHAPE_FILE = "TM_WORLD_BORDERS_SIMPL-0.3.shp"
SLEEP_SECONDS = 1
OUTPUT_DIR = 'coordinates'

def get_options
  $options = {}
  $options[:iso2] = ''
  $options[:near_coordinate] = nil
  $options[:near_file_coordinates] = false
  $options[:distance] = 0.1

  $options[:iso2] = ARGV.select{ |item| !item.start_with?('-') }.first
  $options[:help] = ARGV.select{ |item| item.include?('-h') }.present?

  if $options[:iso2].blank? && $options[:help].blank?
    ARGV.push('-h')
  end

  usage = "Usage: ruby sigmageo.rb COUNTRY_ISO2 [options]\n\n"
  usage += "Example: ruby sigmageo.rb FR\n\n"
  opt_parser = OptionParser.new do |opts|
    opts.banner = usage

    opts.on("-f", "--near-file", "Find near coordinates from %COUNTRY_ISO2%.csv.") do |nf|
      $options[:near_file_coordinates] = nf
    end

    opts.on("-c", "--near-coordinate LAT,LNG", "Find near coordinate (LAT,LNG). Example: geo.rb US -c 45.2796196,-91.8236504.") do |coord|
      $options[:near_coordinate] = coord.split(',').map(&:to_f)
      abort('Wrong options passed for --near_coordinate. Example: geo.rb US -c 45.2796196,-91.8236504  ') if $options[:near_coordinate].count != 2
    end

    opts.on("-d", "--distance DISTANCE", "To be used in pair with --near-file or --near-coordinate. Specifies distance of lat/lng neighbourhood. Default value is 0.1.") do |distance|
      $options[:distance] = distance.to_f
    end
  end

  opt_parser.parse!

  abort if $options[:iso2].blank?

  if ($options[:near_file_coordinates] && $options[:near_coordinate])
    abort("--near-file and --near-coordinate can't be used at the same time")
  end

  p [__LINE__, {'$options' => $options}]

  return $options
end

def load_csv_with_coordinates
  p [__LINE__, 'Loading CSV file.']
  file = "#{OUTPUT_DIR}/#{$options[:iso2]}.csv"
  abort 'No CSV file, exiting.' if !File.file?(file)
  csv_arr = []
  CSV.foreach(file, headers: false) do |row|
    csv_arr << row
  end
  csv_arr
end

def get_country_borders(iso2)
  RGeo::Shapefile::Reader.open(SHAPE_FILE) do |file|
    p [__LINE__, "File contains #{file.num_records} records."]
    file.each do |record|
      if record.attributes['ISO2'] == iso2
        return RGeo::Cartesian::BoundingBox.create_from_geometry(record.geometry)
      end
    end
  end
end

def random_coord_within_county(country_borders)
  while true
    if $options[:near_coordinate].present?
      rand_x = rand(($options[:near_coordinate][1].to_f - $options[:distance])..($options[:near_coordinate][1].to_f + $options[:distance]))
      rand_y = rand(($options[:near_coordinate][0].to_f - $options[:distance])..($options[:near_coordinate][0].to_f + $options[:distance]))
    elsif $options[:near_file_coordinates]
      csv_rand = load_csv_with_coordinates.sample
      rand_x = rand((csv_rand[1].to_f - $options[:distance])..(csv_rand[1].to_f + $options[:distance]))
      rand_y = rand((csv_rand[0].to_f - $options[:distance])..(csv_rand[0].to_f + $options[:distance]))
    else
      rand_x = rand(country_borders.min_x..country_borders.max_x)
      rand_y = rand(country_borders.min_y..country_borders.max_y)
    end
    point = RGeo::Cartesian.factory.point(rand_x, rand_y)
    if country_borders.contains?(point)
      break
    end
  end
  return [rand_y, rand_x]
end

# # There are limits when following this way. I don't know exact limits. But it seems google will allow only 2000 requests per day.
# # It would be more logical to return true/false. Instead I return [lat, lng]/false to unify this function with test_google_2.
# API_KEY = 'AIzaSyDpFdOYgaCQZCPNeiP0NhnXofDYmCJFaiY';
# def test_google(rand_y, rand_x)
#   lat_lng = "#{rand_y},#{rand_x}"
#   url = ("http://maps.googleapis.com/maps/api/streetview?sensor=false&" + "size=640x640&key=" + API_KEY) + "&location=" + lat_lng
#   p [__LINE__, {url: url}]
#   begin
#     source = Magick::Image.read(url).first
#     color =  source.to_color(source.pixel_color(1,1))
#     source.destroy!
#     return (color != '#E4E3DF' && color != '#E0E0E0') ? [rand_y, rand_x] : false
#   rescue Exception => err
#     p [__LINE__, {err: err}]
#     return false
#   end
# end

# There are no limits in this approach.
def test_google_2(lat, lng)
  url = "https://maps.googleapis.com/maps/api/js/GeoPhotoService.SingleImageSearch?pb=!1m5!1sapiv3!5sUS!11m2!1m1!1b0!2m4!1m2!3d#{lat}!4d#{lng}!2d100!3m18!2m2!1sen!2sUS!9m1!1e2!11m12!1m3!1e2!2b1!3e2!1m3!1e3!2b1!3e2!1m3!1e10!2b1!3e2!4m6!1e1!1e2!1e3!1e4!1e8!1e6&callback=_xdc_._2kz7bz"

  begin
    response = HTTP.get(url).to_s
    if response.include? "Search returned no images."
      p [__LINE__, 'Google returned no.', {lat: lat, lng: lng, combined: "#{lat},#{lng}", url: url}]
      return false
    else
      p [__LINE__, 'Google returned yes.', {lat: lat, lng: lng, combined: "#{lat},#{lng}"}]
      splitted_lat = lat.to_s.split('.')
      reg_expr = splitted_lat[0] + '\.' + splitted_lat [1][0..1] + '.+\]'
      reg_results = Regexp.new(reg_expr).match(response)[0]
      if !reg_results.blank?
        p [__LINE__, 'Found by regex.']
        ar = reg_results.chomp(']').split(',')
        return [ar[0].to_f, ar[1].to_f] # Returning first coordinate from google response.
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

if !File.file?(SHAPE_FILE)
  abort(
    "Cannot find #{SHAPE_FILE}. Please download it from http://thematicmapping.org/downloads/world_borders.php and try again.\n" + 
    "You can run `make download-borders`` to download and extract country borders"
  )
end

$options = get_options

p [__LINE__, "Finding country borders."]

country_borders = get_country_borders($options[:iso2])

stat_tries = 0
stat_succes_count  = 0
stat_succes_last_time = nil

while true
  stat_tries += 1
  random_coord = random_coord_within_county(country_borders)
  # google_coord = test_google(random_coord[0], random_coord[1])
  google_coord = test_google_2(random_coord[0], random_coord[1])
  if google_coord
    begin
      geocoder_data = Geocoder.search(google_coord).first.data
      geocode_json = geocoder_data.to_json
      geocode_country_code = geocoder_data['address']['country_code']
      geocode_address = geocoder_data['address']['geocode_address']
      geocode_country_code_upcase = geocoder_data['address']['country_code'].upcase
    rescue Exception => err
      p [__LINE__, 'Failed to do reverse geocoding.', {err: err}]
      next
    end

    if geocode_country_code_upcase != $options[:iso2]
      p [__LINE__, 'Reverse geocode returned different country code: ' + geocode_country_code_upcase.to_s]
    else
      p [__LINE__, 'Found coordinate!']

      stat_succes_last_time = Time.new
      stat_succes_count  += 1

      ext_near_coordinate = $options[:near_coordinate].blank? ? '' : '.near-coordinate'
      ext_near_file_coordinates = $options[:near_file_coordinates].blank? ? '' : '.near-file-coordinates'

      File.open("#{OUTPUT_DIR}/#{$options[:iso2]}#{ext_near_coordinate}#{ext_near_file_coordinates}.csv",'a') { |file|
        l = [
          google_coord[0],
          google_coord[1],
          $options[:near_coordinate],
          DateTime.now.new_offset(0).to_s,
          geocode_country_code,
          geocoder_data["display_name"]]
        file.puts CSV.generate_line(l)
      }

      File.open("#{OUTPUT_DIR}/#{$options[:iso2]}#{ext_near_coordinate}#{ext_near_file_coordinates}.json",'a') { |file|      
        tj = {
          lat: google_coord[0],
          lng: google_coord[1],
          near: $options[:near_coordinate],
          geocode_country_code: geocode_country_code,
          geocode_display_name: geocoder_data["display_name"],
          created_at: DateTime.now.new_offset(0).to_s,
          geocode_json: geocode_json
        }
        file.puts tj.to_json
      }
      url = "https://maps.google.com/maps?q=&layer=c&cbll=#{google_coord[0]},#{google_coord[1]}"
      File.open("#{OUTPUT_DIR}/#{$options[:iso2]}#{ext_near_coordinate}#{ext_near_file_coordinates}.htm",'a') {|file| file.puts "<p>#{geocoder_data["display_name"]}: <a href=\"#{url}\">#{url}</a></p>\r\n" }
    end
  end

  stat_succes_rate = (stat_succes_count.to_f / stat_tries.to_f * 100).to_i.to_s + '%'
  p [__LINE__, ['$options[:iso2]', '$options[:near_coordinate]', 'stat_tries', 'stat_succes_count', 'stat_succes_rate', 'stat_succes_last_time'].map{ |e| { e => eval(e) } }.inject(:merge)]

  sleep SLEEP_SECONDS
end
