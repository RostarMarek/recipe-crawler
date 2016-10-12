require 'Nokogiri'
require 'HTTParty'
#require 'Pry'
require 'csv'

class RecipeScraper

  BASE_URI = 'http://allrecipes.com/recipe/'

  def self.scrape_pages(range = 0..0)
    CSV.open('recipes.csv', 'ab', {headers: true, col_sep: "; "}) do |csv|
      (range).each do |n|
        begin
          parsed_page = parse_page(n)
        rescue Exception => e
          puts "\tError: #{e}"
        else
          recipe = scrape_recipe(parsed_page)
          if recipe
            csv << ["#{recipe[:name]}",
                    "#{recipe[:description]}",
                    "#{recipe[:ingredients].to_s.gsub(/([\[\]\\"])/,'')}",
                    "#{recipe[:servings]}",
                    "#{recipe[:calories]}",
                    "#{recipe[:rating]}",
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:preparation]}" : 0.to_s,
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:cook]}" : 0.to_s,
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:total]}" : 0.to_s,
                    "#{recipe[:directions].to_s.gsub(/([\[\]\\",])/,'')}"
                    ]
            puts "\t SUCCESS, data appended to recipes.csv"
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
    return unless parsed_page && parsed_page.css('.error-page .error-page__404').empty?

    recipe = {}
    recipe[:name] = parsed_page.css('.recipe-summary__h1').text.strip.gsub(/\"/, '')
    recipe[:description] = parsed_page.css('.submitter__description').text.strip.gsub(/\"/, '')
    recipe[:ingredients] = []
    (0..1).each do |i|
      parsed_page.css('.recipe-ingredients > ul')[i].css('li span.recipe-ingred_txt').each do |li|
        recipe[:ingredients] << li.text if li.text != "Add all ingredients to list"
      end
    end

    unless parsed_page.css('ul.prepTime li').empty?
      recipe[:cook_time] = { :preparation => count_time(parsed_page, 1),
                             :cook => count_time(parsed_page, 2),
                             :total => count_time(parsed_page, 3)
      }
    end

    recipe[:directions] = []
    parsed_page.css('.recipe-directions__list').first.css('li').each do |li|
      recipe[:directions] << li.text.strip.gsub(';','.')
    end

    recipe[:servings] = servings(parsed_page)
    recipe[:calories] = calories(parsed_page)
    recipe[:rating] = rating(parsed_page)

    recipe
  end

  private

  def self.count_time(parsed_page, type)
    return unless parsed_page && type && type.is_a?(Integer)
    prep_time_items = parsed_page.css('ul.prepTime li')
    li = prep_time_items[type]
    spans = li.css('span.prepTime__item--time') if li
    time = count_minutes(spans)
  end

  def self.count_minutes(spans)
    result = case spans.count
    when 1
      spans[0].text.to_i
    when 2
      (spans[0].text.to_i * 60) + spans[1].text.to_i
    when 3
      (spans[0].text.to_i * 24 * 60) + (spans[1].text.to_i * 60) + spans[2].text.to_i
    else
      0
    end
    result
  end

  def self.calories(parsed_page)
    return unless parsed_page
    calories_span = parsed_page.css('.calorie-count span')
    first_span = calories_span.first if calories_span
    calories_span ? first_span.text : nil.to_s
  end

  def self.servings(parsed_page)
    return unless parsed_page
    servings_span = parsed_page.css('#metaRecipeServings')
    first_span = servings_span.first if servings_span
    content_attribute = first_span.attributes['content']
    content_attribute ? content_attribute.value : nil.to_s
  end

  def self.rating(parsed_page)
    return unless parsed_page
    rating_span = parsed_page.css('div.rating-stars')
    first_span = rating_span.first if rating_span
    data_ratingstars_attribute = first_span.attributes['data-ratingstars']
    data_ratingstars_attribute ? data_ratingstars_attribute.value : nil.to_s
  end

end

if ARGV.count == 2 && ARGV[0].to_i > 0 && ARGV[1].to_i >= ARGV[0].to_i
  RecipeScraper.scrape_pages(ARGV[0].to_i..ARGV[1].to_i)
else
  puts "USAGE: \n"
  puts "\t - $ ruby recipe_scraper.rb <range_from> <range_to>"
  puts "\t - <range_from> is an integer value higher than 0"
  puts "\t - <range_to> is an integer value equal or greater than <range_from> value"
end
