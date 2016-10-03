require 'Nokogiri'
require 'HTTParty'
require 'Pry'
require 'csv'

class RecipeScraper

  BASE_URI = 'http://allrecipes.com/recipe/'

  def self.scrape_pages(range = 0..0)
    (range).each do |n|
      CSV.open('recipes.csv', 'ab', {headers: true, col_sep: "; "}) do |csv|
        begin
          parsed_page = parse_page(n)
        rescue Exception => e
          puts "\tError: #{e}"
        else
          recipe = scrape_recipe(parsed_page)
          if recipe
            csv << ["#{recipe[:name]}",
                    "#{recipe[:ingredients].to_s.gsub(/([\[\]\\"])/,'')}",
                    "#{recipe[:servings]}",
                    "#{recipe[:calories]}",
                    "#{recipe[:rating]}",
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:preparation]}" : 0.to_s,
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:cook]}" : 0.to_s,
                    (recipe[:cook_time]) ? "#{recipe[:cook_time][:total]}" : 0.to_s,
                    "#{recipe[:directions].to_s.gsub(/([\[\]\\",])/,'')}"
                    ]
            puts "\t SUCCESS, data appended to app_ids.csv"
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
    recipe[:name] = parsed_page.css('.submitter__description').text.strip.gsub(/\"/, '')
    recipe[:ingredients] = []
    (0..1).each do |i|
      parsed_page.css('.recipe-ingredients > ul')[i].css('li span.recipe-ingred_txt').each do |li|
        recipe[:ingredients] << li.text if li.text != "Add all ingredients to list"
      end
    end

    unless parsed_page.css('ul.prepTime li').empty?
      recipe[:cook_time] = { :preparation => count_time(parsed_page.css('ul.prepTime li')[1].css('span.prepTime__item--time')),
                             :cook => count_time(parsed_page.css('ul.prepTime li')[2].css('span.prepTime__item--time')),
                             :total => count_time(parsed_page.css('ul.prepTime li')[3].css('span.prepTime__item--time'))
      }
    end

    recipe[:directions] = []
    parsed_page.css('.recipe-directions__list').first.css('li').each do |li|
      recipe[:directions] << li.text.strip
    end

    recipe[:servings] = parsed_page.css('#metaRecipeServings').first.attributes['content'].value
    recipe[:calories] = parsed_page.css('.calorie-count span').first.children.first.text
    recipe[:rating] = parsed_page.css('div.rating-stars').first.attributes["data-ratingstars"].value

    recipe
  end

  def self.count_time(spans)
    return unless spans
    time = 0
    spans.each_with_index do |span, i|
      (i % 2 == 0) ? time += span.text.to_i * 60 : time += span.text.to_i
    end
    time
  end

end


#Pry.start(binding)
RecipeScraper.scrape_pages(6663..6700)
