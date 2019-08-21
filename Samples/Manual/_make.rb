require 'optparse'
require '../../init'

options = {}
OptionParser.new do |opts|
		opts.on('-v', '--view', 'View HTML files in browser') {|v| options[:view] = v}
end.parse!

template = File.read("template.html")

files = ARGV
files = Dir.glob("*.bsdoc") if files.size == 0

files.each do |path|
	html = path.sub(/\.bsdoc$/, ".html")
	input = IO.read(path)
	parser = Bitsquid::Doc.new
	text = template.dup
	text["[[BODY]]"] = parser.parse(input)
	text["[[TITLE]]"] = parser.data[:title]
	text = Bitsquid::Toc.new.parse(text)
	File.open(html, 'w') {|f| f.write(text)}
	if options[:view]
		`open "#{html}"` if RUBY_PLATFORM =~ /darwin/i
		`start "#{html}"` if RUBY_PLATFORM =~ /mswin/i
	end
end
