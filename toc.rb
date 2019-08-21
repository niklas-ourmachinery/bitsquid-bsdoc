module Bitsquid
	# Does headline enumeration and table of content generation of a HTML document.
	class Toc
		def initialize
			@h1 = @h2 = @h3 = 0
			@toc = []
			@toc << "<h1>Contents</h1>" << "" << "<div id=\"toc\">"
		end

		# Parses a HTML document, adds enumeration to all h1, h2 and h3 headers, adds
		# a table of content and returns the result.
		def parse(html)
			html = html.dup
			html.gsub!(/(<h\d>)(.*?)(<\/h\d>)/m) do |match|
				open = $1
				text = $2
				close = $3
				if open == "<h1>"
					@h1 += 1
					@h2 = 0
					num = "#{@h1}."
				elsif open == "<h2>"
					@h2 += 1
					@h3 = 0
					num = "#{@h1}.#{@h2}"
				elsif open == "<h3>"
					@h3 += 1
					num = "#{@h1}.#{@h2}.#{@h3}"
				end
				tags = ""
				if text[/(<.*>)(.*)/m] then
					tags = $1
					text = $2
				end
				link = text.strip
				toc_print "#{open}<a href=\"\##{link}\">#{num} #{text}</a>#{close}"
				"#{open}#{tags}<a name=\"#{link}\">#{num} #{text}</a>#{close}"
			end
			@toc << "</div>\n"
			add_toc!(html)
			return html
		end

	private
		def add_toc!(html)
			toc = "\n" + @toc.join("\n")
			if html[/<h1 id="title">/]
				html.gsub!(/(<h1 id="title">.*?<\/h1>)/) do
					$1 + toc
				end
			elsif html[/<body>/]
				html.gsub!(/(<body>)/) do
					$1 + toc
				end
			else
				html.gsub!(/\A/s, toc)
			end
		end

		def toc_print(s)
			@toc << "\t" + s 
		end
	end
end