methods_for :global do

  #Fetch the HTML snippet that is embedded in the call to the Javascript
  def fetch_html_snippet(doc)
    doc.each do |line|
      if line.match /^StoreBadgeHtml/
        return line
      end
    end
  end
  
  #A method to determine what timezone a user is in right now
  def find_user_timezone(uri)
    location = get_current_location(Nokogiri::HTML(fetch_html_snippet(open(uri))))
    return location
  end

  #Obtain the current location from Tripit
  def get_current_location(html_doc)
    html_doc.xpath('//div').each do |div_tag|
      if div_tag.inner_text.match /is in/
        location = div_tag.inner_text.split('is in')
        location = location[1].split('and has traveled')
        location = location[0].lstrip.split(',')
        location_uri = URI.escape "http://ws.geonames.org/postalCodeSearchJSON?placename=#{location[0]} #{location[1].lstrip}&maxRows=1"
        location = JSON.parse(RestClient.get(location_uri))
        timezone_uri = URI.escape "http://ws.geonames.org/timezoneJSON?lat=#{location['postalCodes'][0]['lat'].to_s}&lng=#{location['postalCodes'][0]['lng'].to_s}"
        timezone = JSON.parse(RestClient.get(timezone_uri))
        return timezone
      end
    end
  end

  #Convert the time into a Ruby DateTime object
  def convert_time(time, offset)
    datetime = time.split(' ')
    date = datetime[0].split('-')
    time = datetime[1].split(':')
    return DateTime.civil(date[0].to_i, date[1].to_i, date[2].to_i, time[0].to_i, time[1].to_i, 0, Rational(offset, 24))
  end

end

initialization do
  
  #Require the necessary libraries, this could also be in startup.rb
  require 'nokogiri'
  require 'open-uri'
  require 'json'
  require 'rest_client'
  require 'date'

end

methods_for :dialplan do
  
  #Method to get the time, with GMT offset, of the user configured in the tripit.yml configuration file
  def tripit_user_time?(username)
    begin
      timezone = find_user_timezone(COMPONENTS.tripit['users'][username]['uri'])
      return convert_time(timezone['time'], timezone['gmtOffset'])
    rescue => err
      ahn_log.tripit.warn err
      return nil
    end
  end
end