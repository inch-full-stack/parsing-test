require 'nokogiri'
require 'curb'
require 'csv'

# Запуск скрипта: ruby parser.rb

class Parsing
    attr_reader :urls, :table

    def initialize(name_file, url)
        @urls = []
        @table = [['Name', 'Price', 'Image']]
        @name_file = name_file
        @url = url
    end

    def nokogiri_parsed_page(url)
        http = Curl.get(url)
        Nokogiri::HTML(http.body_str)
    end

    def add_urls(page_urls, all_urls)
        page_urls.each do |url_product|
            all_urls.push(url_product)
        end
    end

    def parsing_quantity_pages
        html = nokogiri_parsed_page(@url)
        product_img_link = html.xpath('//a[contains(@class, "product_img_link")]//@href')
        pages = html.xpath('//div[contains(@id, "pagination_bottom")]//@href')
        quantity_pages_match = "#{pages[-2]}".match(/[0-9]+/)
        quantity_pages = "#{quantity_pages_match}".to_i
        add_urls(product_img_link, @urls)

        if quantity_pages > 1
            for i in 2..quantity_pages do
                html = nokogiri_parsed_page("#{@url}?p=#{i}")
                product_img_link = html.xpath('//a[contains(@class, "product_img_link")]//@href')
                add_urls(product_img_link, @urls)
            end
        end

    end

    def parsing_goods(array, page)
        prices = []
        sizes = []
        html = Nokogiri::HTML(page)

        name = "#{html.xpath('//h1//text()')}".strip
        price = html.xpath('//ul[contains(@class, "attribute_radio_list")]//span[@class="radio_label" or @class="price_comb"]//text()')
        images = html.xpath('//ul[contains(@id, "thumbs_list_frame")]//@href')


        for i in 0..price.length - 1 do
            if i.even?
                sizes.push(price[i])
            else
                prices.push(price[i])
            end
        end

        name_with_size = sizes.map { |size| "#{name} - #{size}"}
        prices_without_currency = prices.map { |price| "#{price}".gsub! /[^0-9.]/, '' }
        images_with_reg_exp = images.map { |img| "#{img}".gsub! 'thickbox', 'large' }

        for i in 0..sizes.length - 1 do
            item = [name_with_size[i], prices_without_currency[i], images_with_reg_exp.join(', ')]
            array.push(item)
        end

    end

    def writing_data_to_csv
        response = {}
        multi = Curl::Multi.new

        @urls.each do |url|
            response[url] = ""

            curl_easy = Curl::Easy.new(url) do |curl|
                curl.follow_location = true
                curl.ssl_verify_host = 0
                curl.ssl_verify_peer = false
                curl.on_body{|data| response[url] << data; data.size }
            end

            multi.add(curl_easy)
            multi.perform
            parsing_goods(@table, response[url])
        end
        File.write(@name_file, @table.map(&:to_csv).join)
    end

end

puts "Введите имя файла:"
name_file = gets.chomp

puts "Введите ссылку с категорией:"
path_of_file = gets.chomp

page = Parsing.new("#{name_file}.csv", path_of_file)

page.parsing_quantity_pages

page.writing_data_to_csv
puts "Данные успешно получены и записаны в файл #{name_file}.csv"

