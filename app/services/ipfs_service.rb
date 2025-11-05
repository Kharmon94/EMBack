class IpfsService
  attr_reader :client
  
  def initialize
    @api_key = ENV['PINATA_API_KEY']
    @api_secret = ENV['PINATA_API_SECRET']
    @gateway_url = ENV['IPFS_GATEWAY_URL'] || 'https://gateway.pinata.cloud/ipfs/'
    
    @client = Faraday.new(url: 'https://api.pinata.cloud') do |f|
      f.request :multipart
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.headers['pinata_api_key'] = @api_key
      f.headers['pinata_secret_api_key'] = @api_secret
    end
  end
  
  # Upload file to IPFS via Pinata
  def upload_file(file_path, metadata = {})
    raise "File not found: #{file_path}" unless File.exist?(file_path)
    
    payload = {
      file: Faraday::UploadIO.new(file_path, detect_mime_type(file_path)),
      pinataMetadata: metadata.to_json,
      pinataOptions: { cidVersion: 1 }.to_json
    }
    
    response = @client.post('/pinning/pinFileToIPFS', payload)
    
    if response.success?
      {
        cid: response.body['IpfsHash'],
        size: response.body['PinSize'],
        timestamp: response.body['Timestamp'],
        url: ipfs_url(response.body['IpfsHash'])
      }
    else
      raise "IPFS upload failed: #{response.body}"
    end
  rescue Faraday::Error => e
    Rails.logger.error("IPFS upload error: #{e.message}")
    raise "IPFS upload failed: #{e.message}"
  end
  
  # Upload JSON data to IPFS
  def upload_json(data, name = 'metadata.json')
    payload = {
      pinataContent: data,
      pinataMetadata: { name: name }
    }
    
    response = @client.post('/pinning/pinJSONToIPFS', payload.to_json) do |req|
      req.headers['Content-Type'] = 'application/json'
    end
    
    if response.success?
      {
        cid: response.body['IpfsHash'],
        size: response.body['PinSize'],
        timestamp: response.body['Timestamp'],
        url: ipfs_url(response.body['IpfsHash'])
      }
    else
      raise "IPFS JSON upload failed: #{response.body}"
    end
  rescue Faraday::Error => e
    Rails.logger.error("IPFS JSON upload error: #{e.message}")
    raise "IPFS JSON upload failed: #{e.message}"
  end
  
  # Unpin file from IPFS
  def unpin(cid)
    response = @client.delete("/pinning/unpin/#{cid}")
    response.success?
  rescue Faraday::Error => e
    Rails.logger.error("IPFS unpin error: #{e.message}")
    false
  end
  
  # Get pinned files list
  def list_pins(metadata_filter = {})
    params = {
      status: 'pinned',
      pageLimit: 100
    }
    params[:metadata] = metadata_filter if metadata_filter.any?
    
    response = @client.get('/data/pinList', params)
    response.body['rows'] if response.success?
  rescue Faraday::Error => e
    Rails.logger.error("IPFS list pins error: #{e.message}")
    []
  end
  
  # Generate IPFS URL
  def ipfs_url(cid)
    "#{@gateway_url}#{cid}"
  end
  
  # Generate signed/temporary URL for private content
  def signed_url(cid, expires_in = 1.hour)
    # TODO: Implement signed URL generation if using private IPFS gateway
    # For now, return public URL
    ipfs_url(cid)
  end
  
  private
  
  def detect_mime_type(file_path)
    extension = File.extname(file_path).downcase
    case extension
    when '.mp3' then 'audio/mpeg'
    when '.wav' then 'audio/wav'
    when '.flac' then 'audio/flac'
    when '.m4a' then 'audio/mp4'
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.png' then 'image/png'
    when '.gif' then 'image/gif'
    when '.webp' then 'image/webp'
    when '.mp4' then 'video/mp4'
    when '.webm' then 'video/webm'
    when '.json' then 'application/json'
    else 'application/octet-stream'
    end
  end
end

