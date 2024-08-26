# require 'aws-sdk-lambda'
# require 'json'

# def lambda_handler(event:, context:)
#   puts "called lambda_handler"
#   if defined?(::OpenTelemetry::SDK)
#     $client = Aws::Lambda::Client.new(stub_responses: true)
#     $client.get_account_settings()
#     { statusCode: 200, body: "Hello #{::OpenTelemetry::SDK::VERSION}" }
#   else
#     { statusCode: 200, body: "Missing OpenTelemetry" }
#   end
# end

# lambda_function.rb
puts "initialize lambda_function.rb"


variable = 'logger'

require variable
require 'json'
require 'net/http'
if true
  require 'uri'
end


# require 'logger'
# require 'json'
# require 'net/http'
# require 'uri'

# require 'aws-sdk-lambda'
# require 'opentelemetry'
# require 'opentelemetry-instrumentation-aws_sdk'
# #require 'aws-xray-sdk/lambda'

# for manual tracing
$tracer = ::OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])
# $client = Aws::Lambda::Client.new(stub_responses: true)
# puts "Aws::Lambda::Client: #{Aws::Lambda::Client.ancestors}"
# # unexpected usage, this creates an extra trace during cold start
# $client.get_account_settings()
def lambda_handler(event:, context:)
  
  # for manual tracing
  # $tracer = ::OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])
  $client = Aws::Lambda::Client.new(stub_responses: true)
  # unexpected usage, this creates an extra trace during cold start
  # $client.get_account_settings()

  if event.key?('exception')
    # throw a division by zero
    _ = 1/0
  end
  # puts "$client: #{$client.inspect}"
  $client.get_account_settings().account_usage.to_h
  body['awsclient'] = $client.get_account_settings().account_usage.to_h
  { "statusCode":200, "body": body.to_s }
end