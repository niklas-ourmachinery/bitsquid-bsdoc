module Bitsquid
	# Format module for generating AltDevBlogADay articles.
	class AltDev
		attr_reader :data

		def initialize
			@par = Bitsquid::ParagraphParser.new
			@span = Bitsquid::SpanParser.new
			@data = {}
			setup_par_rules
			setup_span_rules
		end

		def parse(text)
			gen = Bitsquid::Generator.new
			@par.parse(text, @span, gen)
			return gen.generate()
		end

	private
		def prelang(name)
			return "text" if name == "code"
			return "html4strict" if name == "html"
			return name
		end

		def setup_par_rules
			@par.on(/^(#+)\s+(.*)/) do |env, match|
				level = match[1].size
				if level==1 then
					env.write(['h2 class="title"'], match[2])
					data[:title] = match[2]
				else
					tag = "h#{level}"
					env.write([tag], match[2])
				end
			end
			@par.add_list_rule(/^\*\s+(.*)/, %w(ul), %w(ul li))
			@par.add_list_rule_with_header(/^:\s*(.*)/, %w(dl), %w(dl dt), %w(dl dd))

			@par.on(/^@(lua|code|cpp|ruby|html)line\s+(.*)/) do |env, match|
				env.write(%w(), nil)
				env.write_escaped([%Q{pre escaped="true" lang="#{prelang(match[1])}"}], match[2])
			end
			@par.on_block(/^@(code|cpp|lua|ruby|html)/, /^@end(code|cpp|lua|ruby|html)/) do |env, block, start|
				block.each {|line| env.write_escaped([%Q{pre escaped="true" lang="#{prelang(start[1])}"}], line)}
			end
			
			@par.on(/^@img\s+(\S+)/) {|env,match| env.write_raw(['p class="image"'], %Q(<img src="#{match[1]}"/>))}
			@par.add_rule(/^@caption\s+(.*)/, %w(), ['p class="caption"'])

			@par.on(/^@th\s+(.*)/) do |env, match|
				env.write(%w(table), nil)
				match[1].split("\t").each do |s| 
					env.write(%w(table tr), nil) 
					env.write(%w(table tr th), s)
				end
			end
			@par.on(/^@td\s+(.*)/) do |env, match|
				env.write(%w(table), nil)
				match[1].split("\t").each do |s| 
					env.write(%w(table tr), nil) 
					env.write(%w(table tr td), s)
				end
			end

			@par.on(/^@\S+/) do |env, match| raise "Bad keyword #{match[0]}" end
			@par.add_rule(/(.*)/, nil, %w(p))
		end

		def setup_span_rules
			word = '\S*[^\s\.,]'
			@span.add_rule(/\\%/, '___magic_string_2352_')
			
			@span.add_rule(/&/, '&amp;')
			@span.add_rule(/</, '&lt;')
			@span.add_rule(/%i (#{word})/, '<em>\\1</em>')
			@span.add_rule(/%b (#{word})/, '<strong>\\1</strong>')
			@span.add_rule(/%c (#{word})/, '<tt>\\1</tt>')
			@span.add_rule(/%ii (.*?) %ii/, '<em>\\1</em>')
			@span.add_rule(/%bb (.*?) %bb/, '<strong>\\1</strong>')
			@span.add_rule(/%cc (.*?) %cc/, '<tt>\\1</tt>')

			@span.add_rule(/%link (#{word})/, '<a class="link" href="\\1">\\1</a>')
			@span.add_rule(/%ll (.*?) (.*?) %ll/, '<a class="link" href="\\1">\\2</a>')

			@span.add_rule(/%[a-z]/) {|x| raise "Bad span rule #{x[0]}"}

			@span.add_rule(/___magic_string_2352_/, '%')
		end
	end
end