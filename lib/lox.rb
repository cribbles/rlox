require './scanner'

class Lox
  EXIT_CODES = {
    USAGE: 64,
    DATA_ERROR: 65
  }

  private_constant :EXIT_CODES

  class << self
    def cli(*args)
      if args.length > 1
        puts "Usage: rlox [script]"
        exit EXIT_CODES[:USAGE]
      elsif args.length == 1
        run_file(args.first)
      else
        run_prompt
      end
    end

    def run_prompt
      loop do
        print "> "
        break unless line = gets.chomp
        run line
        self.had_error = false
      end
    end

    def run_file(path)
      run File.read(path)
      exit EXIT_CODES[:DATA_ERROR] if had_error?
    end

    def error(line, message)
      report(line, "", message)
    end

    private

    attr_writer :had_error

    def had_error?
      @had_error ||= false
    end

    def run(source)
      tokens = Scanner.new(source).scan_tokens
      tokens.each do |token|
        puts token
      end
    end

    def report(line, where, message)
      puts "[line #{line}] Error #{where}: #{message}"
      self.had_error = true
    end
  end
end

Lox.cli(*ARGV)