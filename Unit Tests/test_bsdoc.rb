# Tests the bscod documentation system.

require '../init.rb'

# Unit tests for the Bitsquid documentation system.
class Test
	def initialize
		@doc = Bitsquid::Doc.new
		@lines = IO.read("testdata.bsdoc").lines.to_a
	end

	def assert_equal(a, b)
		if a != b
		puts "Expected:"
			puts(a)
			puts "Result:"
			puts(b)
			raise "Mismatch"
		end
	end

	def test
		while @lines.size > 0
			skip_separator
			input = skip_separator
			output = skip_separator
			break if input == nil && output == nil
			print "."
			assert_equal(output, @doc.parse(input))
		end
		puts
	end

	def skip_separator
		res = []
		while @lines.size > 0
			line = @lines.shift
			return res.join('') if separator?(line)
			res << line
		end
		return nil
	end

	def separator?(line)
		return line =~ /\-{50,}/
	end
end

Test.new.test