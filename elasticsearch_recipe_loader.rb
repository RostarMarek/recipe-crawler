require 'HTTParty'
require 'Pry'
require 'csv'
require 'json'

class ElasticsearchRecipeLoader

  RECIPES_PATH = './recipes2.csv'
  ELASTICSEARCH_IP = 'http://127.0.0.1:9200'
  ELASTICSEARCH_INDEX = '/recipes-en/recipe/'

  def self.load_data
    put_index

    recipes = CSV.read(RECIPES_PATH,
                      headers: :first_row,
                      encoding: 'iso-8859-1:utf-8',
                      :row_sep => :auto,
                      :col_sep => ';'
    )

    parsed_recipes = parse_csv(recipes)

    parsed_recipes.each do |recipe|
      begin
        response = post_recipe(recipe)
      rescue StandardError=>e
        puts "\tError: #{e}"
      else
        puts "\t Success: #{response}"
      end
    end

  end

  private

  def self.parse_csv(recipes)
    parsed_recipes = []
    if recipes
      recipes.each do |row|
        recipe = {}
        recipe[:name] = row['recipe name']
        recipe[:ingredients] = row[' ingredients'].strip.gsub(/\"/, '').gsub(/, /,',').split(',')
        recipe[:preparation] = row[' preparation'].strip.gsub(/\"/, '').gsub(/\u008CÁ/,"\u2103")
        parsed_recipes << recipe
      end
    end
    parsed_recipes
  end

  def self.post_recipe(recipe_hash)
    puts "Posting recipe to #{ELASTICSEARCH_IP + ELASTICSEARCH_INDEX}"
    HTTParty.post(ELASTICSEARCH_IP + ELASTICSEARCH_INDEX,
                  :body => recipe_hash.to_json,
                  :headers => { 'Content-Type' => 'application/json' }
    )
  end

  def self.put_index
    puts "PUT index #{ELASTICSEARCH_IP}"
    HTTParty.put(ELASTICSEARCH_IP + '/recipes-en',
                  :body => { "mappings" => {
                                "ingredients" => {
                                    "properties" => {
                                        "ingredients" => {
                                            "type" => "string",
                                            "analyzer" => "english"
                                        }
                                    }
                                }
                            }

                  }.to_json,
                  :headers => { 'Content-Type' => 'application/json' }
    )
  end

end

ElasticsearchRecipeLoader.load_data
