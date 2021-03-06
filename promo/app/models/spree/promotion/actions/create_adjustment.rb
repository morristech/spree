module Spree
  class Promotion
    module Actions
      # Responsible for the creation and management of an adjustment since an
      # an adjustment uses its originator to also update its eligiblity and amount
      class CreateAdjustment < PromotionAction
        calculated_adjustments

        has_many :adjustments, :as => :originator, :dependent => :destroy

        delegate :eligible?, :to => :promotion

        before_validation :ensure_action_has_calculator

        # Creates the adjustment related to a promotion for the order passed
        # through options hash
        def perform(options = {})
          order = options[:order]
          return if order.promotion_credit_exists?(self.promotion)

          self.create_adjustment("#{I18n.t(:promotion)} (#{promotion.name})", order, order)
        end

        # Override of CalculatedAdjustments#create_adjustment so promotional
        # adjustments are added all the time. They will get their eligibility
        # set to false if the amount is 0.
        #
        # Currently an adjustment is created even when its promotion is not eligible.
        # This helps to figure out later which adjustments should be eligible
        # as the order is being updated
        #
        # BTW The order is updated (through order#update) every time an adjustment
        # is saved
        def create_adjustment(label, target, calculable, mandatory=false)
          amount = compute_amount(calculable)
          params = { :amount => amount,
                    :source => calculable,
                    :originator => self,
                    :label => label,
                    :mandatory => mandatory }
          target.adjustments.create(params, :without_protection => true)
        end

        # Ensure a negative amount which does not exceed the sum of the order's
        # item_total and ship_total
        def compute_amount(calculable)
          [(calculable.item_total + calculable.ship_total), super.to_f.abs].min * -1
        end

        private
        def ensure_action_has_calculator
          return if self.calculator
          self.calculator = Calculator::FlatPercentItemTotal.new
        end
      end
    end
  end
end
