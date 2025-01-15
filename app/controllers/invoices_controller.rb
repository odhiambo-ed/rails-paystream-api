class InvoicesController < ApplicationController
  before_action :set_invoice, only: [:show, :make_payment]

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

  # Initiate payment via STK Push
  def make_payment
    phone_number = params[:phone_number]
    amount = params[:amount].to_f

    # Call the STK Push service
    response = stkpush(@invoice, phone_number, amount)

    # Save payment details
    @payment = @invoice.payments.create!(
      date: Time.now,
      amount: amount,
      mpesa_details: phone_number,
      checkoutRequestID: response['CheckoutRequestID'],
      merchantRequestID: response['MerchantRequestID'],
      status: 'pending'
    )

    render json: {
      status: { code: 200, message: 'Payment initiated successfully.' },
      data: {
        payment_id: @payment.id,
        checkoutRequestID: response['CheckoutRequestID'],
        merchantRequestID: response['MerchantRequestID']
      }
    }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # Find an invoice by ID
  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  # Format invoice JSON response
  def invoice_json(invoice)
    {
      id: invoice.id,
      invoice_number: invoice.invoice_number,
      items: invoice.items,
      total_amount: invoice.calculate_total_amount,
      tax: invoice.calculate_only_tax,
      total_with_tax: invoice.total_with_tax,
      status: invoice.status,
      due_date: invoice.due_date
    }
  end

  # Perform STK Push
  def stkpush(invoice, phone_number, amount)
    url = "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    business_short_code = Rails.application.credentials.dig(:MPESA_SHORTCODE)
    password = Base64.strict_encode64("#{business_short_code}#{Rails.application.credentials.dig(:MPESA_PASSKEY)}#{timestamp}")

    payload = {
      'BusinessShortCode': business_short_code,
      'Password': password,
      'Timestamp': timestamp,
      'TransactionType': 'CustomerPayBillOnline',
      'Amount': amount,
      'PartyA': phone_number,
      'PartyB': business_short_code,
      'PhoneNumber': phone_number,
      'CallBackURL': "#{Rails.application.credentials.dig(:CALLBACK_URL)}/mpesa_callback",
      'AccountReference': invoice.invoice_number,
      'TransactionDesc': 'Payment for invoice'
    }.to_json

    headers = {
      Content_type: 'application/json',
      Authorization: "Bearer #{access_token}"
    }

    response = RestClient.post(url, payload, headers)
    JSON.parse(response.body)
  end

  # Generate access token
  def access_token
    url = "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
    consumer_key = Rails.application.credentials.dig(:MPESA_CONSUMER_KEY)
    consumer_secret = Rails.application.credentials.dig(:MPESA_CONSUMER_SECRET)
    userpass = Base64.strict_encode64("#{consumer_key}:#{consumer_secret}")

    response = RestClient.get(url, { Authorization: "Basic #{userpass}" })
    JSON.parse(response.body)['access_token']
  end
end
