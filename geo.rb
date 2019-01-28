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

def get_options
  return $options if defined?($options)

  $options = {}
  $options[:iso2] = ''
  $options[:near_coordinate] = nil
  $options[:near_file] = false
  $options[:distance] = nil

  OptionParser.new do |opts|
    opts.banner = "Usage: geo.rb COUNTRY_ISO2 [options]"

    opts.on("-f", "--near-file", "Find near coordinates from %COUNTRY_ISO2%.csv.") do |nf|
      $options[:near_file] = nf
    end

    opts.on("-c", "--near-coordinate COORD", "Find near coordinates that can be found near COORD. In 'lat,lng' format. Example: geo.rb US -c 45.2796196,-91.8236504.") do |coord|
      $options[:near_coordinate] = coord.split(',').map(&:to_f)
      abort('Wrong options passed for --near_coordinate. Example: geo.rb US -c 45.2796196,-91.8236504  ') if $options[:near_coordinate].count != 2
    end

    opts.on("-d", "--distance DISTANCE", "To be used in pair with --near-file or --near-coordinate. Specifies distance of lat/lng neighbourhood. Default value is 0.1.") do |distance|
      $options[:distance] = distance.to_f
    end
  end.parse!

  $options[:iso2] = ARGV.select{ |item| !item.start_with?('-') }.first
  $options[:help] = ARGV.select{ |item| item.include?('-h') }.present?

  p [__LINE__, {'$options' => $options}]

  if $options[:iso2].blank? && $options[:help].blank?
    abort 'COUNTRY_ISO2 parameter is required'
  end

  if ($options[:near_file] && $options[:near_coordinate])
    abort("--near-file and --near-coordinate can't be used at the same time")
  end

  if $options[:distance] && !$options[:near_file] && !$options[:near_coordinate]
    abort("--distance should be used in pair with --near-file or --near-coordinate.")
  end

  $options[:distance] = 0.1 if $options[:distance].blank?

  return $options
end

def load_csv
  p [__LINE__, 'Loading CSV file.']
  file = "rec/#{get_options[:iso2]}.csv"
  abort 'No CSV file, exiting.' if !File.file?(file)
  csv_arr = []
  CSV.foreach(file, headers: false) do |row|
    csv_arr << row
  end
  csv_arr
end

def get_country_borders(iso2)
  RGeo::Shapefile::Reader.open('TM_WORLD_BORDERS-0.3.shp') do |file|
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
    if get_options[:near_coordinate].present?
      rand_x = rand((get_options[:near_coordinate][1].to_f - get_options[:distance])..(get_options[:near_coordinate][1].to_f + get_options[:distance]))
      rand_y = rand((get_options[:near_coordinate][0].to_f - get_options[:distance])..(get_options[:near_coordinate][0].to_f + get_options[:distance]))
    elsif get_options[:near_file]
      csv_rand = load_csv.sample
      rand_x = rand((csv_rand[1].to_f - get_options[:distance])..(csv_rand[1].to_f + get_options[:distance]))
      rand_y = rand((csv_rand[0].to_f - get_options[:distance])..(csv_rand[0].to_f + get_options[:distance]))
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
# # It would be more logical to return true/false. Instead I return [lat, lng]/false to unify this function with test_google2.
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
  abort("Cannot find #{SHAPE_FILE}. Please download it from http://thematicmapping.org/downloads/world_borders.php and try again.")
end

p [__LINE__, "Finding country borders."]

country_borders = get_country_borders(get_options[:iso2])

stat_tries = 0
stat_succes_count  = 0
stat_succes_last_time = nil

while true
  stat_tries += 1
  random_coord = random_coord_within_county(country_borders)
  # google_coord = test_google(coord[0], coord[1])
  google_coord = test_google2(random_coord[0], random_coord[1])
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

    if geocode_country_code_upcase != get_options[:iso2]
      p [__LINE__, 'Reverse geocode returned different country code: ' + geocode_country_code_upcase.to_s]
    else
      p [__LINE__, 'Found coordinate!']

      stat_succes_last_time = Time.new
      stat_succes_count  += 1

      ext_near_coordinate = get_options[:near_coordinate].blank? ? '' : '.near-coordinate'
      ext_near_file = get_options[:near_file].blank? ? '' : '.near-file'

      File.open("rec/#{get_options[:iso2]}#{ext_near_coordinate}#{ext_near_file}.csv",'a') { |file|
        l = [
          google_coord[0],
          google_coord[1],
          get_options[:near_coordinate],
          DateTime.now.new_offset(0).to_s,
          geocode_country_code,
          geocoder_data["display_name"]]
        file.puts CSV.generate_line(l)
      }

      File.open("rec/#{get_options[:iso2]}#{ext_near_coordinate}#{ext_near_file}.json",'a') { |file|      
        tj = {
          lat: google_coord[0],
          lng: google_coord[1],
          near: get_options[:near_coordinate],
          geocode_country_code: geocode_country_code,
          geocode_display_name: geocoder_data["display_name"],
          created_at: DateTime.now.new_offset(0).to_s,
          geocode_json: geocode_json
        }
        file.puts tj.to_json
      }
      url = "https://maps.google.com/maps?q=&layer=c&cbll=#{google_coord[0]},#{google_coord[1]}"
      File.open("rec/#{get_options[:iso2]}#{ext_near_coordinate}#{ext_near_file}.htm",'a') {|file| file.puts "<p>#{geocoder_data["display_name"]}: <a href=\"#{url}\">#{url}</a></p>\r\n" }
    end
  end

  stat_succes_rate = (stat_succes_count.to_f / stat_tries.to_f * 100).to_i.to_s + '%'  
  p [__LINE__, ['get_options[:iso2]', 'get_options[:near_coordinate]', 'stat_tries', 'stat_succes_count', 'stat_succes_rate', 'stat_succes_last_time'].map{ |e| { e => eval(e) } }.inject(:merge)]

  sleep SLEEP_SECONDS
end
