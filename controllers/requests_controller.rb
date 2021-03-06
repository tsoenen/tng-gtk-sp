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
require 'sinatra'
require 'json'
#require 'logger'

class RequestsController < ApplicationController
  #register Sinatra::ActiveRecordExtension
  
  ERROR_REQUEST_CONTENT_TYPE={error: "Unsupported Media Type, just accepting 'application/json' HTTP content type for now."}
  ERROR_SERVICE_NOT_FOUND="Network Service with UUID '%s' was not found in the Catalogue."
  ERROR_PARSING_NS_DESCRIPTOR="There was an error parsing the NS descriptor with UUID '%s'."
  ERROR_CONNECTING_TO_CATALOGUE={error: "There was an error connecting to the Catalogue."}
  ERROR_EMPTY_BODY = <<-eos 
  The request was missing a body with:
     \tservice_uuid: the UUID of the service to be instantiated
     \trequest_type: can be CREATE_SERVICE (default), UPDATE_SERVICE or TERMINATE_SERVICE
     \tegresses: the list of required egresses (defaults to [])
     \tingresses: the list of required ingresses (defaults to [])
  eos
  #ERROR_SERVICE_UUID_IS_MISSING="Service UUID is a mandatory parameter (absent from the '%s' request)"
  ERROR_REQUEST_NOT_FOUND="Request with UUID '%s' was not found"
  
  before { content_type :json}
  after  {ActiveRecord::Base.clear_active_connections!}

  # Accept service instantiation requests
  post '/?' do
    msg='RequestsController.post'
    halt_with_code_body(415, ERROR_REQUEST_CONTENT_TYPE.to_json) unless request.content_type =~ /^application\/json/

    body = request.body.read
    halt_with_code_body(400, ERROR_EMPTY_BODY.to_json) if body.empty?
    params = JSON.parse(body, quirks_mode: true, symbolize_names: true)
    #halt_with_code_body(400, ERROR_SERVICE_UUID_IS_MISSING % params) unless params.key?(:service_uuid)
    
    begin
      STDERR.puts "#{msg}: before saved_request...'"
      saved_request = ProcessRequestService.call(params.deep_symbolize_keys) #, request.env['5gtango.user.data'])
      STDERR.puts "#{msg}: saved_request='#{saved_request.inspect}'"
      #halt_with_code_body(404, {error: "Service UUID '#{params[:service_uuid]}' not found"}.to_json) if (saved_request == {} || saved_request == nil)
      halt_with_code_body(400, {error: "Error saving request"}.to_json) if saved_request.to_s.empty? 
      halt_with_code_body(404, {error: saved_request[:error]}.to_json) if (saved_request && saved_request.is_a?(Hash) && saved_request.key?(:error))
      halt_with_code_body(201, saved_request.to_json)
    rescue ArgumentError => e
      halt_with_code_body(404, {error: e.message}.to_json)
    rescue JSON::ParserError => e
      halt_with_code_body(400, {error: ERROR_PARSING_NS_DESCRIPTOR % params[:service_uuid]}.to_json)
    rescue StandardError => e
      halt_with_code_body(500, e.message)
    end
  end
  
  # GETs a request, given an uuid
  get '/:request_uuid/?' do
    msg='RequestsController.get (single)'
    STDERR.puts "#{msg}: entered with uuid='#{params[:request_uuid]}'"
    captures=params.delete('captures') if params.key? 'captures'
    begin
      single_request = Request.find(params[:request_uuid])
      STDERR.puts "#{msg}: single_request='#{single_request}' (class #{single_request.class})"
      halt_with_code_body(200, ProcessRequestService.enrich_one(single_request.as_json).to_json) unless single_request.to_s.empty?
    rescue Exception => e
			ActiveRecord::Base.clear_active_connections!
      halt_with_code_body(404, {error: e.message}.to_json)
      raise
    end
    halt_with_code_body(404, {error: ERROR_REQUEST_NOT_FOUND % params[:request_uuid]}.to_json)
  end

  # GET many requests
  get '/?' do
    msg='RequestsController.get (many)'
    captures=params.delete('captures') if params.key? 'captures'
    STDERR.puts "#{msg}: entered with params='#{params}'"
    
    # get rid of :page_size and :page_number
    page_number, page_size, sanitized_params = sanitize(params)
    STDERR.puts "#{msg}: page_number, page_size, sanitized_params=#{page_number}, #{page_size}, #{sanitized_params}"
    begin
      requests = Request.where(sanitized_params).limit(page_size).offset(page_number)
      STDERR.puts "#{msg}: requests='#{requests}'"
      headers 'Record-Count'=>requests.size.to_s, 'Content-Type'=>'application/json'
      halt 200, ProcessRequestService.enrich(requests.to_a).to_json
    rescue ActiveRecord::RecordNotFound => e
      halt 200, '[]'
    end
  end
  
  options '/?' do
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET,DELETE'      
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
    halt 200
  end
  
  private
  def halt_with_code_body(code, body)
    halt code, {'Content-Type'=>'application/json', 'Content-Length'=>body.length.to_s}, body
  end
  
  def validated_fields(params_keys)
    valid_fields = [:service_uuid, :status, :created_at, :updated_at]
    logger.info(log_msg) {" keyed_params.keys - valid_fields = #{keyed_params.keys - valid_fields}"}
    json_error 400, "GtkSrv: wrong parameters #{params}" unless keyed_params.keys - valid_fields == []
  end
  
  def sanitize(params)
    params[:page_number] ||= ENV.fetch('DEFAULT_PAGE_NUMBER', 0)
    params[:page_size]   ||= ENV.fetch('DEFAULT_PAGE_SIZE', 100)
    page_number = params.delete(:page_number).to_i
    page_size = params.delete(:page_size).to_i
    return page_number, page_size, params
  end
  
  def symbolized_hash(hash)
    Hash[hash.map{|(k,v)| [k.to_sym,v]}]
  end
  
end
