module Ordinalize
  def self.ordinalize(value)
    case value.to_s
    when /^[0-9]*[1][0-9]$/
      suffix = "th"
    when /^[0-9]*[1]$/
      suffix = "st"
    when /^[0-9]*[2]$/
      suffix = "nd"
    when /^[0-9]*[3]$/
      suffix = "rd"
    else
      suffix = "th"
    end

    return value.to_s + suffix
  end
end
