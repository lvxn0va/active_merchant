require File.dirname(__FILE__) + '/paypal/paypal_payment_details_response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalAdaptivePaymentGateway < Gateway
      include PaypalExpressCommon

      TEST_URL = 'https://svcs.sandbox.paypal.com/AdaptivePayments'
      LIVE_URL = 'https://svcs.paypal.com/AdaptivePayments'

      self.test_redirect_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd='
      self.live_redirect_url = 'https://www.paypal.com/cgi-bin/webscr?cmd='


      API_VERSION = '1.1.0'
      
      SUCCESS_CODES = [ 'Success', 'SuccessWithWarning' ]

      PAYMENT_PERIODS = ['DAILY', 'WEEKLY', 'BIWEEKLY', 'SEMIMONTHLY', 'MONTHLY', 'ANNUALLY']

      FEES_PAYER_OPTIONS = ['SENDER', 'PRIMARYRECEIVER', 'EACHRECEIVER', 'SECONDARYONLY']
 
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://x.com/'
      
      # The name of the gateway
      self.display_name = 'Paypal Adaptive Payments'

      self.default_currency = 'USD'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  

      # Pay money to one or more recievers
      #
      #   gateway.pay 1000, 'bob@example.com',
      #     :sender_email => "john@example.com", :return_url => "http://example.com/return", :cancel_url => "http://example.com/cancel"
      #
      #   gateway.pay [1000, 'fred@example.com'],
      #     [2450, 'wilma@example.com', :primary => true],
      #     [2000, 'barney@example.com'],
      #     :sender_email => "john@example.com", :return_url => "http://example.com/return", :cancel_url => "http://example.com/cancel"
      #
      def pay(*args)
        commit('Pay', build_pay_request(*args))
      end

      def payment_details(token, options = {})
        commit('PaymentDetails', build_payment_details_request(token, options))
      end

      def preapproval(options)
        requires!(options, :return_url, :cancel_url, :ending_date)
        commit('Preapproval', build_preapproval_request(options))
      end

      def preapproval_details(token, options = {})
        commit('PreapprovalDetails', build_preapproval_details_request(token, options))
      end

      def refund(*args)
        commit('Refund', build_refund_request(*args))
      end

      def redirect_url_for(token, options = {})
        if token =~ /AP\-/
          "#{redirect_url}_ap-payment&payKey=#{token}"
        elsif token =~ /PA\-/
          "#{redirect_url}_ap-preapproval&preapprovalkey=#{token}"
        end
      end

      private                       

      def endpoint_url
        test? ? TEST_URL : LIVE_URL
      end

      def build_pay_request(*args)
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        receivers = args.first.is_a?(Array) ? args : [args]

        requires!(default_options, :return_url, :cancel_url)

        currency = options[:currency] || currency(receivers.first[0])

        xml = Builder::XmlMarkup.new
        add_client_details(xml, default_options)
        xml.tag! 'actionType', 'PAY'
        xml.tag! 'feesPayer', fees_payer_option(default_options[:fees_payer]) unless default_options[:fees_payer].blank?
        xml.tag! 'cancelUrl', default_options[:cancel_url]
        xml.tag! 'currencyCode', currency
        xml.tag! 'ipnNotificationUrl', default_options[:ipn_notification_url] unless default_options[:ipn_notification_url].blank?
        xml.tag! 'logDefaultShippingAddress', true if default_options[:log_default_shipping_address]
        xml.tag! 'memo', default_options[:memo] unless default_options[:memo].blank?
        xml.tag! 'pin', default_options[:pin] unless default_options[:pin].blank?
        xml.tag! 'preapprovalKey', default_options[:preapproval_key] unless default_options[:preapproval_key].blank?
        xml.tag! 'receiverList' do
          receivers.each do |money, receiver, options|
            options ||= default_options
            xml.tag! 'receiver' do
              xml.tag! 'amount', amount(money)
              xml.tag! 'email', receiver
              xml.tag! 'primary', true if options[:primary]
            end
          end
        end
        xml.tag! 'reverseAllParallelPaymentsOnError', true if default_options[:reverse_all_parallel_payments_on_error]
        xml.tag! 'senderEmail', default_options[:sender_email] unless default_options[:sender_email].blank?
        xml.tag! 'returnUrl', default_options[:return_url]
        xml.tag! 'trackingId', default_options[:tracking_id] unless default_options[:tracking_id].blank?
        xml.target!
      end

      def build_payment_details_request(token, options)
        xml = Builder::XmlMarkup.new
        add_client_details(xml, options)
        xml.tag! 'payKey', token unless token.blank?
        xml.tag! 'transactionId', options[:transaction_id] unless options[:transaction_id].blank?
        xml.tag! 'trackingId', options[:tracking_id] unless options[:tracking_id].blank?
        xml.target!
      end

      def build_preapproval_request(options)
        xml = Builder::XmlMarkup.new
        add_client_details(xml, options)
        xml.tag! 'cancelUrl', options[:cancel_url]
        xml.tag! 'currencyCode', options[:currency] || self.default_currency
        xml.tag! 'dateOfMonth', options[:date_of_month] unless options[:date_of_month].blank?
        xml.tag! 'dayOfWeek', day_of_week(options[:date_of_week]) unless options[:date_of_week].blank?
        xml.tag! 'endingDate', options[:ending_date]
        xml.tag! 'maxAmountPerPayment', money(options[:max_amount_per_payment]) unless options[:max_amount_per_payment].blank?
        xml.tag! 'maxNumberOfPayments', options[:max_number_of_payments] unless options[:max_number_of_payments].blank?
        xml.tag! 'maxNumberOfPaymentsPerPeriod', options[:max_number_of_payments_per_period] unless options[:max_number_of_payments_per_period].blank?
        xml.tag! 'paymentPeriod', payment_period(options[:payment_period]) unless options[:payment_period].blank?
        xml.tag! 'senderEmail', options[:sender_email] unless options[:sender_email].blank?
        xml.tag! 'returnUrl', options[:return_url]
        xml.target!
      end

      def build_preapproval_details_request(token, options)
        xml = Builder::XmlMarkup.new
        add_client_details(xml, options)
        xml.tag! 'preapprovalKey', token
        xml.target!
      end

      def build_refund_request(*args)
        default_options = args.last.is_a?(Hash) ? args.pop : {}
        receivers = if args.first
                     args.first.is_a?(Array) ? args : [args]
                   else
                     []
                   end

        currency = options[:currency] || (currency(receivers.first[0]) unless receivers.empty?) || self.default_currency

        xml = Builder::XmlMarkup.new
        add_client_details(xml, default_options)
        xml.tag! 'currencyCode', currency
        xml.tag! 'payKey', default_options[:pay_key] unless default_options[:pay_key].blank?
        xml.tag! 'trackingId', default_options[:tracking_id] unless default_options[:tracking_id].blank?
        xml.tag! 'transactionId', default_options[:transaction_id] unless default_options[:transaction_id].blank?
        xml.tag! 'receivers' do
          receivers.each do |money, receiver, options|
            options ||= default_options
            xml.tag! 'receiver' do
              xml.tag! 'amount', amount(money)
              xml.tag! 'email', receiver
              xml.tag! 'primary', true if options[:primary]
            end
          end
        end
        xml.target!
      end

      def headers
        {
          "X-PAYPAL-REQUEST-DATA-FORMAT" => "XML",
          "X-PAYPAL-RESPONSE-DATA-FORMAT" => "JSON",
          "X-PAYPAL-SECURITY-USERID" => @options[:login],
          "X-PAYPAL-SECURITY-PASSWORD" => @options[:password],
          "X-PAYPAL-SECURITY-SIGNATURE" => @options[:signature],
          "X-PAYPAL-SERVICE-VERSION" => API_VERSION,
          "X-PAYPAL-APPLICATION-ID" => self.application_id
        }
      end

      def day_of_week(d)
        if d
          if Date::DAYNAMES.include?(d.to_s.upcase)
            d.to_s.upcase
          elsif Date::DAYNAMES[d.to_i]
            Date::DAYNAMES[d.to_i].upcase
          end
        end
      end

      def payment_period(p)
        if p && PAYMENT_PERIODS.include?(p.to_s.upcase)
          p.to_s.upcase
        end
      end

      def fees_payer_option(o)
        if o & FEES_PAYER_OPTIONS.include?(o.to_s.gsub('_', '').upcase)
          o.to_s.gsub('_', '').upcase
        end
      end

      def add_client_details(xml, options)
        xml.clientDetails do
          xml.ipAddress options[:remote_ip]
          xml.deviceId options[:device_id] unless options[:device_id].blank?
          xml.applicationId self.application_id
          xml.partnerName options[:partner_name] unless options[:partner_name].blank?
        end
      end

      def build_url(action)
        "#{endpoint_url}/#{action}"
      end

      def successful?(response)
        SUCCESS_CODES.include?(response[:ack])
      end

      def message_from(response)
        response[:message] || response[:status] || response[:payment_exec_status] || response[:ack]
      end

      def authorization_from(response)
        response[:pay_key] || response[:preapproval_key]
      end

      def build_response(action, success, message, response, options = {})
         case action
         when 'PaymentDetails'
           PaypalPaymentDetailsResponse.new(success, message, response, options)
         else
           Response.new(success, message, response, options)
         end
      end

      def build_request(action, body)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! "#{action}Request" do
          xml.tag! 'requestEnvelope' do
            xml.tag! 'detailLevel', 'ReturnAll'
          end
          xml << body
        end
        xml.target!
      end

      def parse(action, json)
        result = ActiveSupport::JSON.decode(json)
        response = {}
        result.each do |k,v|
          response[k.underscore.to_sym] = v if v.is_a?(String)
        end
        if result['responseEnvelope']
          result['responseEnvelope'].each do |k,v|
            response[k.underscore.to_sym] = v if v.is_a?(String)
          end
        end
        if result['paymentInfoList']
          response[:payment_list] = result['paymentInfoList']['paymentInfo']
        end
        if result['error']
          response[:message] = result['error'].collect{|e| e['message'] }.uniq.join('. ')
          response[:error_codes] = result['error'].collect{|e| e['errorId'] }.uniq.join(', ')
        end
        response
      end

      def commit(action, request)
        response = parse(action, ssl_post(build_url(action), build_request(action,request), headers))
        build_response(action, successful?(response), message_from(response), response, 
          :test => test?,
    	    :authorization => authorization_from(response)
        )
      end

    end
  end
end

