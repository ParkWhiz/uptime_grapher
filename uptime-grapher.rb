#!/usr/bin/env ruby

require 'time'
require 'base64'
require 'json'
require 'optparse'
require 'rubygems'
require 'excon'
require 'dotenv'
require 'gruff'
require 'chronic'
require 'facets/string/titlecase'

class PingdomClient

  def initialize(pingdom_user_email, pingdom_user_password, pingdom_app_key)
    basic_auth = Base64.strict_encode64(
      "#{pingdom_user_email}:#{pingdom_user_password}")
    @auth_headers = {'Authorization' => "Basic #{basic_auth}",
                     'App-Key' => pingdom_app_key}
    @check_ids = {}
    refresh_check_ids
  end

  def refresh_check_ids
    resp = Excon.get('https://api.pingdom.com/api/2.0/checks',
                      :headers => @auth_headers)
    body = JSON.parse(resp.body)
    body['checks'].each do |check|
      @check_ids[check['name']] = check['id']
    end
  end

  def all_checks
    @check_ids.keys
  end

  # from and to should be Time instances
  def get_uptime_perct(check_name, from=nil, to=nil, scheduled_minutes=nil)
    from = from ? from.to_i : 0
    to = to ? to.to_i : Time.now.to_i
    check_id = @check_ids[check_name]
    resp = Excon.get(
      "https://api.pingdom.com/api/2.0/summary.average/#{check_id}",
      :headers => @auth_headers,
      :query => {"from" => from, "to" => to, "includeuptime" => true})
    body = JSON.parse(resp.body)
    status = body['summary']['status']
    totalup = status['totalup'].to_f
    totaldown = status['totaldown'].to_f
    if scheduled:
      totaldown -= scheduled
      totalup += scheduled
    end
    (totalup / (totalup + totaldown)) * 100
  end

end

def create_graph(interval: 'week', range: 8, filename: 'uptime.png', whitelist_checks: nil, scheduled: {})
  g = Gruff::Line.new
  client = PingdomClient.new(ENV['PINGDOM_USER_EMAIL'],
                             ENV['PINGDOM_USER_PASSWD'],
                             ENV['PINGDOM_APP_KEY'])

  all_checks = client.all_checks
  if whitelist_checks
    all_checks = all_checks & whitelist_checks
  end

  now = Time.now
  dts = (0..range).map { |i| Chronic.parse("#{i} #{interval} ago") }.reverse

  puts 'collecting data...'
  puts
  all_checks.each do |check|
    data = dts.each_cons(2).map do |from, to| 
      client.get_uptime_perct(check, from, to, scheduled['check'])
    end
    puts "Check: #{check}"
    puts '-' * 80
    puts data
    puts
    g.data(check, data)
  end

  g.title = "Parkwhiz % Uptime by #{interval.to_s.titlecase}"
  # http://stackoverflow.com/questions/14528560/convert-an-array-to-hash-where-keys-are-the-indices
  timefmt = '%m-%d'
  timefmt = '%Y' if interval == :year
  labels = dts.drop(1).map { |dt| dt.strftime('%m-%d') }
  g.labels = Hash[(0...labels.size).zip labels]

  g.write(filename)
  puts "==> Graph written to: #{filename}"
  filename
end

Dotenv.load

interval = 'week'
range = 8
filename = 'uptime.png'
whitelist = ENV['PINGDOM_CHECKS'] ? ENV['PINGDOM_CHECKS'].split(',') : nil
scheduled = {}

opt_parser = OptionParser.new do |opt|

  opt.banner = 'Create historical uptime report'
  opt.separator ""
  opt.separator "Usage: ./uptime-grapher.rb [options] "

  opt.on('-i', '--interval [INTERVAL]', [:week, :month, :year], 
         'Report uptimes for every {week,month,year}') do |cl_interval|
    interval = cl_interval
  end

  opt.on('-r', '--range [RANGE]', Integer, 
         'Number of data points to report') do |cl_range|
    range = cl_range
  end

  opt.on('-f', '--file [FILE]', 'output filename') do |cl_filename|
    filename = cl_filename
  end

  opt.on('-w', '--whitelist [check1,check2,check3]', Array, 
         'checks to include') do |cl_whitelist|
    whitelist = cl_whitelist
  end

  opt.on('-s' '--scheduled [FILE]', 'YAML file showing number of minutes of expected downtime per service') do |scheduled|
    scheduled = YAML.load_file(scheduled)
  end

end.parse!

filename = create_graph(interval: interval, range: range, filename: filename, whitelist_checks: whitelist, scheduled: scheduled)
