# frozen_string_literal: true

require 'tty-config'
require 'tty-box'
require 'tty-prompt'
require 'tty-spinner'
require 'ruby-progressbar'
require 'pastel'
require 'fileutils'
require 'pathname'
require 'facets'
require 'yaml'
require 'yaml/store'
require 'csv'
require 'mini_exiftool'
require 'logger'
require 'net/http'
require 'uri'
require 'json'

config = TTY::Config.new
config.filename = 'paths'
config.append_path "P:/DigitalProjects/_TDD/0_dev/workflow"
config.read
log = Logger.new "P:/DigitalProjects/_TDD/0_dev/workflow/tdd-copyright-lookup.log"
log.level = Logger::INFO

def lookup_copyright(title, author="", sleeptime=0.1)
    pthing = Pastel.new
    query = []
    if author.empty?
        print pthing.cyan("Looking up \"#{title}\"\n")
        query = [
            {
            "column_name" => "titles",
            "operator_type" => "",
            "query" => "#{title}",
            "type_of_query" => "phrase"
            }
        ]
    else
        print pthing.cyan("Looking up \"#{title}\" by #{author}\n")
        query = [
            {
            "column_name" => "titles",
            "operator_type" => "",
            "query" => "#{title}",
            "type_of_query" => "phrase"
            },
            {
            "column_name" => "claimants",
            "operator_type" => "AND",
            "query" => "#{author}",
            "type_of_query" => "contains"
            }
        ]
    end
    uri = URI.parse("https://api.publicrecords.copyright.gov/search_service_external/advance_search")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:103.0) Gecko/20100101 Firefox/103.0"
    request["Accept"] = "application/json, text/plain, */*"
    request["Accept-Language"] = "en-US,en;q=0.5"
    request["Origin"] = "https://publicrecords.copyright.gov"
    request["Connection"] = "keep-alive"
    request["Sec-Fetch-Dest"] = "empty"
    request["Sec-Fetch-Mode"] = "cors"
    request["Sec-Fetch-Site"] = "same-site"
    request["Te"] = "trailers"
    request.body = JSON.dump({
        #"date_field" => "creation_date_as_year",
        #"start_date" => "1977-01-01 00:00:00",
        #"end_date" => "1984-01-01 00:00:00",
        "page_number" => 1,
        "parent_query" => query,
        "records_per_page" => 10,
        "sort_field" => "relevancy",
        "sort_order" => "asc",
        "highlight" => true,
        "model" => ""
    })

    req_options = {
        use_ssl: uri.scheme == "https",
    }

    #print pthing.yellow("Sleeping #{sleeptime}\n")
    sleep(sleeptime)
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
    end

    registration_date = ""
    if response.code == "200"
        #print pthing.green("Response: #{response.code}\n")
        #print pthing.green("#{response.body}\n")
        body = JSON.parse(response.body)
        if body["metadata"]["hit_count"] > 0
            registration_date = body["data"][0]["hit"]["registration_number_list"][0]["registration_date"]
            print pthing.green("FOUND ONE with registration date #{registration_date}\n")
        else
            print pthing.yellow("No hits\n")
        end
    else
        #print pthing.red("Response: #{response.code}\n")
        if response.code == "429"
            print pthing.yellow("Too many requests, retrying...\n")
            registration_date = lookup_copyright(title, author, sleeptime * 5)
        elsif response.code == "503"
            print pthing.red("Got a 503\n")
            registration_date = lookup_copyright(title, author, sleeptime * 50)
        else
            print pthing.red("ERROR: #{response.code}\n")
        end
    end

    return registration_date
end

#
# Entry point
#

is_1978 = false

if is_1978
    # For 1978 Only
    basefile = "UH Theses 1978 Only.csv"
    hdr_title = "TITLE"
    hdr_author = ""
    hdr_cdate = "Metadata/Rights Notes"
    use_rights = false
else
    # For 1979-1988
    basefile = "UH_Theses_1979_1988_fullmetaFINAL.csv"
    hdr_title = "dc.title"
    hdr_author = "dc.creator"
    hdr_cdate = "dc.date.copyright"
    use_rights = true
end

pastel = Pastel.new
#function_path = Pathname.new(config.fetch(:toMetadataEditing))
function_path = Pathname.new("C:/Users/hoovers/Documents/MovedFrom-Downloads")
data = CSV.parse(File.read("#{function_path}/#{basefile}"), headers: true)
articles = ["A", "a", "An", "an", "The", "the"]
bys = ["By", "by"]

data.each do |row|
    #1978 Only has "Title /by Author." but 1979-1988 has separate "dc.title" and "dc.creator"
    title = ""
    title_col = row["#{hdr_title}"]
    if hdr_author.empty?
        ta_array = title_col.split("/")
        title = ta_array[0]
    else
        title = title_col
    end
    title_array = title.split(" ")
    if articles.include?(title_array[0])
        title = title_array[1..10].join(" ")
    else
        title = title_array[0..9].join(" ")
    end
    author = ""
    unless hdr_author.empty?
        author = row["#{hdr_author}"]
        author = author.delete_suffix(".")
        author_array = author.split(",")
        if bys.include?(author_array[0])
            author = author_array[1..-1].join(" ")
        else
            author = author_array[0..-1].join(" ")
        end
    end

    registration_date = lookup_copyright(title, author)
    unless registration_date.empty?
        previous_content = row["#{hdr_cdate}"].to_s
        if previous_content.empty?
            row["#{hdr_cdate}"] = "#{registration_date}"
        else
            row["#{hdr_cdate}"] = "#{previous_content}||#{registration_date}"
        end
    end
    if use_rights
        row["dc.rights"] = "In Copyright"
    end
end

CSV.open("#{function_path}/tdd-copyright-lookup.csv", "w") do |csv|
    csv << data.headers
    data.each do |row|
        csv << row
    end
end
