class SolanaService
  attr_reader :connection
  
  def initialize
    @rpc_url = ENV['SOLANA_RPC_URL'] || 'https://api.mainnet-beta.solana.com'
    @connection = Faraday.new(url: @rpc_url) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end
  
  # Verify a signed message from a Solana wallet
  def verify_signature(wallet_address, message, signature)
    # TODO: Implement actual signature verification using ed25519
    # For now, return true for development
    # In production, use: ed25519-ruby gem or call Solana RPC
    Rails.logger.warn("Solana signature verification not implemented - accepting all signatures")
    true
  end
  
  # Get token account balance
  def get_token_balance(wallet_address, mint_address)
    response = rpc_call('getTokenAccountsByOwner', [
      wallet_address,
      { mint: mint_address },
      { encoding: 'jsonParsed' }
    ])
    
    return 0 unless response['result']['value'].any?
    
    token_account = response['result']['value'].first
    token_account.dig('account', 'data', 'parsed', 'info', 'tokenAmount', 'uiAmount') || 0
  end
  
  # Get SOL balance
  def get_sol_balance(wallet_address)
    response = rpc_call('getBalance', [wallet_address])
    lamports = response.dig('result', 'value') || 0
    lamports / 1_000_000_000.0 # Convert lamports to SOL
  end
  
  # Get transaction details
  def get_transaction(signature)
    response = rpc_call('getTransaction', [
      signature,
      { encoding: 'jsonParsed' }
    ])
    response['result']
  end
  
  # Verify transaction exists and is confirmed
  def verify_transaction(signature)
    transaction = get_transaction(signature)
    transaction && transaction['meta'] && transaction['meta']['err'].nil?
  end
  
  # Get recent blockhash
  def get_recent_blockhash
    response = rpc_call('getLatestBlockhash', [])
    response.dig('result', 'value', 'blockhash')
  end
  
  # Send transaction
  def send_transaction(signed_transaction)
    response = rpc_call('sendTransaction', [
      signed_transaction,
      { encoding: 'base64' }
    ])
    response['result'] # Returns transaction signature
  end
  
  # Get account info
  def get_account_info(pubkey)
    response = rpc_call('getAccountInfo', [
      pubkey,
      { encoding: 'jsonParsed' }
    ])
    response.dig('result', 'value')
  end
  
  private
  
  def rpc_call(method, params = [])
    response = @connection.post do |req|
      req.body = {
        jsonrpc: '2.0',
        id: 1,
        method: method,
        params: params
      }
    end
    
    response.body
  rescue Faraday::Error => e
    Rails.logger.error("Solana RPC Error: #{e.message}")
    { 'error' => e.message }
  end
end

