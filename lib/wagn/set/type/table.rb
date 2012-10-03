module Wagn::Set::Type::Table
  def validate_content( content )
    return if content.blank? and new_card?
    self.errors.add :content, "'#{content}' is not a table" unless valid_table?( content )
  end

  def columns
    @table_headers
  end

  def table_row row
    @table_rows[row]
  end

  def table_column row, column
    @table_rows[row][column]
  end

  def valid_column string
    return string[1..-2] if string[0] == '"' && string[-1] == '"'
    number = 0
    return false if string == 'false'
    return true if string == 'true'
    begin
      number = Float string
    rescue ArgumentError, TypeError
      number = nil
    end
    number
  end

  def valid_table? string
    valid = true
    lines = string.split "\n"
    @table_headers =
      lines[0] =~ /[^\w\,\s]/ ? lines.shift.split(',').map(&:strip) : []
    @table_rows = lines.map do |l|
        cols = l.split(',').map(&:valid_column)
        valid = false if cols.find(&:nil?)
        cols
      end
    Kernel.Float( string )
    valid
  end
end
