class WatiService
  include HTTParty
  
  def initialize
    @api_token = ENV['WATI_API_TOKEN'] || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJiZTRlZDVkNS0xZmU2LTQ4ZWUtOTAxYy00OTYzMGJjNDEyNGQiLCJ1bmlxdWVfbmFtZSI6ImRldi5hdG1hbmlyYmhhcmZhcm1AZ21haWwuY29tIiwibmFtZWlkIjoiZGV2LmF0bWFuaXJiaGFyZmFybUBnbWFpbC5jb20iLCJlbWFpbCI6ImRldi5hdG1hbmlyYmhhcmZhcm1AZ21haWwuY29tIiwiYXV0aF90aW1lIjoiMDcvMzEvMjAyNSAxNDo1MTozMSIsInRlbmFudF9pZCI6IjQ3NjQyNiIsImRiX25hbWUiOiJtdC1wcm9kLVRlbmFudHMiLCJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL3dzLzIwMDgvMDYvaWRlbnRpdHkvY2xhaW1zL3JvbGUiOiJBRE1JTklTVFJBVE9SIiwiZXhwIjoyNTM0MDIzMDA4MDAsImlzcyI6IkNsYXJlX0FJIiwiYXVkIjoiQ2xhcmVfQUkifQ.kfBcCise3pV49PXxufA6rtghBVrGT9_Vo4DPHDf7MTo"
    @api_url = ENV['WATI_API_URL'] || "https://live-mt-server.wati.io/476426/api/v1"
    @tenant_id = ENV['WATI_TENANT_ID'] || "476426"
    @headers = {
      'Authorization' => "Bearer #{@api_token}",
      'Content-Type' => 'application/json'
    }
  end

  def test_connection
    response = HTTParty.get("#{@api_url}/getContacts", headers: @headers)
    if response.success?
      { success: true, message: "Connected to WATI successfully!", data: response.parsed_response }
    else
      { success: false, message: "Connection failed", error: response.body }
    end
  end

  def add_contact(whatsapp_number, name)
    url = "#{@api_url}/addContact/#{whatsapp_number}"
    body = { name: name }.to_json
    
    response = HTTParty.post(url, headers: @headers, body: body)
    parse_response(response, "Contact added")
  end

  def send_message(whatsapp_number, message)
    url = "#{@api_url}/sendSessionMessage/#{whatsapp_number}"
    body = { messageText: message }.to_json
    
    response = HTTParty.post(url, headers: @headers, body: body)
    parse_response(response, "Message sent")
  end

  def send_document(whatsapp_number, file_url, caption = "")
    url = "#{@api_url}/sendSessionFile/#{whatsapp_number}"
    body = {
      file: file_url,
      caption: caption
    }.to_json
    
    response = HTTParty.post(url, headers: @headers, body: body)
    parse_response(response, "Document sent")
  end

  private

  def parse_response(response, success_message)
    if response.success?
      { success: true, message: success_message, data: response.parsed_response }
    else
      { success: false, message: "API call failed", error: response.body, code: response.code }
    end
  end
end