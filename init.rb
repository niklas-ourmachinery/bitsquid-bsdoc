unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'altdev'
require_relative 'bsdoc'
require_relative 'generator'
require_relative 'paragraph_parser'
require_relative 'span_parser'
require_relative 'toc'