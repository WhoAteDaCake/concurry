require "option_parser"

def parse_cmd()
  OptionParser.parse do |parser|
    parser.banner = "Usage: con-curry [...cmd]"

    parser.on("-h", "--help", "Show this help") do
      puts parser
      exit
    end
  end
end