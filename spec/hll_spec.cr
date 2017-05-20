require "./spec_helper"
require "secure_random"

describe Hll::Log do
  describe "#new" do
    it "correctly implements a Log with correct values" do
      log = Hll::Log.new(0.05)

      log.position.should eq 9
      log.alpha.should eq 0.7197831133217303
      log.counter_precision.should eq 512
      log.counter.size.should eq 512
    end
  end

  describe "#add" do
    it "adds an item to the Log" do
      log = Hll::Log.new(0.05)

      (0...10).each { |i| log.add(i.to_s) }
      expected_set = log.counter.map_with_index { |val, idx|
        [idx, val] if val > 0
      }.compact

      expected_set.should eq [
        [1, 1],
        [41, 1],
        [44, 1],
        [76, 3],
        [103, 4],
        [182, 1],
        [442, 2],
        [464, 5],
        [497, 1],
        [506, 1],
      ]
    end
  end

  describe "#cardinality" do
    it "calculates cardinality correctly" do
      cardinality_list = [1, 5, 10, 30, 60, 200, 1000, 10000]
      n = 30
      error_rate = 0.05

      cardinality_list.each do |cardinality|
        s = 0.0
        n.times do
          log = Hll::Log.new(error_rate)

          cardinality.times do
            log.add(SecureRandom.random_bytes(20).to_s)
          end

          s += log.cardinality
        end

        z = (s.to_f / n - cardinality) / (error_rate * cardinality / Math.sqrt(n))
        z.should be > -3
        z.should be < 3
      end
    end
  end

  describe "#get_alpha" do
    it "correctly gets alpha for p in range" do
      alphas = (4...10).map { |p| Hll::Log.new.get_alpha(p) }
      alphas.should eq [
        0.673,
        0.697,
        0.709,
        0.7152704932638152,
        0.7182725932495458,
        0.7197831133217303,
      ]
    end

    it "raises an error if p is out of range" do
      expect_raises { Hll::Log.new.get_alpha(1) }
      expect_raises { Hll::Log.new.get_alpha(17) }
    end
  end

  describe "#get_rho" do
    it "correctly gets rho for w and a given maximum width" do
      Hll::Log.new.get_rho(0_i64, 32).should eq 33
      Hll::Log.new.get_rho(1_i64, 32).should eq 32
      Hll::Log.new.get_rho(2_i64, 32).should eq 31
      Hll::Log.new.get_rho(3_i64, 32).should eq 31
      Hll::Log.new.get_rho(4_i64, 32).should eq 30
      Hll::Log.new.get_rho(5_i64, 32).should eq 30
      Hll::Log.new.get_rho(6_i64, 32).should eq 30
      Hll::Log.new.get_rho(7_i64, 32).should eq 30
      Hll::Log.new.get_rho(1_i64 << 31, 32).should eq 1
    end

    it "raises an error if rho <= 0" do
      expect_raises { Hll::Log.new.get_rho(1_i64 << 32, 32) }
      expect_raises { Hll::Log.new.get_rho(1_i64 << 33, 32) }
    end
  end
end

describe Hll::Bias do
  it "has the right bias data" do
    Hll::Bias::THRESHOLD_DATA.size.should eq(18 - 3)
  end
end
