## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# encoding: utf-8
require 'rack/test'
require 'rspec'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'
#$LOAD_PATH << '../models'
require_relative File.dirname(__FILE__) + '/../models/request'
require_relative File.dirname(__FILE__) + '/../controllers/application_controller'
require_relative File.dirname(__FILE__) + '/../controllers/requests_controller'
require_relative File.dirname(__FILE__) + '/../controllers/root_controller'
require_relative File.dirname(__FILE__) + '/../controllers/pings_controller'
require_relative File.dirname(__FILE__) + '/../controllers/services_controller'
require_relative File.dirname(__FILE__) + '/../controllers/functions_controller'
require_relative File.dirname(__FILE__) + '/../controllers/records_controller'
require_relative File.dirname(__FILE__) + '/../services/message_publishing_service'
Dir.glob('./services/*.rb').each { |file| require file }

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.mock_with :rspec do |configuration|
    configuration.syntax = :expect
  end
  config.order = 'random'
  #config.color_enabled = true
  config.tty = true
  config.formatter = :documentation
  config.profile_examples = 3
end

WebMock.disable_net_connect!() #allow_localhost: true)
