require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'erb'
require 'date'
require 'kindle-your-highlights/kindle_format'

class KindleYourHighlights
  attr_accessor :highlights, :books

  DEFAULT_PAGE_LIMIT = 1
  DEFAULT_DAY_LIMIT  = 365 * 100  # set default as 100 years
  DEFAULT_WAIT_TIME  = 5

  def initialize(file, options = {}, &block)
    @page_limit = options[:page_limit] || DEFAULT_PAGE_LIMIT
    @day_limit  = options[:day_limit]  || DEFAULT_DAY_LIMIT
    @wait_time  = options[:wait_time]  || DEFAULT_WAIT_TIME

    @block = block

    scrape_highlights
  end

  def scrape_highlights
    highlights_page = Nokogiri::HTML(open(file))

    @books = []
    @highlights = []
    @page_limit.times do | cnt |
      @books      += collect_book(highlights_page)
      @highlights += collect_highlight(highlights_page)

      date_diff_from_today = (Date.today - Date.parse(@books.last.last_update)).to_i
      break if date_diff_from_today > @day_limit

      break unless highlights_page
      sleep(@wait_time) if cnt != 0

      @block.call(self) if @block

    end
  end

  def list
    List.new(@books, @highlights)
  end

private
  def collect_book(page)
    page.search(".//div[@class='bookMain yourHighlightsHeader']").map { |b| Book.new(b) }
  end

  def collect_highlight(page)
    page.search(".//div[@class='highlightRow yourHighlight']").map { |h| Highlight.new(h) }.sort_by { |h| h.location }
  end
end

class KindleYourHighlights
  class List
    attr_accessor :books, :highlights, :highlights_hash

    def initialize(books, highlights)
      @books = books
      @highlights = highlights
      @highlights_hash = get_highlights_hash
    end

    def dump(file_name)
      File.open(file_name, "w") do | f |
        Marshal.dump(self, f)
      end
    end

    def self.load(file_name)
      Marshal.load(File.open(file_name))
    end

    def self.merge(left, right)
      books      = left.books.clone
      highlights = left.highlights.clone

      right.books.each do | r_book |
        books << r_book unless books.find { | item | item.asin == r_book.asin }
      end

      right.highlights.each do | r_highlight |
        highlights << r_highlight unless highlights.find { | item | item.annotation_id == r_highlight.annotation_id }
      end

      List.new(books, highlights)
    end

  private
    def get_highlights_hash
      hash = Hash.new([].freeze)
      @highlights.each do | h |
        hash[h.asin] += [h]
      end
      hash
    end
  end

  class Book
    attr_accessor :asin, :author, :title, :last_update

    @@amazon_items = Hash.new

    def initialize(item)
      @asin        = item.attribute("id").value.gsub(/_[0-9]+$/, "")
      @author      = item.xpath("span[@class='author']").text.gsub("\n", "").gsub(" by ", "").strip
      @title       = item.xpath("span/a").text
      @last_update = item.xpath("div[@class='lastHighlighted']").text

      @@amazon_items[@asin] = {:author => author, :title => title}
    end

    def self.find(asin)
      @@amazon_items[asin] || {:author => "", :title => ""}
    end
  end

  class Highlight
    attr_accessor :annotation_id, :asin, :author, :title, :content, :location, :note

    @@amazon_items = Hash.new

    def initialize(highlight)
      @annotation_id = highlight.xpath("form/input[@id='annotation_id']").attribute("value").value
      @asin          = highlight.xpath("p/span[@class='hidden asin']").text
      @content       = highlight.xpath("span[@class='highlight']").text
      @note          = highlight.xpath("p/span[@class='noteContent']").text

      if highlight.xpath("a[@class='k4pcReadMore readMore linkOut']").attribute("href").value =~ /location=([0-9]+)$/
        @location = $1.to_i
      end

      book = KindleYourHighlights::Book.find(@asin)
      @author = book[:author]
      @title  = book[:title]
    end
  end
end

