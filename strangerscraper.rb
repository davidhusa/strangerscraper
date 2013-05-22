require 'yaml'
require 'rubygems'
require 'mechanize'
require 'geocoder'

class StrangerScraper

  def run
    @agent = Mechanize.new
    @looper = String.new
    @number = 1
    #while @looper != "q"
    while @number < 7
      @page = @agent.get("http://www.thestranger.com/gyrobase/LocationSearch?feature=Featured%20Happy%20Hour&page=#{@number}")

      @all_data = get_the_data(@page)
      
      puts "___locations___"
      puts @all_data["locations"].to_yaml
      puts "___happy hours___"
      puts @all_data["happy_hours"].to_yaml
      puts "___bargains___"
      puts @all_data["bargains"].to_yaml

      File.open("output/location.yml", "a") do |aFile|
        aFile.syswrite(@all_data["locations"].to_yaml)
      end
      File.open("output/happy_hour.yml", "a") do |aFile|
        aFile.syswrite(@all_data["happy_hours"].to_yaml)
      end
      File.open("output/bargain.yml", "a") do |aFile|
        aFile.syswrite(@all_data["bargains"].to_yaml)
      end

      puts "_Type 'q' to quit_"
      @number+=1
      @looper = "y"
    end

  end

  def get_the_data(page)
    locations = Hash.new
    happy_hours = Hash.new
    bargains = Hash.new

    # page_links=page.parser.css("h4 a")
    # page_links.delete("All Categories")
    # page_links.delete("All Neighborhoods")

    page.parser.css("h4 a").each do |link|
      #puts link.text
      location_name = link.text
      next if location_name == "All Categories" or location_name == "All Neighborhoods"

      @agent.click(location_name)
      print '.'
      
      happy_hour_text = /<strong>Happy Hour:<\/strong>(.*)\s*<\/li>/.match(@agent.page.search("li.cats_features").to_s)

      if happy_hour_text
        happy_hour_text = happy_hour_text[1].strip
        deal_info = /^(.*)\((.*)\)/.match(happy_hour_text)
      else
        happy_hour_text= "n/a"
        deal_info = ["n/a", "n/a", "n/a"]
      end

      #puts @agent.page.search("h1 + p").to_s
      # grab address only works in Seattle addresses
      /\n(.*)<br>\n(.*)\n/.match(@agent.page.search("h1 + p").to_s)
      address_line_1 = $1 || "missing"
      address_line_2 = $2 || "missing"
      address_line_1.strip!
      address_line_2.strip!
      address_raw = address_line_1 + ", " + address_line_2
      address_array = Geocoder.search(address_raw)
      unless address_array.empty?
        address_final = address_array[0].address
        longitude = address_array[0].longitude
        latitude = address_array[0].latitude
      else
        address_final, longitude, latitude = "missing"
      end

      @agent.back

      locations[location_name] = {
        "name" => location_name, "address" => address_final,
        "longitude" => longitude, "latitude" => latitude, "version" => 1, "record_number" => nil
      }
      happy_hours[location_name + "_hh"] = {
        "name" => "Happy Hour", "days" => deal_info[1], "start_time" => deal_info[1], "end_time" => deal_info[1], "version" => 1,
        "location" => location_name, "record_number" => nil
      }
      bargains[location_name + "_b"] = {
        "deal" => deal_info[2], "version" => 1, "deal_type" => "beer", "discount_or_price" => 0,
        "happy_hour" => location_name + "_hh", "record_number" => nil
      }
    end
    {"locations" => locations, "happy_hours" => happy_hours, "bargains" => bargains} 
  end
end

StrangerScraper.new.run