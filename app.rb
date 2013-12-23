require 'sinatra'
require 'haml'
require 'open-uri'
require 'erb'
require 'ostruct'

configure do
  Templates = Dir['templates/*.erb'].map do |path|
    content = File.read path
    {
      title: path,
      content: content,
      permalink: "?template=#{URI.escape(content, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
    }
  end
  Cache = OpenStruct.new(
    data: nil,
    version: Time.now
  )
end

def compile
  if (template = params[:template].to_s) != ''
    templateEncoded = URI.escape template, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    @permalink = "http://chnroutesapp.micy.in/?template=#{templateEncoded}"
    @permalink_raw = "http://chnroutesapp.micy.in/raw?template=#{templateEncoded}"
    if Time.now - Cache.version > 60
      Cache.data = nil
    end
    if Cache.data
      data = Cache.data
    else
      Cache.version = Time.now
      Cache.data = data = open('http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest').read.scan(/^apnic\|cn\|ipv4\|[\d\.]+\|\d+\|\d+\|a\w*$/im).map do |m|
        m = m.split '|'
        starting_ip = m[3]
        num_ip = m[4].to_i

        imask = 0xffffffff ^ (num_ip - 1)
        imask = imask.to_s 16
        mask = []
        for i in 1..4
          mask << imask.slice(-2 * i, 2).to_i(16)
        end
        mask = mask.reverse.join '.'
        {
          ip: starting_ip,
          mask: mask,
          cidr_mask: 32 - Math.log(num_ip, 2).to_i,
        }
      end
    end
    namespace = OpenStruct.new(routes: data)
    @result = ERB.new(template).result(namespace.instance_eval { binding }) 
  end
end
get '/' do
  compile
  @templates = Templates
  haml :default
end
get '/raw' do
  compile
  [200, {"Content-Type" => "text/plain"}, @result.to_s]
end
