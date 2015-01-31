=begin
Plugin: Weather Logger
Description: Log the daily high, daily low, and average temperature, for a given location.
Author: Joe Martin (http://desertflood.com/)
Configuration:
  weather_location_lat: 42.922
  weather_location_long: -89.395
  weather_api_key: 89b8a67d457644d8879f367b8a3a7755
  weather_tags: "#Weather"
Notes:
  - This uses the Forecast.io API.
=end

config = { # All parameters required
  'description' => ['Daily weather recorder.',
                    'The location has to be specified as a latitude and longitude.',
                    'You must obtain your own API key from Forecast.io.'],
  'weather_location_lat' => '',
  'weather_location_long' => '',
  'weather_api_key' => '',
  'weather_tags' => '#Weather'
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'WeatherLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class WeatherLogger < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('weather_location_lat') || config['weather_location_lat'] == [] || !config.key?('weather_location_long') || config['weather_location_long'] == [] || !config.key?('weather_api_key') || config['weather_api_key'] == []
        @log.warn("WeatherLogger has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        latitude = config['weather_location_lat']
        longitude = config['weather_location_long']
        api_key = config['weather_api_key']
      end
    else
      @log.warn("WeatherLogger has not been configured or an option is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging Weather for #{latitude} and #{longitude}")

	config['weather_tags'] ||= ''
    tags = "\n\n#{config['weather_tags']}\n" unless config['weather_tags'] == ''
    today = @timespan

    # Perform necessary functions to retrieve posts

    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify
    options = {}
    options['content'] = "#{summarize_weather(latitude,longitude,api_key)}#{tags}"
    options['datestamp'] = Time.now.utc.iso8601
    options['starred'] = false
    options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    # Create a journal entry
    # to_dayone accepts all of the above options as a hash
    # generates an entry base on the datestamp key or defaults to "now"
    sl = DayOne.new
    sl.to_dayone(options)

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error

  end

  def summarize_weather(lat,lng,api_key)
    require 'forecast_io'
    require 'time'

    summary = ""

    ForecastIO.api_key = api_key
    yesterday = Time.parse((Date.today).strftime("%Y-%m-%d 23:59:59"))

    forecast = ForecastIO.forecast(lat, lng, time: yesterday.to_i, params: { units: 'si'})
    count = 0
    temp = 0
    forecast.hourly.data.each { |h|
        temp=temp+h['temperature']
        count=count+1
      }

    dp = forecast.daily.data[0]
    max = dp[:temperatureMax]
    min = dp[:temperatureMin]
    minTime = Time.at(dp[:temperatureMinTime])
    maxTime = Time.at(dp[:temperatureMaxTime])
    output = [
      "**Low**: %d at %s" % [min.round(), minTime.strftime("%H:%M")],
      "**High**: %d at %s" % [max.round(), maxTime.strftime("%H:%M")],
      "**Average**: %d" % [(temp/count).round()]
    ]
    summary = "## Daily Weather Summary\n\n"
    if dp[:temperatureMinTime] > dp[:temperatureMaxTime] then
      summary << output[1] << "\n"
      summary << output[0] << "\n"
    else
      summary << output[0] << "\n"
      summary << output[1] << "\n"
    end
    summary << output[2]
    return summary
  end
end
