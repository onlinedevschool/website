require "application_responder"

class ApplicationController < ActionController::Base
  self.responder = ApplicationResponder
  respond_to :html

  before_action :set_site_social_vars

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def set_site_social_vars
    @site_name = "ODS - OnlineDevSchool"
    @site_title = "Welcome to the OnlineDevSchool (ODS) website. Learn to code, change your life!"
    @site_url = "https://oninedevschool.com"
    @site_share_image = ActionController::Base.helpers.asset_url("ods-lg-sq.png")
    @site_description = <<-DESCRIPTION.strip_heredoc
    The OnlineDevSchool has one mission. To teach you the skills you need
    to get a job as a technology maker, a web developer, in today's market.
    You are our primary concern and our 1 on 1 education is much more
    effective and personal than jamming 25 students together into a cohort.
    DESCRIPTION
    @site_last_updated = 5.days.ago
  end
end
