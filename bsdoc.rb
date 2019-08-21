module Bitsquid
	# Format module for generating bitsquid documentation.
	# See tne Manual for a description of the format.
	class Doc
		# Contains data about the parsed document. data[:title] is the document's title.
		attr_reader :data

		def initialize
			@par = Bitsquid::ParagraphParser.new
			@span = Bitsquid::SpanParser.new
			@data = {}

			@glossary = {}
			@glossary_ref = {}
			
			@is_api_document = false

			setup_par_rules
			setup_span_rules
		end

		# Parses the string text and returns the resulting HTML.
		def parse(text)
			@is_api_document = (text =~ /^@api/)
			gen = Bitsquid::Generator.new
			@par.parse(text, @span, gen)
			return gen.generate()
		end

	private
		def write_with_keyword(env, tags, word, text)
			keystart = %Q{<object type="application/x-oleobject" classid="clsid:1e2a7bd0-dab9-11d0-b93a-00c04fc99f9e" width="0" height="0"><param name="Keyword" value="#{word}"/></object}
			env.write_raw(tags, keystart)
			env.write_both(tags, '>', text)
		end

		def setup_par_rules
			@par.on(/^(#+)\s+(.*)/) do |env, match|
				data[:title] = data[:title] || match[2]
				tag = "h#{match[1].size}"
				name = match[2][/\S+/]
				if @is_api_document && tag == "h2"
					name = match[2][/\S+/]
					write_with_keyword(env, [tag], name, match[2])
				else
					env.write([tag], match[2])
				end
			end
			@par.on(/^@title\s+(.*)/) do |env, match|
				data[:title] = data[:title] || match[1]
				env.write(%w(), nil)
			 	env.write(['h1 id="title"'], match[1])
			 end

			@par.add_list_rule(/^\*\s+(.*)/, %w(ul), %w(ul li))

			@par.on(/^@note\s+(.*)/) do |env, match|
				in_note = env.generator.lines[-1] && env.generator.lines[-1].context[-2] == 'div class="note"'
				env.write(['div class="note"', 'p'], "%b Note") unless in_note
				env.write(['div class="note"'], nil)
				env.write(['div class="note"', 'p'], match[1])
			end

			@par.add_list_rule_with_header(/^:\s*(.*)/, %w(dl), %w(dl dt), %w(dl dd))

			@par.on(/^@(?:lua|code|cpp)line\s+(.*)/) do |env, match|
				env.write(%w(), nil)
				env.write_escaped(%w(pre), match[1])
			end
			@par.on_block(/^@(code|cpp|lua)/, /^@end(code|cpp|lua)/) do |env, block|
				 block.each {|line| env.write_escaped(%w(pre), line)}
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

			@par.on(/^@api/) do |env, match|
				@par.rules.pop
				@par.on(/(.*)/) do |env, match|
					if env.scopes.last.indent == ""
						name = match[1][/^\w+/]
						env.write(%w(), nil)
						write_with_keyword(env, ["p class=\"definition\"", "a name=\"#{name}\""], name, match[1])
					else
						env.write(%w(p), match[1])
					end
				end
			end
			@par.on(/^@text/) do |env, match|
				@par.rules.pop
				@par.add_rule(/(.*)/, nil, %w(p))
			end

			@par.on_block(/^@glossary/, /^@endglossary/) do |env, lines|
				lines.each do |line|
					if line[/^\S+/]
						env.write(['dl', 'dt', "a name=\"glossary-#{line.downcase}\""], line)
						@glossary[line.downcase] = true
					elsif line[/^\s+(\S.*)/]
						env.write(%w(dl dd), $1)
					end
				end
				@glossary_ref.each do |k,v|
					next if @glossary[k.downcase]
					env.write(['dl', 'dt', "a name=\"glossary-#{k.downcase}\""], k)
					env.write(%w(dl dd), '???')
				end
			end

			@par.on(/^@\S+/) do |env, match| raise "Bad keyword #{match[0]}" end
			
			@par.add_rule(/(.*)/, nil, %w(p))
		end

		def glossary(key, text)
			@glossary_ref[key.downcase] = true
			"<a class=\"ref\" href=\"#glossary-#{key.downcase}\">#{text}</a>"
		end

		def setup_span_rules
			word = '\S*[^\s\.,]'
			@span.add_rule(/\\%/, '___magic_string_2352_')
			
			@span.add_rule(/&/, '&amp;')
			@span.add_rule(/</, '&lt;')
			@span.add_rule(/%i (#{word})/, '<i>\\1</i>')
			@span.add_rule(/%b (#{word})/, '<b>\\1</b>')
			@span.add_rule(/%c (#{word})/, '<tt>\\1</tt>')
			@span.add_rule(/%ii (.*?) %ii/, '<i>\\1</i>')
			@span.add_rule(/%bb (.*?) %bb/, '<b>\\1</b>')
			@span.add_rule(/%cc (.*?) %cc/, '<tt>\\1</tt>')

			@span.add_rule(/%r (\w+)\.(\w+)\(\)/, "<a class=\"ref\" href=\"\\1.html\#\\2\">\\1.\\2()</a>")
			@span.add_rule(/%r (\w+)\(\)/, "<a class=\"ref\" href=\"\#\\1\">\\1()</a>")
			@span.add_rule(/%r (\w+)/, "<a class=\"ref\" href=\"\\1.html\">\\1</a>")

			@span.add_rule(/%link (#{word})/, '<a class="link" href="\\1">\\1</a>')

			@span.add_rule(/%g (#{word})/) {|x| glossary(x[1], x[1])}
			@span.add_rule(/%g\((.*?)\) (#{word})/) {|x| glossary(x[1], x[2])}
			@span.add_rule(/%gg (.*?) %gg/) {|x| glossary(x[1], x[1])}
			@span.add_rule(/%gg\((.*?)\) (.*?) %gg/) {|x| glossary(x[1], x[1])}

			@span.add_rule(/%[a-z]/) {|x| raise "Bad span rule #{x[0]}"}

			@span.add_rule(/___magic_string_2352_/, '%')
		end
	end
end