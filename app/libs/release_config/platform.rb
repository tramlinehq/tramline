class ReleaseConfig::Platform < Struct.new(:platform_config)
  def distributions?
    distributions.present?
  end

  def distributions
    Distributions.new(platform_config[:distributions])
  end

  class Distributions < Struct.new(:distributions_config)
    alias_method :value, :distributions_config

    def present?
      distributions_config.present? && distributions_config.first.present?
    end

    def blank? = !present?

    def first
      Distribution.new(distributions_config.first, distributions_config)
    end

    def last
      Distribution.new(distributions_config.last, distributions_config)
    end

    def find_by_number(num)
      distributions_config.find do |distribution|
        distribution[:number] == num
      end
    end

    class Distribution < Struct.new(:current_distribution_config, :all_distributions)
      alias_method :value, :current_distribution_config

      def next
        return if all_distributions.blank?

        next_distribution = all_distributions.find do |distribution|
          distribution[:number] > number
        end

        next_distribution ? Distribution.new(next_distribution) : nil
      end

      def number
        current_distribution_config[:number]
      end

      def submission_type
        current_distribution_config[:submission_type]
      end

      def auto_promote?
        current_distribution_config[:auto_promote]
      end
    end
  end
end
