require 'open-uri'
require 'fileutils'

class WaybackMachineDownloader

  attr_accessor :base_url, :timestamp

  def initialize params
    @base_url = params[:base_url]
    @timestamp = params[:timestamp].to_i
  end

  def backup_name
    @base_url.split('/')[2]
  end

  def backup_path
    'websites/' + backup_name + '/'
  end

  def get_file_list_curated
    file_list_raw = open "http://web.archive.org/cdx/search/xd?url=#{@base_url}/*"
    file_list_curated = Hash.new
    file_list_raw.each_line do |line|
      line = line.split(' ')
      file_timestamp = line[1].to_i
      file_url = line[2]
      file_id = file_url.split('/')[3..-1].join('/')
      file_id = URI.unescape file_id
      if @timestamp == 0 or file_timestamp <= @timestamp
        if file_list_curated[file_id]
          unless file_list_curated[file_id][:timestamp] > file_timestamp
            file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
          end
        else
          file_list_curated[file_id] = {file_url: file_url, timestamp: file_timestamp}
        end
      end
    end
    file_list_curated
  end

  def download_files
    puts "Downlading #{@base_url} from Wayback Machine..."
    puts
    file_list_curated = get_file_list_curated
    file_list_curated.each do |file_id, file_remote_info|
      file_url = file_remote_info[:file_url]
      file_path_elements = file_id.split('/')
      if file_id == ""
        dir_path = backup_path
        file_path = backup_path + 'index.html'
      elsif file_url[-1] == '/' or not file_path_elements[-1].include? '.'
        dir_path = backup_path + file_path_elements[0..-1].join('/')
        file_path = backup_path + file_path_elements[0..-1].join('/') + 'index.html'
      else
        dir_path = backup_path + file_path_elements[0..-2].join('/')
        file_path = backup_path + file_path_elements[0..-1].join('/')
      end
      unless File.exists? file_path
        FileUtils::mkdir_p dir_path unless File.exists? dir_path
        open(file_path, "wb") do |file|
          begin
            open("http://web.archive.org/web/#{timestamp}id_/#{file_url}") do |uri|
              file.write(uri.read)
            end
          rescue OpenURI::HTTPError => e
            puts "#{file_url} # #{e}"
            file.write(e.io.read)
          end
        end
        puts "#{file_url} -> #{file_path}"
      else
        puts "#{file_url} # #{file_path} already exists."
      end
    end
    puts
    puts "Download complete, saved in #{backup_path}. (#{file_list_curated.size} files downloaded)"
  end

end
