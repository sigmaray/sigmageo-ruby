def parse_args
  args = {}
  args[:country] = ''
  args[:near_coordinate] = nil
  args[:near_file] = false
  args[:delta] = 0.1

  # command = ARGV[0]  
  abort('You should provide country code (examples: US, RU, FR)') if ARGV.count == 0
  not_keys = ARGV.select{ |item| item[0] != '-' }
  # keys = ARGV.select{ |item| item[0] == '-' }.map{ |item| item.gsub('-', '') }
  keys = ARGV.select{ |item| item[0] == '-' }
  args[:country] = not_keys[0]
  if not_keys.count > 1
    args[:near_file] = true
    args[:delta] = not_keys[1].to_f
  end

  p_delta = keys.select{ |item| item[0..4] == '-delta' }[0]
  if !p_delta.nil?
    p_delta = p_delta.gsub('-delta', '')
    args[:delta] = p_delta.to_f
  end  

  args[:near_file] = !((keys.select{ |item| item.start_with?('-near_file' }[0]).nil?)

  p_near_coordinate = keys.select{ |item| item.start_with?('-near_coordinate') }[0]
  if !p_near_coordinate.nil?
    p_near_coordinate = p_near_coordinate.gsub('-near_coordinate', '')
    p_near_coordinate = p_near_coordinate.split(',').map(&:to_f)
    args[:near_coordinate] = p_near_coordinate
  end

  if args[:near_coordinate] && args[:near_file]
    abort '-near_coordinate and -near_file cannot be provided at the same time'
  end

  # raise args.inspect

  args
end

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

def reload_delta
  p 'Loading delta'
  delta_file = "rec/#{parse_args[:country]}.csv"
  abort 'no delta file, exiting' if !File.file?(delta_file)
  delta_arr = []
  CSV.foreach(delta_file, headers: false) do |row|
    delta_arr << row
    # data << row.to_hash
  end
  delta_arr
end

p("Loading borders")
# SHAPE_FILE = "TM_WORLD_BORDERS-0.3.shp"
SHAPE_FILE = "TM_WORLD_BORDERS_SIMPL-0.3.shp"
if !File.file?(SHAPE_FILE)
    p("Cannot find " + SHAPE_FILE + ". Please download it from " +
          "http://thematicmapping.org/downloads/world_borders.php " +
          "and try again.")
    # sys.exit()
    exit
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
  # reload_delta if parse_args[:near_file]
  while true
    if !parse_args[:near_coordinate].nil?
      rand_x = rand((parse_args[:near_coordinate][1].to_f - parse_args[:delta])..(parse_args[:near_coordinate][1].to_f + parse_args[:delta]))
      rand_y = rand((parse_args[:near_coordinate][0].to_f - parse_args[:delta])..(parse_args[:near_coordinate][0].to_f + parse_args[:delta]))
    elsif !parse_args[:near_file]
      rand_x = rand(borders.min_x..borders.max_x)
      rand_y = rand(borders.min_y..borders.max_y)
    else
      delta_rand = reload_delta.sample
      rand_x = rand((delta_rand[1].to_f - parse_args[:delta])..(delta_rand[1].to_f + parse_args[:delta]))
      rand_y = rand((delta_rand[0].to_f - parse_args[:delta])..(delta_rand[0].to_f + parse_args[:delta]))
    end

    # US? (don't remember)
    # rand_y = 45.2796196
    # rand_x = -91.8236504  

    point1 = factory.point(rand_x, rand_y)
    cont = borders.contains?(point1)

    if cont
      break
    end
  end
  return [rand_y, rand_x]
end

# API_KEY = 'AIzaSyDpFdOYgaCQZCPNeiP0NhnXofDYmCJFaiY';
# GOOGLE_URL = ("http://maps.googleapis.com/maps/api/streetview?sensor=false&" + "size=640x640&key=" + API_KEY)

def test_google(rand_y, rand_x)
  country_hits = 0
  
  print("  In country")
  country_hits += 1
  lat_lon = "#{rand_y},#{rand_x}"
  url = GOOGLE_URL + "&location=" + lat_lon
  p [__LINE__, {url: url}].inspect  

  begin
    source = Magick::Image.read(url).first
    color =  source.to_color(source.pixel_color(1,1))
    source.destroy!
    return (color != '#E4E3DF' && color != '#E0E0E0') ? [lat, lng] : false
  rescue Exception => err
    p [__LINE__, {err: err}].inspect
    return false
  end
end

def check2(lat, lng)
  url = "https://maps.googleapis.com/maps/api/js/GeoPhotoService.SingleImageSearch?pb=!1m5!1sapiv3!5sUS!11m2!1m1!1b0!2m4!1m2!3d#{lat}!4d#{lng}!2d100!3m18!2m2!1sen!2sUS!9m1!1e2!11m12!1m3!1e2!2b1!3e2!1m3!1e3!2b1!3e2!1m3!1e10!2b1!3e2!4m6!1e1!1e2!1e3!1e4!1e8!1e6&callback=_xdc_._2kz7bz"

  begin
    res = HTTP.get(url).to_s
    if res.include? "Search returned no images"
      p [__LINE__, 'no images', {lat: lat, lng: lng, combined: "#{lat},#{lng}", url: url}].inspect
      return false
    else
      # abort('@@url: ' + url)
      p [__LINE__, 'found', {lat: lat, lng: lng, combined: "#{lat},#{lng}"}].inspect
      ###############
      # Trying to find in res
      splitted = lat.to_s.split('.')
      regexpr = splitted[0] + '\.' + splitted [1][0..1] + '.+\]'
      regres = Regexp.new(regexpr).match(res)[0]
      if !regres.nil?
        p 'found by regex'
        ar = regres.chomp(']').split(',')
        return [ar[0].to_f, ar[1].to_f]
        # return true
      else
        p 'not by regex'
        return false
      end
    end    
  rescue Exception => err
    p [__LINE__, {err: err}].inspect
    return false
  end
end

p "Finding country"
borders = get_borders(parse_args[:country])

while true
  tries += 1
  coord = random_coord_within_borders(borders)
  # r = test_google(coord[0], coord[1])
  r = check2(coord[0], coord[1])
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
      p [__LINE__, 'Failed to do reverse geocoding.', {err: err}].inspect
      # return false
    end

    if geocode_country_code_upcase != parse_args[:country]
      p [__LINE__, 'reverse geocode returned different country code: ' + geocode_country_code_upcase.to_s].inspect
    else
      p [__LINE__, '!!! found !!!']
      succesfull += 1
      last_succesfull = Time.new
      sese = parse_args[:near_coordinate].nil? ? '' : '.s'
      File.open("rec/#{parse_args[:country]}#{sese}.csv",'a') { |file|
        l = [
          coord[0],
          coord[1],
          DateTime.now.new_offset(0).to_s,
          geocode_country_code,
          d["display_name"]]
        file.puts CSV.generate_line(l)
      }
      File.open("rec/#{parse_args[:country]}#{sese}.json",'a') { |file|      
        tj = {
          lat: coord[0],
          lng: coord[1],
          near: parse_args[:near_coordinate],
          geocode_country_code: geocode_country_code,
          geocode_display_name: d["display_name"],
          created_at: DateTime.now.new_offset(0).to_s,
          geocode_json: geocode_json
        }
        file.puts tj.to_json
      }
      File.open("rec/#{parse_args[:country]}#{sese}.htm",'a') {|file| file.puts "<p>#{d["display_name"]}: <a href=\"#{uuu}\">#{uuu}</a></p>\r\n" }
    end
  end
  succes_rate = (succesfull.to_f / tries.to_f * 100).to_i.to_s + '%'
  p [__LINE__, ['parse_args[:country]', 'parse_args[:near_coordinate]', 'tries', 'succesfull', 'succes_rate', 'last_succesfull'].map{ |e| { e => eval(e) } }.inject(:merge)]
  sleep 1
end
