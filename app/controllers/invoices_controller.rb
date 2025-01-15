class InvoicesController < ApplicationController

  # List all invoices
  def index
    @invoices = Invoice.all
    if @invoices.any?
      render json: { message: 'Success', invoices: @invoices.map { |invoice| invoice_json(invoice) } }, status: :ok
    else
      render json: { error: 'No invoices found' }, status: :not_found
    end
  end

  # Show details of a specific invoice
  def show
    render json: { message: 'Success', invoice: invoice_json(@invoice) }, status: :ok
  end

  # Create an invoice
  def create
    @invoice = Invoice.new(invoice_params)
    if @invoice.save
      # Initiate STK push
      stk_response = stkpush(@invoice.phone_number, @invoice.amount)
  
      # Log the STK Push response
      logger.info("STK Push response: #{stk_response}")
  
      render json: {
        message: 'Invoice created successfully',
        invoice: {
          id: @invoice.id,
          phone_number: @invoice.phone_number,
          amount: @invoice.amount
        },
        stk_push_response: stk_response
      }, status: :created
    else
      render json: { error: @invoice.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def invoice_params
    params.require(:invoice).permit(:phone_number, :amount)
  end  

  # Perform STK Push
  def stkpush(phone_number, amount)
    # Add logging for debugging
    Rails.logger.info "Initiating STK push to phone number: #{phone_number} for amount: #{amount}"
  
    url = "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    business_short_code = Rails.application.credentials.dig(:MPESA_SHORTCODE)
    password = Base64.strict_encode64("#{business_short_code}#{Rails.application.credentials.dig(:MPESA_PASSKEY)}#{timestamp}")
  
    payload = {
      'BusinessShortCode': business_short_code,
      'Password': password,
      'Timestamp': timestamp,
      'TransactionType': 'CustomerPayBillOnline',
      'Amount': amount.to_f,
      'PartyA': phone_number,
      'PartyB': business_short_code,
      'PhoneNumber': phone_number,
      'CallBackURL': "#{Rails.application.credentials.dig(:CALLBACK_URL)}/mpesa_callback",
      'AccountReference': SecureRandom.hex(10), # Random reference if invoice_number is unavailable
      'TransactionDesc': 'Payment for invoice'
    }.to_json
  
    headers = {
      Content_type: 'application/json',
      Authorization: "Bearer #{access_token}"
    }
  
    # Log the request payload for debugging
    Rails.logger.info "STK Push payload: #{payload}"
  
    # Perform the request and capture the response
    begin
      response = RestClient.post(url, payload, headers)
      Rails.logger.info "STK Push response: #{response.body}"
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "STK Push error: #{e.response}"
      raise "STK Push failed: #{e.response}"
    end
  end
  
  
  
  def generate_access_token_request
    @url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
    @consumer_key = Rails.application.credentials.dig(:MPESA_CONSUMER_KEY)
    @consumer_secret = Rails.application.credentials.dig(:MPESA_CONSUMER_SECRET)
    @userpass = Base64::strict_encode64("#{@consumer_key}:#{@consumer_secret}")
    headers = {
        Authorization: "Bearer #{@userpass}"
    }
    res = RestClient::Request.execute( url: @url, method: :get, headers: {
        Authorization: "Basic #{@userpass}"
    })
    res
  end

  def access_token
    res = generate_access_token_request()
    if res.code != 200
    r = generate_access_token_request()
    if res.code != 200
    raise MpesaError('Unable to generate access token')
    end
    end
    body = JSON.parse(res, { symbolize_names: true })
    token = body[:access_token]
    AccessToken.destroy_all()
    AccessToken.create!(token: token)
    token
  end
end
