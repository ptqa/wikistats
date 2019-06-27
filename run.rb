require 'sinatra'
require 'rest-client'
require 'json'
require 'mediawiki_api'
require 'pry'

TYPES = {
  ky: 'Просроченные_подведения_итогов_по_удалению_страниц',
  kpm: 'Просроченные_подведения_итогов_по_переименованию_страниц',
  kyl: 'Статьи_для_срочного_улучшения',
  kob: 'Просроченные_подведения_итогов_по_объединению_страниц',
  vys: 'Незакрытые_обсуждения_восстановления_страниц'
}


DATAPAGE = 'Участник:PtQa/Статистика отставания/data'
GRAPHPAGE = 'Ky_kpm_kob_vys_stat.png'

class WikiStats
  class << self
    attr_accessor :client
    def client
      @client ||= MediawikiApi::Client.new "https://ru.wikipedia.org/w/api.php"
    end
  end
end

get '/' do
  main
end

def main
  WikiStats.client.log_in ENV['WIKI_USER'],ENV['WIKI_PASS']
  # Get current stats via API
  new_stats = get_stats.to_h
  # Load old stas for graph
  old_stats = load_old_stats
  # Merge new and old
  stats = merge_stats(new_stats,old_stats)
  # Save to file
  save_stats(stats)
  # Update stats on wiki
  update_stats(new_stats)
  # Generate graph
  plot_graph
  # Upload graph
  upload_graph
end

def get_stats
  TYPES.map {|k,v| api_get(k,v)}
end

def api_get(name,desc)
  j = JSON.parse(RestClient.get(gen_url(desc)))
  pages = j.dig('query','pages').first&.last&.dig('categoryinfo','pages')
  return [ name, pages ]
end

def gen_url(name)
  URI.escape("https://ru.wikipedia.org/w/api.php?action=query&prop=categoryinfo&format=json&titles=Категория:Википедия:#{name}")
end

def plot_graph
  File.delete('/tmp/result.png')
  system('gnuplot result.graph > /dev/null')
end

def load_old_stats
  parse_old_stats
end

def parse_old_stats
  WikiStats.client.get_wikitext(DATAPAGE).body
end

def merge_stats(new_stats, old_stats)
  old_stats + "\n" + format_stats(new_stats)
end

def format_stats(stats)
  date = Time.now.strftime("%d.%m.%Y") 
  new = "#{date} #{stats[:ky]} #{stats[:kpm]} #{stats[:kob]} #{stats[:vys]} #{stats[:kyl]}"
end

def save_stats(stats)
  IO.write('/tmp/stat', stats)
end

def update_stats(stats)
  WikiStats.client.edit(appendtext: "\n"+format_stats(stats)+"\n", title: DATAPAGE, minor: true, summary: 'Automatic data update')
end

def upload_graph
  WikiStats.client.upload_image(GRAPHPAGE, '/tmp/result.png', 'Automatic graph update', 'ignorewarnings')
end

pry.binding
