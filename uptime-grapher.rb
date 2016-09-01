#!/usr/bin/env ruby

require 'time'
require 'base64'
require 'json'
require 'rubygems'
require 'excon'
require 'dotenv'
require 'gruff'

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
  def get_uptime_perct(check_name, from=nil, to=nil)
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
    totalup / (totalup + totaldown)
  end

end

def create_graph(filename: 'uptime.png', whitelist_checks: nil)
  g = Gruff::Line.new
  client = PingdomClient.new(ENV['PINGDOM_USER_EMAIL'],
                             ENV['PINGDOM_USER_PASSWD'],
                             ENV['PINGDOM_APP_KEY'])

  all_checks = client.all_checks
  if whitelist_checks
    all_checks = all_checks & whitelist_checks
  end

  now = Time.now
  dts = (0..8).map { |i| now - (i * 7 * 24 * 60 * 60) }.reverse

  puts 'collecting data...'
  puts
  all_checks.each do |check|
  #client.all_checks[0,2].each do |check|
    data = dts.each_cons(2).map do |from, to| 
      client.get_uptime_perct(check, from, to)
    end
    puts "Check: #{check}"
    puts '-' * 80
    puts data
    puts
    g.data(check, data)
  end

  g.title = "Parkwhiz % Uptime by Week"
  # http://stackoverflow.com/questions/14528560/convert-an-array-to-hash-where-keys-are-the-indices
  labels = dts.drop(1).map { |dt| dt.strftime('%m-%d') }
  g.labels = Hash[(0...labels.size).zip labels]

  g.write(filename)
  puts "==> Graph written to: #{filename}"
  filename
end

Dotenv.load
whitelist = ENV['PINGDOM_CHECKS'] ? ENV['PINGDOM_CHECKS'].split(',') : nil
filename = create_graph(whitelist_checks: whitelist)
