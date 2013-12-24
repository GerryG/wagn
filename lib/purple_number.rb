class PurpleNumber < SimpleDelegator
  @@current = nil

  class << self
    def current
      @@current = 1 if @@current.nil?
      @@current
    end

    def parse_purple number
      raise "Not base 36 number #{number}" if number.strip =~ /[^a-z\d]/i
      number.to_i(36)
    end

    def next_number number=nil
      number = parse_purple number  if String===number
      if number.nil?
        @@current = current + 1
      elsif number > current
        @@current = number
      else
        number
      end
    end
  end

  def to_s; __getobj__.to_s( 36 ).upcase end

  def initialize number=nil
    __setobj__ self.class.next_number number
  end
end
