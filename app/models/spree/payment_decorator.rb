Spree::Payment.class_eval do
  self.state_machine.before_transition to: :completed, do: :avalara_finalize
  self.state_machine.after_transition to: :void, do: :cancel_avalara

  def avalara_tax_enabled?
    Spree::Config.avatax_tax_calculation
  end

  def cancel_avalara
    order.avalara_transaction.cancel_order unless order.avalara_transaction.nil?
  end

  def avalara_finalize
    return unless avalara_tax_enabled?

    #if self.amount != order.total
    #  self.update_attributes(amount: order.total)
    #end
    begin
      if (self.state == "completed" && order.payments.where(state: "completed").sum(&:amount) >= order.total)
        order.avalara_capture_finalize
      elsif (self.state == "processing" && (self.amount + order.payments.where(state: "completed").sum(&:amount)) >= order.total)
        order.avalara_capture_finalize
      else
        Rails.logger.info("Partial payment captured: waiting to finalize avatax transaction")
      end
    rescue Avalara::CalculationError => e
      Rails.logger.warn("Unable to calculate tax on order #{order.number}")
    end
  end
end
