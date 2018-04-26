require 'httparty'
require 'json'

require 'cdek_client/abstract_client'
require 'cdek_client/calculator_errors'
require 'cdek_client/util'

module CdekClient
  
  class CalculatorClient < AbstractClient

    def initialize(account = nil, password = nil)
      @account = account
      @password = password
    end

    def calculate(params)
      params = normalize_request_data params
      formatted_date_execute = if params[:dateExecute].is_a?(Date) || params[:dateExecute].is_a?(Time)
        CdekClient.format_date params[:dateExecute]
      elsif !Util.blank? params[:dateExecute]
        params[:dateExecute]
      else
        CdekClient.format_date Date.today
      end
      params.merge!(
        version: CdekClient::CALCULATOR_API_VERSION,
        dateExecute: formatted_date_execute
      )
      if !@account.nil? && !@password.nil?
        params.merge!({
          authLogin: @account,
          secure: CdekClient.generate_secure(formatted_date_execute, @password)
        })
      end
      result = request url_for(:calculator_primary, :calculate), url_for(:calculator_secondary, :calculate), :post, params
      if result.errors.any?
        result.set_data({})
      elsif result.data.has_key?(:error)
        Util.array_wrap(result.data[:error]).each do |error_data|
          error = Calculator.get_api_error error_data[:code], error_data[:text]
          result.add_error error
        end
        result.set_data({})
      else
        normalized_data = normalize_response_data result.data[:result], response_normalization_rules_for(:calculate)
        result.set_data normalized_data
      end
      return result
    end
  
    def get_list_by_term(params)
      params = normalize_request_data params
      result = request url_for(:calculator_primary, :get_list_by_term), url_for(:calculator_secondary, :get_list_by_term), :get, params
      if result.errors.any?
        result.set_data []
        return result
      end
      if result.data.has_key? :ErrorCode
        error = CdekClient.get_api_error result.data[:ErrorCode], result.data[:Msg]
        result.add_error error
        result.set_data []
      else
        normalized_data = Util.array_wrap result.data[:geonames]
        normalized_data = normalize_response_data normalized_data, response_normalization_rules_for(:get_list_by_term)
        result.set_data normalized_data
      end
      result
    end

    private

    def request(url, retry_url, method, params = {})
      params = params.to_json
      request_params = { 
        headers: { 'Content-Type' => 'application/json' }
      }
      result = raw_request url, retry_url, method, {}, params
      if !Util.blank? result.data
        data = Util.deep_symbolize_keys JSON.parse(result.data)
        result.set_data data
      end
      result
    end

  end
end
