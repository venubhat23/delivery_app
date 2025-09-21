class Api::InstagramAnalyticsController < Api::BaseController
  skip_before_action :require_login

  def post_details
    post_id = params[:id]

    if post_id.blank?
      render json: {
        success: false,
        message: "Post ID is required"
      }, status: :bad_request
      return
    end

    # Mock data - replace with actual data source
    post_data = get_post_by_id(post_id)

    if post_data.nil?
      render json: {
        success: false,
        message: "Post not found"
      }, status: :not_found
      return
    end

    render json: {
      success: true,
      message: "Post details retrieved successfully",
      data: post_data
    }
  end

  private

  def get_post_by_id(post_id)
    # This is mock data based on your example
    # Replace this with actual data retrieval logic from your data source

    posts_data = {
      "18052452383555406" => {
        "id" => "18052452383555406",
        "type" => "IMAGE",
        "url" => "https://www.instagram.com/p/DOjQSGnD9po/",
        "media_url" => nil,
        "thumbnail_url" => nil,
        "caption" => "tets",
        "full_caption" => "tets",
        "timestamp" => "2025-09-13T17:29:57+0000",
        "likes" => 0,
        "comments" => 0,
        "reach" => 0,
        "impressions" => 0,
        "saved" => 0,
        "shares" => 0,
        "clicks" => 0,
        "engagement" => 0,
        "video_views" => 0,
        "plays" => 0,
        "is_shared_to_feed" => false,
        "shortcode" => nil,
        "media_product_type" => nil,
        "children" => nil,
        "engagement_rate" => 0,
        "reach_rate" => 0,
        "save_rate" => 0,
        "performance_score" => 0,
        "has_hashtags" => false,
        "hashtag_count" => 0,
        "has_mentions" => false,
        "mention_count" => 0,
        "caption_length" => 4,
        "days_since_posted" => 7,
        "posted_time" => "17:29",
        "posted_day" => "Saturday"
      },
      "17960410367834621" => {
        "id" => "17960410367834621",
        "type" => "IMAGE",
        "url" => "https://www.instagram.com/p/DOjOtIhD4CI/",
        "media_url" => nil,
        "thumbnail_url" => nil,
        "caption" => "sa",
        "full_caption" => "sa",
        "timestamp" => "2025-09-13T17:16:10+0000",
        "likes" => 0,
        "comments" => 0,
        "reach" => 0,
        "impressions" => 0,
        "saved" => 0,
        "shares" => 0,
        "clicks" => 0,
        "engagement" => 0,
        "video_views" => 0,
        "plays" => 0,
        "is_shared_to_feed" => false,
        "shortcode" => nil,
        "media_product_type" => nil,
        "children" => nil,
        "engagement_rate" => 0,
        "reach_rate" => 0,
        "save_rate" => 0,
        "performance_score" => 0,
        "has_hashtags" => false,
        "hashtag_count" => 0,
        "has_mentions" => false,
        "mention_count" => 0,
        "caption_length" => 2,
        "days_since_posted" => 7,
        "posted_time" => "17:16",
        "posted_day" => "Saturday"
      }
    }

    posts_data[post_id]
  end
end