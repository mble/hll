require "./hll/*"
require "math"
require "digest"

module Hll
  struct Log
    property position : Int64,
      alpha : Float64,
      counter_precision : Int64,
      counter : Array(Int64)

    def initialize(error_rate = 0.04)
      raise "Error rate must be between 0 and 1" unless (0.0..1.0).includes? error_rate

      @position = Math.log((1.04 / error_rate) ** 2, 2).ceil.to_i64
      @alpha = get_alpha(@position)
      @counter_precision = 1.to_i64 << @position
      @counter = Array(Int64).new(@counter_precision, 0.to_i64)
    end

    def add(value)
      x = Digest::SHA1.hexdigest(
        value.encode("UTF-8")
      )[0...16].to_u64(16)
      j = x & (@counter_precision - 1)
      w = x >> @position

      @counter[j] = [@counter[j], get_rho(w.to_i64, 64 - @position)].max.to_i64
    end

    def cardinality
      v = @counter.count(0)
      if v > 0
        estimate = @counter_precision * Math.log(@counter_precision / v.to_f)
        if estimate <= get_threshold(@position)
          return estimate
        else
          return enhanced_precision_estimate
        end
      else
        enhanced_precision_estimate
      end
    end

    def get_alpha(position)
      unless (4..16).includes? position
        raise "position = %d should be in range [4 : 16]" % position
      end

      case position
      when 4
        0.673
      when 5
        0.697
      when 6
        0.709
      else
        0.7213 / (1.0 + 1.079 / (1 << position))
      end
    end

    def get_rho(w : Int64, max_width)
      (max_width - bit_length(w) + 1).tap do |rho|
        raise "w overflow" if rho <= 0
      end
    end

    private def enhanced_precision_estimate
      estimate = @alpha * (@counter_precision ** 2).to_f / @counter.map { |x| 2.0 ** (0 - x) }.sum
      if estimate <= 5 * @counter_precision
        return (estimate - estimate_bias(estimate, @position))
      else
        estimate
      end
    end

    private def get_nearest_neighbours(raw_estimate, estimate_vector)
      estimate_vector.map_with_index { |val, idx|
        [idx, ((raw_estimate - val.to_f) ** 2)]
      }.sort_by { |a|
        a.last
      }.map { |a|
        a[0].to_i
      }[0...6]
    end

    private def estimate_bias(raw_estimate, position)
      position_vector = position - 4
      estimate_vector = Bias::RAW_ESTIMATE_DATA[position_vector]
      bias_vec = Bias::BIAS_DATA[position_vector]
      nearest_neighours = get_nearest_neighbours(raw_estimate, estimate_vector)
      nearest_neighours.map { |n| bias_vec[n].to_f }.sum / nearest_neighours.size
    end

    private def bit_length(w)
      return 0 if w == 0
      w.to_s(2).gsub('-', '\'').split(//).size
    end

    private def get_threshold(position)
      Bias::THRESHOLD_DATA[position - 4]
    end
  end
end
