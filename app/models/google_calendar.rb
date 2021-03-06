class GoogleCalendar
  USER_ID = "default".freeze
  SCOPE = "https://www.googleapis.com/auth/calendar".freeze

  attr_reader :calendar

  def initialize(request:)
    @request = request
    @calendar_service = Google::Apis::CalendarV3::CalendarService.new
    @calendar_service.authorization = credentials if request.present?
  end

  def available_calendars
    calendars.find_all { |calendar| calendar.available? }
  end

  def calendars
    @calendar_service.list_calendar_lists.items.map do |item|
      next unless item.id.ends_with?("resource.calendar.google.com")
      calendar_for_today(item.id)
    end.compact.sort_by { |calendar| calendar.location }
  end

  def calendar(calendar_id)
    @calendar_service.get_calendar_list(calendar_id)
  end

  def calendar_for_today(calendar_id)
    calendar_data = calendar(calendar_id)
    Calendar.new(calendar_data, @calendar_service)
  end

  def handle_auth_callback!
    authorizer.handle_auth_callback(USER_ID, @request)
  end

  def authorized?
    @credentials.present?
  end

  def authorization_url(callback:)
    authorizer.get_authorization_url(request: @request, redirect_to: callback)
  end

  private

  def credentials
    @credentials ||= authorizer.get_credentials(USER_ID, @request)
  end

  def token_store
    Google::Auth::Stores::RedisTokenStore.new(redis: $redis)
  end

  def config_store_file
    Rails.root.join("config", "google", "config.json")
  end

  def credentials_store_file
    Rails.root.join("config", "google", "calendar-oauth2.json")
  end

  def client_id
    Google::Auth::ClientId.from_file(credentials_store_file)
  end

  def authorizer
    Google::Auth::WebUserAuthorizer.new(client_id, SCOPE, token_store, "/oauth/callback")
  end
end
