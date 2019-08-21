module Bitsquid
	# Handles in-line transformation of text.
	#
	# The transformation consist of a number of RegEx rules that are applied in turn to the text.
	class SpanParser
		def initialize
			@rule = Struct.new(:pattern, :replace)
			@rules = []
		end

		# Adds a new rule. A rule consists of a match pattern and a replacement string, or a
		# block that returns the replacment value. The block gets the regex match object as
		# argument.
		def add_rule(pattern, replace = nil, &proc)
			if replace
				@rules << @rule.new(pattern, replace)
			else
				@rules << @rule.new(pattern, proc)
			end
		end

		# Transforms the text using the set of rules in this span parser and returns the
		# result.
		def transform(text)
			@rules.each do |rule|
				if rule.replace.is_a?(String)
					text = text.gsub(rule.pattern, rule.replace)
				else
					text = text.gsub(rule.pattern) {rule.replace.call($~)}
				end
			end
			return text
		end
	end
end