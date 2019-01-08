require 'http'

lat = 32.806671
lng = -86.791130

def check2(lat, lng)
  url = "https://maps.googleapis.com/maps/api/js/GeoPhotoService.SingleImageSearch?pb=!1m5!1sapiv3!5sUS!11m2!1m1!1b0!2m4!1m2!3d#{lat}!4d#{lng}!2d100!3m18!2m2!1sen!2sUS!9m1!1e2!11m12!1m3!1e2!2b1!3e2!1m3!1e3!2b1!3e2!1m3!1e10!2b1!3e2!4m6!1e1!1e2!1e3!1e4!1e8!1e6&callback=_xdc_._2kz7bz"

  begin
    if HTTP.get(url).to_s.include? "Search returned no images"
      p ['no images', {lat: lat, lng: lng, combined: "#{lat},#{lng}"}].inspect
      return false
    else
      p ['found', {lat: lat, lng: lng, combined: "#{lat},#{lng}"}].inspect
      return true
    end    
  rescue Exception => err
    p [:L21, {err: err}].inspect
    return false
  end
end

p check2(lat, lng).inspect
