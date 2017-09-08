#! /usr/bin/ruby
# Fetch chat data from HipChat, post to Dashing.io dashboard
# Uses dashing-table widget: https://github.com/nick123pig/dashing-table
# Anders Nordby <anders@fupp.net>, 2016-03-16

require 'httparty'
require 'pp'
require 'nokogiri'
require 'htmlentities'

room="123456"
token="YYYYYYYYYYYYYYYYYYYYYYYYY"
coder = HTMLEntities.new

colors = {
	"green"		=> "background-color:#009933; color:#000000",
	"yellow"	=> "background-color:#ffff00; color:#000000",
	"red"		=> "background-color:#cc2211; color:#000000",
}

begin
	response = HTTParty.get("https://api.hipchat.com/v2/room/#{room}/history/latest?auth_token=#{token}&max-results=6&timezone=CET")

rescue Exception => e
	puts "Error fetching data from HipChat: #{e.to_s}"
	exit 3
end

if response.code != 200
	puts "Error fetching data from HipChat, got response #{response.code.to_s} #{response.message}."
	exit 3
end

#pp response
rows = []
json = JSON.parse(response.body)
json["items"].each do |key|
	color = key["color"]
	date = key["date"]
	sdate = date[11..15]
	# evt name og droppe alt etter mellomrom ?
	if key["from"]["mention_name"].nil?
		from = key["from"]
	else
		from = key["from"]["name"]
#		from = key["from"]["mention_name"]
		from = from.gsub(/\s+.*/, "")
	end
	doc = Nokogiri::HTML(key["message"])
	text = doc.xpath("//text()").remove.to_s
	if text.length > 118
		text = text[0,117] + ".."
	end
	# HTML safe now?
	text = coder.encode(text)
	# Percent must be encoded
	text = text.gsub(/%/, "&#37;")
	# Remove .foo.local in hostnames
	text = text.gsub(/(\w+)\.foo\.local/, '\1')

#	puts "Got key: #{key} color: #{color}"
	puts "Got color #{color} sdate #{sdate} from #{from} text #{text}"
	bstyle = "font-size: x-small; font-family: monospace; word-wrap: break-word; word-break: break-all; -webkit-hyphens: none"
	if colors.has_key?(color)
		style = colors[color] + "; #{bstyle}"
	else
		style = bstyle
	end
	rows.push(
		{
			"style" => style,
			"cols" => [
				{"value" => from},
				{"value" => sdate},
				{"value" => text},
			]
		}
	)
end

headers = [{
	"style" => "font-size: x-small",
	"cols" => [
		{"value"=>"From"},
		{"value"=>"When"},
		{"value"=>"Message"},
	]
}]

pp headers
pp rows

response = HTTParty.post("http://dashing.foo.local:3030/widgets/hipchat_devops",
  :body => { auth_token: "YYYYY", hrows: headers, rows: rows }.to_json,
  debug_output: $stderr)
