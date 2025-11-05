class VerificationService
  # Artist verification system
  # Criteria for verification:
  # 1. Minimum follower count
  # 2. Minimum streams/engagement
  # 3. Complete profile
  # 4. Active for minimum period
  # 5. No fraud flags
  
  MINIMUM_FOLLOWERS = 100
  MINIMUM_STREAMS = 1000
  MINIMUM_ACTIVE_DAYS = 30
  
  def self.evaluate_artist_for_verification(artist)
    checks = {}
    
    # Check 1: Follower count
    follower_count = Follow.where(followable: artist).count
    checks[:followers] = {
      passed: follower_count >= MINIMUM_FOLLOWERS,
      current: follower_count,
      required: MINIMUM_FOLLOWERS
    }
    
    # Check 2: Total streams
    total_streams = Stream.joins(track: { album: :artist })
                         .where(albums: { artist_id: artist.id })
                         .count
    checks[:streams] = {
      passed: total_streams >= MINIMUM_STREAMS,
      current: total_streams,
      required: MINIMUM_STREAMS
    }
    
    # Check 3: Profile completeness
    profile_complete = artist.name.present? &&
                      artist.bio.present? &&
                      artist.avatar_url.present?
    checks[:profile] = {
      passed: profile_complete,
      details: {
        has_name: artist.name.present?,
        has_bio: artist.bio.present?,
        has_avatar: artist.avatar_url.present?
      }
    }
    
    # Check 4: Active duration
    days_active = (Date.today - artist.created_at.to_date).to_i
    checks[:active_duration] = {
      passed: days_active >= MINIMUM_ACTIVE_DAYS,
      current: days_active,
      required: MINIMUM_ACTIVE_DAYS
    }
    
    # Check 5: No fraud flags
    has_fraud_flags = FraudFlag.where(flaggable: artist).where(resolved: false).exists?
    checks[:no_fraud] = {
      passed: !has_fraud_flags,
      flags_count: FraudFlag.where(flaggable: artist).where(resolved: false).count
    }
    
    # Check 6: Has released content
    has_content = artist.albums.any? && artist.tracks.any?
    checks[:has_content] = {
      passed: has_content,
      albums: artist.albums.count,
      tracks: artist.tracks.count
    }
    
    # Calculate overall eligibility
    all_passed = checks.values.all? { |check| check[:passed] }
    
    {
      eligible: all_passed,
      checks: checks,
      score: calculate_verification_score(checks)
    }
  end
  
  def self.verify_artist!(artist, verifier)
    evaluation = evaluate_artist_for_verification(artist)
    
    unless evaluation[:eligible]
      return {
        success: false,
        message: 'Artist does not meet verification criteria',
        evaluation: evaluation
      }
    end
    
    artist.update!(
      verified: true,
      verified_at: Time.current,
      verified_by_id: verifier.id
    )
    
    # Send notification to artist
    # TODO: Implement notification system
    
    {
      success: true,
      message: 'Artist verified successfully',
      evaluation: evaluation
    }
  end
  
  def self.unverify_artist!(artist, reason, admin)
    artist.update!(
      verified: false,
      verification_revoked_at: Time.current,
      verification_revoked_reason: reason,
      verification_revoked_by_id: admin.id
    )
    
    # Notify artist
    # TODO: Send notification
    
    {
      success: true,
      message: 'Verification revoked'
    }
  end
  
  # Manual verification request
  def self.request_verification(artist, additional_info = {})
    # Create verification request
    request = VerificationRequest.create!(
      artist: artist,
      status: :pending,
      additional_info: additional_info
    )
    
    # Notify admin team
    # TODO: Send notification to admins
    
    {
      success: true,
      request_id: request.id,
      message: 'Verification request submitted. Our team will review it within 48 hours.'
    }
  end
  
  private
  
  def self.calculate_verification_score(checks)
    # Calculate a score out of 100
    passed_count = checks.values.count { |check| check[:passed] }
    total_count = checks.size
    
    (passed_count.to_f / total_count * 100).round
  end
end

