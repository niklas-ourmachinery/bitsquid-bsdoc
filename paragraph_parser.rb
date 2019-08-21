module Bitsquid
	# Represents a scope in the in the source document. Scopes are created by indentiation, and
	# for that indentation, a particular set of tags that will be applied to objects with that
	# indentation.
	Scope = Struct.new(:indent, :tags)

	# Represents a transformation rule. The pattern is a regex pattern that the rule matches, and
	# the proc is a block that is run if there is match.
	Rule = Struct.new(:pattern, :proc)

	# Represents the environment of a running paragraph parser.
	class ParagraphParserEnv
		# The tags that will be used by default for indented text.
		attr_accessor :indent_tags

		# The list of nested scopes that represent the current state.
		attr_accessor :scopes

		# The lines of the document that remain to be processed.
		attr_accessor :lines

		# The Bitsquid::Generator used to generate the HTML.
		attr_accessor :generator

		# Initializes the environment with a list of rules, a SpanParser for inline transforms and
		# a Generator for generating the HTML.
		def initialize(rules, span, generator)
			@rules = rules
			@scopes = []
			@scopes << Scope.new("", %w())
			@indent_tags = %w(blockquote)
			@span = span
			@generator = generator
		end

		# Parses the text, applies the rules, writing the result to the generator.
		def parse(text)
			@lines = text.lines.to_a

			while @lines.size > 0
				line = @lines.shift.chomp
				
				# Split line into indent and text. Blank lines inherit last indent
				indent = line[/^\s*/]
				text = line[indent.size..-1]
				indent = @scopes.last.indent if line[/^\s*$/]

				process_indent(indent)
				process_text(text)
			end
		end

		# Writes the line raw (without span-line transformations) to the generator.
		def write_raw(tags, line)
			@generator.add(@scopes.last.tags + tags, line)
		end

		def write_escaped(tags, line)
			line = line.gsub(/&/, "&amp;")
			line = line.gsub(/</, "&lt;")
			write_raw(tags, line)
		end

		# Writes the line (with span-line transformation) to the generator using the tags.
		# (Scope tags are added automatically.)
		def write(tags, line)
			line = @span.transform(line) if line
			write_raw(tags, line)
		end
		

		# Convenience function for writing some raw text, followed by some span-transformed
		# text.
		def write_both(tags, raw, line)
			line = raw + @span.transform(line)
			write_raw(tags, line)
		end

		# Handles indentation changes. Pops all de-indented scopes and adds new scopes for
		# indentation.
		def process_indent(indent)
			unless @scopes.last.indent
				return unless indent

				if indent.size > @scopes[-2].indent.size
					@scopes.last.indent = indent
				else
					@scopes.pop
				end
			end

			@scopes.pop while indent.size < @scopes.last.indent.size
			if indent.size > @scopes.last.indent.size
				@scopes << Scope.new(indent, @scopes.last.tags + @indent_tags)
			end
		end

		# Processes text by applying the first rule that matches.
		def process_text(line)
			@rules.each do |rule|
				if rule.pattern.match(line)
					rule.proc.call(self, $~)
					return
				end
			end
		end
	end
	
	# Class for parsing the lines of a source document.
	#
	# The parser is created by adding rules. Each rule is a regex that is matched and
	# a command that should be performed on match. The command from the first rule that
	# matches the line is applied.
	class ParagraphParser
		# Returns the list of rules
		attr_accessor :rules

		def initialize
			@rules = []
			add_rule(/^\s*$/, %w(), %w())
		end

		# Parses the text using the rule set, using the specified SpanParser and Generator.
		# The result is written to the generator.
		def parse(text, span, generator)
			env = ParagraphParserEnv.new(@rules, span, generator)
			env.parse(text)
		end

		# Adds a generic rule, when the pattern is matched, the block is called. The first
		# argument to the block is the running ParagraphParserEnv, and the second argument
		# is the match object from the regex.
		#
		# This is the main function for defining rules. The result of the functions are
		# convenience functions.
		def on(pattern, &action)
			@rules << Rule.new(pattern, action)
		end

		# Adds a rule for parsing a block of text delimited by a start and end pattern.
		# When the pattern is matched, the action block is called, with the arguments:
		# 
		#     (env, block, start_match, end_match)
		#
		# Env is the running ParagraphParserEnv, block is an Array of the lines delimited
		# by the patterns. start_match and end_match are the match objects for the start
		# and end patterns.
		def on_block(start_pattern, end_pattern, &action)
			on(start_pattern) do |env, start_match|
				indent = env.scopes.last.indent
				block = []
				while true
					line = env.lines.shift.chomp
					line = line[indent.size..-1]
					line = line || ""
					break if line.match(end_pattern)
					block << line
				end
				end_match = $?
				action.call(env, block, start_match, end_match)
			end
		end

		# Adds a rule that writes the first matching group of the regex with the specified
		# context. If before is specified, a nil-line with that context is written before.
		def add_rule(pattern, before, context)
			on(pattern) do |env, match|
				env.write(before, nil) if before
				env.write(context, match[1])
			end
		end

		# Adds a list rule. On match a new scope is created, with the specified context.
		def add_list_rule(pattern, before, context)
			on(pattern) do |env, match|
				env.write(before, nil) if before
				env.scopes << Scope.new(nil, env.scopes.last.tags + context)
				env.process_text(match[1])
			end
		end

		# Adds a list rule with a header. A different context (the header_context) is applied
		# to the matching lines, the (main_context) is used as scope for the following lines.
		def add_list_rule_with_header(pattern, before, header_context, main_context)
			on(pattern) do |env, match|
				env.write(before, nil) if before
				env.write(header_context, match[1])
				env.scopes << Scope.new(nil, env.scopes.last.tags + main_context)
			end
		end
	end
end