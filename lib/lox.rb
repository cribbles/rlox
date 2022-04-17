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
        exit EXIT_CODES.USAGE
      elsif args.length == 1
        run_file(args.first)
      else
        run_prompt
      end
    end

    def run_prompt(stream = true)
      loop do
        print "> "
        break unless line = gets.chomp
        run line, stream
        self.had_error = false
      end
    end

    def run_file(path, stream = true)
      run File.read(path), stream
      exit EXIT_CODES.DATA_ERROR if had_error?
    end

    private

    attr_writer :had_error

    def had_error?
      @had_error ||= false
    end

    def run(source, stream)
      if stream
        run_stream source
      else
        run_sync source
      end
    end

    def run_stream(source)
      tokens = []
      Scanner.new(source).each_token do |element|
        case element
        in { token: token }
          tokens << token
        in { error: [line, message] }
          error(line, message)
        else
          next
        end
      end
      tokens.each &method(:token)
    end

    def run_sync(source)
      Scanner.new(source).scan_tokens => { tokens:, errors: }
      errors.each { |(line, message)| error(line, message) }
      tokens.each &method(:token)
    end

    def token(token)
      puts token
    end

    def error(line, message)
      report(line, "", message)
    end

    def report(line, where, message)
      puts "[line #{line}] Error #{where}: #{message}"
      self.had_error = true
    end
  end
end

Lox.cli(*ARGV)