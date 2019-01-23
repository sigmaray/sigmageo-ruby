$p_delta_mode = false
# $p_delta_mode = true
# $p_delta_mode = true
# $p_delta_mode = false

def parse_args
  args = {}
  args[:sel] = nil
  args[:country] = ''
  args[:delta_seq] = 0.1

  # command = ARGV[0]  
  abort('Yoush should provide country code (examples: US, RU, FR)') if ARGV.count == 0
  not_keys = ARGV.select{ |item| item[0] != '-' }
  # keys = ARGV.select{ |item| item[0] == '-' }.map{ |item| item.gsub('-', '') }
  keys = ARGV.select{ |item| item[0] == '-' }
  args[:country] = not_keys[0]
  if not_keys.count > 1
    args[:delta_mode] = true
    args[:delta_seq] = not_keys[1].to_f
  end

  p_sel = keys.select{ |item| item[0..3] == '-sel' }[0]
  if !p_sel.nil?
    p_sel = p_sel.gsub('-sel', '')
    p_sel = p_sel.split(',').map(&:to_f)
    args[:sel] = p_sel
  end
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
  # reload_delta if parse_args[:delta_mode]
  while true
    if !parse_args[:sel].nil?
      rand_x = rand((parse_args[:sel][1].to_f - parse_args[:delta_seq])..(parse_args[:sel][1].to_f + parse_args[:delta_seq]))
      rand_y = rand((parse_args[:sel][0].to_f - parse_args[:delta_seq])..(parse_args[:sel][0].to_f + parse_args[:delta_seq]))
    elsif !parse_args[:delta_mode]
      rand_x = rand(borders.min_x..borders.max_x)
      rand_y = rand(borders.min_y..borders.max_y)
    else
      delta_rand = reload_delta.sample
      rand_x = rand((delta_rand[1].to_f - parse_args[:delta_seq])..(delta_rand[1].to_f + parse_args[:delta_seq]))
      rand_y = rand((delta_rand[0].to_f - parse_args[:delta_seq])..(delta_rand[0].to_f + parse_args[:delta_seq]))
    end

    # US? (don't remember)
    # rand_y = 45.2796196
    # rand_x = -91.8236504  

    point1 = factory.point(rand_x, rand_y)
    cont = borders.contains?(point1)

    if cont
      reload_delta if $p_delta_mode
      break
    end
  end
  return [rand_y, rand_x]
end

# API_KEY = 'AIzaSyDpFdOYgaCQZCPNeiP0NhnXofDYmCJFaiY';
# GOOGLE_URL = ("http://maps.googleapis.com/maps/api/streetview?sensor=false&" + "size=640x640&key=" + API_KEY)

# def test_google(rand_y, rand_x)
#   country_hits = 0
  
#   print("  In country")
#   country_hits += 1
#   lat_lon = "#{rand_y},#{rand_x}"
#   url = GOOGLE_URL + "&location=" + lat_lon
#   p [__LINE__, {url: url}].inspect  

#   begin
#     source = Magick::Image.read(url).first
#     color =  source.to_color(source.pixel_color(1,1))
#     source.destroy!
#     return (color != '#E4E3DF' && color != '#E0E0E0')
#   rescue Exception => err
#     p [__LINE__, {err: err}].inspect
#     return false
#   end
# end

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
  # if test_google(coord[0], coord[1])
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
      succesfull += 1
      last_succesfull = Time.new
      p '!!! found !!!'
      sese = parse_args[:sel].nil? ? '' : '.s'
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
          near: parse_args[:sel],
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
  p [__LINE__, ['parse_args[:country]', 'parse_args[:sel]', 'tries', 'succesfull', 'succes_rate', 'last_succesfull'].map{ |e| { e => eval(e) } }.inject(:merge)]
  sleep 1
end
