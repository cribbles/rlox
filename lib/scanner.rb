require './token'
require './token_types'

class LexicalError < Struct.new(:line, :message)
  alias_method :attributes, :deconstruct
end

class Scanner
  TOKEN_TYPE_KEYWORD_LITERALS = (
    TOKEN_TYPE_KEYWORDS.to_h { |kw| [kw.to_s.downcase, kw] }
  ).freeze

  TOKEN_TYPE_SINGLE_CHAR_LITERALS = {
    '(' => TOKEN_TYPES[:LEFT_PAREN],
    ')' => TOKEN_TYPES[:RIGHT_PAREN],
    '{' => TOKEN_TYPES[:LEFT_BRACE],
    '}' => TOKEN_TYPES[:RIGHT_BRACE],
    ',' => TOKEN_TYPES[:COMMA],
    '.' => TOKEN_TYPES[:DOT],
    '-' => TOKEN_TYPES[:MINUS],
    '+' => TOKEN_TYPES[:PLUS],
    ';' => TOKEN_TYPES[:SEMICOLON],
    '*' => TOKEN_TYPES[:STAR],
  }.freeze

  TOKEN_TYPE_SINGLE_CHAR_REGEXP = Regexp.new(
    "\\A[\\#{TOKEN_TYPE_SINGLE_CHAR_LITERALS.keys.join("\\")}]{1}\\z"
  ).freeze

  WHITESPACE_CHAR_REGEXP = /\A[ \r\t]{1}\z/.freeze

  NUMERIC_CHAR_REGEXP = /\A[\d]{1}\z/.freeze

  ALPHANUMERIC_REGEXP = /\A[\d\w_]+\z/.freeze

  ALPHANUMERIC_CHAR_REGEXP = /\A[\d\w_]{1}\z/.freeze

  private_constant *%i(
    ALPHANUMERIC_REGEXP
    ALPHANUMERIC_CHAR_REGEXP
    NUMERIC_CHAR_REGEXP
    TOKEN_TYPE_KEYWORD_LITERALS
    TOKEN_TYPE_SINGLE_CHAR_LITERALS
    TOKEN_TYPE_SINGLE_CHAR_REGEXP
    WHITESPACE_CHAR_REGEXP
  )

  def initialize(source)
    @source = source
    @start = 0
    @current = 0
    @line = 1
  end

  def scan_tokens
    tokens = []
    errors = []
  
    scan(
      token: ->(result) { tokens << result },
      error: ->(result) { errors << result }
    )
  
    { tokens: tokens, errors: errors }
  end

  def each_token
    scan(
      token: ->(result) { yield token: result },
      error: ->(result) { yield error: result }
    )
  end

  private

  attr_reader :source
  attr_accessor :start, :current, :line

  def scan(token:, error:)
    until at_end?
      case result = scan_token
      when Token
        token.(result)
      when LexicalError
        error.(result.attributes)
      else
        next
      end
    end
    token.(eof)
  end

  def at_end?
    current >= source.length
  end

  def scan_token
    self.start = current
    case char = advance
    when TOKEN_TYPE_SINGLE_CHAR_REGEXP
      token(TOKEN_TYPE_SINGLE_CHAR_LITERALS[char])
    when WHITESPACE_CHAR_REGEXP
      # do nothing
    when NUMERIC_CHAR_REGEXP
      number
    when ALPHANUMERIC_CHAR_REGEXP
      identifier
    when "\n"
      self.line += 1
    when '!'
      token(match('=') ? TOKEN_TYPES[:BANG_EQUAL] : TOKEN_TYPES[:BANG])
    when '='
      token(match('=') ? TOKEN_TYPES[:EQUAL_EQUAL] : TOKEN_TYPES[:EQUAL])
    when '<'
      token(match('=') ? TOKEN_TYPES[:LESS_EQUAL] : TOKEN_TYPES[:LESS])
    when '>'
      token(match('=') ? TOKEN_TYPES[:GREATER_EQUAL] : TOKEN_TYPES[:GREATER])
    when '/'
      if match('/')
        advance until peek == "\n" || at_end?
      else
        token(TOKEN_TYPES[:SLASH])
      end
    when '"'
      string
    else
      LexicalError.new(line, "Unexpected character.")
    end
  end

  def advance
    curr = source[self.current]
    self.current += 1
    curr
  end

  def token(type, literal = nil)
    lexeme = source[start...current]
    Token.new(type, lexeme, literal, line)
  end

  def match(expected)
    return false if at_end? || source[current] != expected

    self.current += 1
    true
  end

  def peek
    return "\0" if at_end?

    source[current]
  end

  def peek_next
    return "\0" if current + 1 >= source.length

    source[current + 1]
  end

  def string
    until peek == '"' || at_end?
      self.line += 1 if peek == "\n"
      advance
    end

    if at_end?
      return LexicalError.new(line, "Unterminated string.")
    end

    # The closing ".
    advance

    value = source[(start + 1)...(current - 1)]
    token(TOKEN_TYPES[:STRING], value)
  end

  def number
    advance while numeric?(peek)

    if peek == '.' && numeric?(peek_next)
      advance
      advance while numeric?(peek)
    end

    token(TOKEN_TYPES[:NUMBER], source[start...current].to_f)
  end

  def identifier
    advance while alphanumeric?(peek)

    text = source[start...current]
    type = TOKEN_TYPE_KEYWORD_LITERALS[text] || TOKEN_TYPES[:IDENTIFIER]

    token(type)
  end

  def eof
    Token.new(TOKEN_TYPES[:EOF], "", nil, line)
  end

  def numeric?(char)
    NUMERIC_CHAR_REGEXP.match?(char)
  end

  def alphanumeric?(string)
    ALPHANUMERIC_REGEXP.match(string)
  end
end