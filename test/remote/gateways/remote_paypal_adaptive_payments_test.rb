require 'test_helper'

class RemotePaypalAdaptivePaymentTest < Test::Unit::TestCase
  
  def setup
    @gateway = PaypalAdaptivePaymentGateway.new(fixtures(:paypal_signature))

    @amount = 100

    @receivers = [@amount, 'paymen_1245697080_per@teachstreet.com']

    @pay_options = {:sender_email => 'paymen_1250541923_biz@teachstreet.com', :remote_ip => '10.0.0.1', :return_url => 'http://example.com/return', :cancel_url => 'http://example.com/cancel'}

    @valid_token = "AP-2JU68453W94563608"
    @invalid_token = "INVALID"
  end

  def test_successful_pay
    assert response = @gateway.pay(@receivers, @pay_options)
    assert_success response
    assert pay_url = @gateway.redirect_url_for(response.authorization)
    assert response.test?
  end

  def test_successful_payment_details
    assert response = @gateway.payment_details(@valid_token)
    assert_success response
    assert response.test?
  end

  def test_invalid_payment_details
    assert response = @gateway.payment_details(@invalid_token)
    assert_failure response
    assert response.test?
    assert_equal 'Invalid pay key INVALID', response.message
  end

  def test_successful_pay_and_refund
    assert pay_response = @gateway.pay(@receivers, @pay_options)
    assert_success pay_response
    assert pay_response.test?
    assert pay_url = @gateway.redirect_url_for(pay_response.authorization)
    assert refund_response = @gateway.refund(:pay_key => pay_response.authorization)
    assert_success refund_response
    assert refund_response.test?
  end
  
  def test_invalid_login
    gateway = PaypalAdaptivePaymentGateway.new(
                :login => '',
                :password => '',
                :signature => '',
                :app_id => ''
              )
    assert response = gateway.pay(@receivers, @pay_options)
    assert_failure response
    assert_equal 'Username/Password is incorrect', response.message
  end
end
