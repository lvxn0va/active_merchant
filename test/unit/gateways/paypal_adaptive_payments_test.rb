require 'test_helper'

class PaypalAdaptivePaymentTest < Test::Unit::TestCase
  def setup
    @gateway = PaypalAdaptivePaymentGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :signature => 'signature',
                 :app_id => 'app_id'
               )

    @amount = 100

    @receivers = [@amount, 'receiver@example.com']
    @pay_options = {:sender_email => 'sender@example.com',
                    :remote_ip => '10.0.0.1',
                    :return_url => 'http://example.com/return',
                    :cancel_url => 'http://example.com/cancel'}

    @preapproval_options = {:sender_email => 'sender@example.com', 
                            :return_url => 'http://example.com/return',
                            :cancel_url => 'http://example.com/cancel',
                            :ending_date => (Time.now + 3.months), 
                            :payment_period => :weekly,
                            :day_of_week => :monday,
                            :remote_ip => '10.0.0.1'}

    @refund_options_without_ids = {:remote_ip => '10.0.0.1'}

    @refund_options_with_ids = {:tracking_id => '12325231231231',
                                :pay_key => 'AP-13R096665X681474E',
                                :transaction_id => '123123132133',
                                :remote_ip => '10.0.0.1'}

    @pay_key = "AP-2JU68453W94563608"
    @preapproval_key = "PA-13R096665X681474E"
  end

  def test_successful_pay
    @gateway.expects(:ssl_post).returns(successful_pay_response_json)
    assert response = @gateway.pay(@receivers, @pay_options)
    assert_success response
    assert_equal 'AP-13R096665X681474E', response.authorization
    assert_equal 'COMPLETED', response.message
    assert_equal 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_ap-payment&payKey=AP-13R096665X681474E', @gateway.redirect_url_for(response.authorization)
    assert response.test?
  end
  
  def test_unsuccessful_pay
    @gateway.expects(:ssl_post).returns(failed_pay_response_json)
    
    assert response = @gateway.pay(@receivers, @pay_options)
    assert_failure response
    assert_equal 'Invalid request: amount cannot be negative', response.message
    assert response.test?
  end

  def test_successful_payment_details
    @gateway.expects(:ssl_post).returns(successful_payment_details_response_json)
    assert response = @gateway.payment_details(@pay_key)
    assert_success response
    assert response.is_a?(PaypalPaymentDetailsResponse)
    assert_equal @pay_key, response.authorization
    assert_equal 'PAY', response.action_type
    assert_equal 'http://www.YourCancelURL.com', response.cancel_url
    assert response.test?
  end

  def test_successful_preapproval
    @gateway.expects(:ssl_post).returns(successful_preapproval_response_json)
    assert response = @gateway.preapproval(@preapproval_options)
    assert_success response

    assert_equal 'PA-13R096665X681474E', response.authorization
    assert_equal 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_ap-preapproval&preapprovalkey=PA-13R096665X681474E', @gateway.redirect_url_for(response.authorization)
    assert response.test?
  end

  def test_successful_preapproval_details
    @gateway.expects(:ssl_post).returns(successful_preapproval_details_response_json)
    assert response = @gateway.payment_details(@preapproval_key)
    assert_success response
    assert_equal @preapproval_key, response.authorization
    assert_equal 'ACTIVE', response.message
    assert response.test?
  end
  
  def test_successful_refund_with_receivers
    @gateway.expects(:ssl_post).returns(successful_refund_response_json)
    assert response = @gateway.refund(@recievers, @refund_options_without_ids)
    assert_success response
    assert response.test?
  end
  
  def test_successful_refund_with_ids
    @gateway.expects(:ssl_post).returns(successful_refund_response_json)
    assert response = @gateway.refund(@refund_options_with_ids)
    assert_success response
    assert response.test?
  end

  private
  
  def successful_pay_response_json
    <<-RESPONSE
  {"responseEnvelope":{"timestamp":"2009-08-19T20:06:37.422-07:00","ack":"Success","correlationId":"4831666d56952","build":"1011828"},"payKey":"AP-13R096665X681474E","paymentExecStatus":"COMPLETED"}
    RESPONSE
  end

  def successful_payment_details_response_json
    <<-RESPONSE
    {"responseEnvelope":{"timestamp":"2009-08-20T09:37:18.038-07:00","ack":"Success","correlationId":"42e4ea59ba24d","build":"1011828"},"cancelUrl":"http://www.YourCancelURL.com","currencyCode":"USD","logDefaultShippingAddress":"false","paymentInfoList":{"paymentInfo":[{"transactionId":"41X75143SU925680B","transactionStatus":"COMPLETED","receiver":{"amount":"2.00","email":"paymen_1245697080_per@teachstreet.com","primary":"false"},"refundedAmount":"0.00","pendingRefund":"false"}]},"returnUrl":"http://www.YourReturnURL.com","senderEmail":"paymen_1250541923_biz@teachstreet.com","status":"COMPLETED","payKey":"AP-2JU68453W94563608","actionType":"PAY","feesPayer":"EACHRECEIVER","reverseAllParallelPaymentsOnError":"false"}
    RESPONSE
  end

  def successful_preapproval_response_json
    <<-RESPONSE
  {"responseEnvelope":{"timestamp":"2009-08-19T20:06:37.422-07:00","ack":"Success","correlationId":"4831666d56952","build":"1011828"},"preapprovalKey":"PA-13R096665X681474E"}
    RESPONSE
  end

  #TODO - need real result
  def successful_preapproval_details_response_json
    <<-RESPONSE
  {"responseEnvelope":{"timestamp":"2009-08-19T20:06:37.422-07:00","ack":"Success","correlationId":"4831666d56952","build":"1011828"},"preapprovalKey":"PA-13R096665X681474E", "status":"ACTIVE"}
    RESPONSE
  end

  def successful_refund_response_json
    <<-RESPONSE
  {"responseEnvelope":{"timestamp":"2009-08-20T10:41:32.88-07:00","ack":"Success","correlationId":"d7e2312267530","build":"1011828"},"currencyCode":"USD","refundInfoList":{"refundInfo":[{"receiver":{"amount":"1.00","email":"receiver@example.com"},"refundStatus":"NOT_PAID"}]}}
    RESPONSE
  end

  def failed_pay_response_json
    <<-RESPONSE
      {"responseEnvelope":{"timestamp":"2009-08-19T20:07:12.272-07:00","ack":"Failure","correlationId":"fa8f6df75f7c6","build":"1011828"},"error":[{"errorId":"580001","domain":"PLATFORM","severity":"Error","category":"Application","message":"Invalid request: amount cannot be negative"}]}
    RESPONSE
  end
end
