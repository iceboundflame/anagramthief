require 'singleton'

class BotPersonalities
  include Singleton

  def get(i)
    @personalities[i]
  end
  def all_titles
    @personalities.map {|p| p[:title]}
  end

  private
  def initialize
    @personalities = []
    INIT_DATA.each_line do |line|
      line.chomp!
      next if line.empty?

      title, max_rank, max_steal_len, max_word_len, delay_ms_mean, delay_ms_stdev,
        delay_ms_per_char, delay_ms_per_kcost = line.split("|")

      @personalities.push({
        :title => title,
        :settings => {
          :max_rank => max_rank.to_i,
          :max_steal_len => max_steal_len.to_i,
          :max_word_len => max_word_len.to_i,
          :delay_ms_mean => delay_ms_mean.to_i,
          :delay_ms_stdev => delay_ms_stdev.to_i,
          :delay_ms_per_char => delay_ms_per_char.to_i,
          :delay_ms_per_kcost => delay_ms_per_kcost.to_i,
        },
      })
    end
  end

  INIT_DATA = <<EOF
Baby|10000|3|6|5000|2000|1500|0
Petty Thief|30000|7|12|4000|2000|1000|0
Pickpocket|30000|11|15|2000|2000|1000|0
Shoplifter|30000|0|0|-1000|1000|1000|0
Burglar|30000|0|0|-500|1000|750|0
Heistmaster|30000|0|0|250|1000|400|0
EOF
end
