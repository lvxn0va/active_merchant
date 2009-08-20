module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalPaymentDetailsResponse < Response
      def action_type
        @params['action_type']
      end 
      
      def cancel_url
        @params['cancel_url']
      end

      def currency_code
        @params['currency_code']
      end

      def fees_payer
        @params['fees_payer']
      end

      def ipn_notification_url
        @params['ipn_notification_url']
      end

      def memo
        @params['memo']
      end

      def payment_list
        @params['payment_list']
      end

      def return_url
        @params['return_url']
      end

      def ipn_notification_url
        @params['ipn_notifcation_url']
      end

      def sender_email
        @params['sender_email']
      end

      def status
        @params['status']
      end

      def tracking_id
        @params['tracking_id']
      end

      def fees_payer
        @params['fees_payer']
      end

      def reverse_all_parallel_payments_on_error
        @params['reverse_all_parallel_payments_on_error'] == 'true'
      end

      def log_default_shipping_address
        @params['log_default_shipping_address'] == 'true'
      end

      def preapproval_key
        @params['preapproval_key']
      end

    end
  end
end
