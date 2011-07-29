require 'redis'
require 'pp'
require 'set'


def parse_list(blob)
  parts = blob.scan /(\w+) \+?  (?: \s+ -> \s+ \[ ( [^\]]+ ) \])?/x

#    (\w+) \+?     # word, with optional plus
#    (?:           # optional segment
#      \s+ -> \s+  # arrow
#      \[
#        ( [^]]+ ) # bracket contents
#      \]
#    )?

    #return words
  result = []
  parts.each{|word|
    if word[1]
      result << [word[0], parse_list(word[1])]
    else
      result << word[0]
    end
  }
  result
end


file = ARGV[0]
rhash = ARGV[1] || '2+2lemma'

puts "Reading #{file} => redis hash '#{rhash}'"
puts "Enter to continue, ^C to abort"
STDIN.gets

@r = Redis.new

@r.del rhash

@hash = Hash.new { |hash, key| hash[key] = Set.new }

#PP.pp parse_list '    sounded, sounder -> [sounder, sounder2, sounder3+], soundest, sounding -> [sounding], soundless, soundlessly, soundly, soundness, sounds'
#exit

i = 0
headword = nil
IO.foreach(file) { |line|
  print '.' if (i += 1) % 1000 == 0

  line.chomp!
  if line =~ /^\s+(.*)$/
    unless headword
      puts "\nLine #{i} without headword: '#{line}'"
      next
    end

    parse_list($1).each {|word|
      inflection = word
      if word.kind_of?(Array)
        inflection = word[0]
        word[1].each {|alt_headword|
          @hash[inflection] << alt_headword    # FIXME???? @hash[headword] = ref;? WTF?
        }
      end
      @hash[inflection] << headword
    }

    headword = nil
  else
    headwords = parse_list(line)[0]

    if headwords.kind_of?(Array)
      headword = headwords[0]
      headwords[1].each {|ref|
        @hash[ref] << headword    # FIXME???? @hash[headword] = ref;? WTF?
      }
    else
      headword = headwords
    end
    @hash[headword] << headword
  end
}

i = 0
data = @hash.map {|inflection, headword_set|
  print '+' if (i += 1) % 1000 == 0

  set_str = headword_set.to_a.join(',')
  #puts "#{rhash}: #{inflection} => #{set_str}"

  #[inflection, set_str]
  @r.hset rhash, inflection, set_str
}.flatten
#@r.hmset rhash, *data
