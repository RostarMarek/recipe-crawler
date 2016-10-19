require 'Nokogiri'
require 'HTTParty'
#require 'Pry'
require 'csv'

class RecipeScraper

  BASE_URI = 'http://www.cookbooks.com/Recipe-Details.aspx?id='

  def self.scrape_pages(range = 0..0)
    CSV.open('recipes2.csv', 'ab', {headers: true, col_sep: "; "}) do |csv|
      (range).each do |n|
        begin
          parsed_page = parse_page(n)
        rescue StandardError => e
          puts "\tError while parsing page: #{e}"
        else
          recipe = scrape_recipe(parsed_page)
          if recipe
            csv << ["#{recipe[:name]}",
                    "#{recipe[:ingredients].to_s.gsub(/([\[\]\\"])/,'')}",
                    "#{recipe[:preparation].to_s.gsub(/([\[\]\\"])/,'')}",
                    "#{recipe[:rating]}"
            ]
            puts "\t SUCCESS, data appended to recipes2.csv"
          else
            puts "\t PAGE NOT FOUND"
          end
        ensure
          sleep rand
        end
      end

    end
  end

  private

  def self.parse_page(id)
    url = BASE_URI + id.to_s
    puts "Fetching page #{id} #{url}"
    page = HTTParty.get(url)
    parsed_page = Nokogiri::HTML.parse(page)
  end

  def self.scrape_recipe(parsed_page)
    return unless parsed_page && parsed_page.css("td [valign][bgcolor]")[2].css("p.H1").count >= 2

    recipe = {}
    recipe[:name] = parsed_page.css("td [valign][bgcolor]")[2].css("p.H2").text.strip.gsub(/[;\"]/,'')
    recipe[:ingredients] = []
    parsed_page.css("td [valign][bgcolor]")[2].css("table p.H1").first.children.each do |child|
      recipe[:ingredients] << child.text.strip.gsub(',',' and').gsub(';','.') unless child.text.empty?
    end

    recipe[:preparation] = []
    preparation_perexes = parsed_page.css("td [valign][bgcolor]")[2].css("table p.H1")
    (1..preparation_perexes.count-1).each do |n|
      recipe[:preparation] << preparation_perexes[n].text.strip.gsub(';',' -').gsub(',',' and')
    end

    recipe[:rating] = rating(parsed_page)

    recipe
  end

  def self.rating(parsed_page)
    return unless parsed_page
    recipe_rating = parsed_page.css("div#star-rating strong").text
    (recipe_rating.empty?) ? 'none' : (recipe_rating.to_i) / 5.0
  end

end

if ARGV.count == 2 && ARGV[0].to_i > 0 && ARGV[1].to_i >= ARGV[0].to_i
  RecipeScraper.scrape_pages(ARGV[0].to_i..ARGV[1].to_i)
else
  puts "USAGE: \n"
  puts "\t - $ ruby recipe_scraper2.rb <range_from> <range_to>"
  puts "\t - <range_from> is an integer value higher than 0"
  puts "\t - <range_to> is an integer value equal or greater than <range_from> value"
end
