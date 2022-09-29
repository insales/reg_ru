require 'digest/sha1'
require 'uri'
require 'net/http'
require 'net/https'

require 'active_support/core_ext/class/attribute'

module RegRu
  class MissingCaCertFile < StandardError; end

  class Api
    CONNECTION_ATTEMPTS = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60

    POSITIVE_RENEW_ANSWER_STATUSES = ["renew_success", "only_bill_created"].freeze
    REQUIRED_FIELDS_FOR_RENEW = ["period", "service_id"].freeze

    class_attribute :login, :password, :logger
    class_attribute :ca_cert_path, instance_writer: false

    attr_reader :response

    def initialize(login=nil, password=nil)
      self.login = login if login
      raise(ArgumentError, "Login is required") unless self.login
      self.password = password if password
      raise(ArgumentError, "Password is required") unless self.password
    end

    # Registers a domain. Returns service_id if success.
    # Example:
    # @api.domain_create(
    #   'period'              => 1,
    #   'domain_name'         => 'domain.ru',
    #   'point_of_sale'       => 'insales.ru',
    #   'enduser_ip'          => '127.0.0.1',
    #   'ns0'                 => 'ns1.reg.ru',
    #   'ns1'                 => 'ns2.reg.ru',
    #   'private_person_flag' => 1,
    #   'person'              => 'Vassily N Pupkin',
    #   'person_r'            => 'Пупкин Василий Николаевич',
    #   'passport'            => '4 02 651241 выдан 48 о/м г.Москвы 26.12.1990',
    #   'birth_date'          => '07.11.1917',
    #   'country'             => 'RU',
    #   'p_addr'              => '101000, Москва, ул.Воробьянинова, 15,\\n кв.22, В. Лоханкину.',
    #   'phone'               => '+7 495 8102233',
    #   'fax'                 => '+7 3432 811221\\n+7 495 8102233',
    #   'e_mail'              => 'ncc@test.ru',
    #   'code'                => '789012345678'
    # )

    def domain_create(options)
      request_v2('domain','create', options)
      if is_success?
        response["answer"]["service_id"]
      end
    end

    # Renews a domain. Returns true if success. Service_id and Period are required arguments.
    # Example:
    # @api.domain_renew(
    #   'period'     => 1,
    #   'service_id' => 123456
    # )

    def domain_renew(options)
      required = REQUIRED_FIELDS_FOR_RENEW
      if (required - options.keys).any?
        raise ArgumentError, "#{required.join(', ')} are missing. Given: #{options.keys.join(', ')}"
      end

      request_v2('service', 'renew', options)
      is_renew_success?
    end

    def domain_service_id(options)
      request_v2('domain', 'nop', options)
      return response["answer"]["service_id"] if is_success?
    end

    # Check domain's availability to register. Currently supports checking only one domain name at a time.
    # Returns true if domain is available.
    def domain_check(name)
      options = { "domains" => [ {"dname" => name} ] }
      request_v2("domain", "check", options)
      if is_success?
        record = response["answer"]["domains"].first
        record && record["error_code"].nil? && record["result"] == "Available"
      end
    end

    def domain_suggest(options)
      request_v2("domain", "get_suggest", options)
    end

    def service_get_info(options)
      request_v2('service', 'get_info', options)
      return response['answer']['services'].first if is_success?
    end

    def zone_add(options)
      request_v1('zone_add_rr',options)
    end

    def zone_rm(options)
      request_v1('zone_rm_rr',options)
    end

    def get_info(domains)
      request_v2('service', 'get_info',
        input_format: 'json',
        input_data: {domains: domains.map{ |domain| { dname: domain } } }.to_json
      )["answer"]["services"].index_by {|e| e["dname"].mb_chars.downcase.to_s}
    end

    def is_success?
      response["result"] == "success"
    end

    # Also checks renew status.
    def is_renew_success?
      is_success? && POSITIVE_RENEW_ANSWER_STATUSES.include?(response["answer"]["status"])
    end

    def error_detail
      response["error_params"] && response["error_params"]["error_detail"]
    end

    def error_code
      response["error_code"]
    end

    protected

    def test_v1
      request_v1('domain_check','domain_name' => 'domain.ru')
    end

    def request_v1(action,options={})
      data = options.merge(
        action: action,
        username: login,
        password: password,
        extended_message_lang: 'ru',
      )
      url = "https://api.reg.ru/api/regru"
      answer = ssl_post(url, data)
      @response = {"result" => answer.match(/\ASuccess:/) ? "success" : "errors"}
      response["error_code"] = answer unless is_success?
    end

    def test_v2
      request_v2('domain', 'nop', 'domain_name' => 'domain.ru')
    end

    def request_v2(group,command,options={})
      data = options.merge(
        output_format: 'json',
        username: login,
        password: password,
        lang: 'ru',
      )
      data[:input_format]  ||= 'plain'
      url = "https://api.reg.ru/api/regru2/#{group}/#{command}"
      @response = JSON.parse(ssl_post(url, data))
      if !is_success? && error_code == "ACCESS_DENIED_FROM_IP"
        raise "Добавьте в личном кабинете рег-ру IP: #{response["error_params"]}: " \
          "Личный кабинет => Насройки безопасности => Ограничения доступа к аккаунту"
      end
      response
    end

    def ssl_post(url, data)
      logger&.info { "RegRu::Api#ssl_post request: #{url} #{data.except(:password)}" }
      data = URI.encode_www_form(data) if data && !data.is_a?(String)
      uri = URI.parse(url)
      http = build_http_client(uri)
      attempts = CONNECTION_ATTEMPTS
      begin
        response = http.post(uri.request_uri, data).body
        logger&.info { "RegRu::Api#ssl_post response: #{response}" }
        response
      rescue Errno::ECONNREFUSED => e
        attempts -= 1
        logger&.error { "RegRu::Api#ssl_post error: #{e}, attempts remain: #{attempts}" }
        retry if attempts.positive?
      rescue
        logger&.error { "RegRu::Api#ssl_post error: #{e}" }
        raise
      end
    end

    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      if uri.scheme == "https"
        http.use_ssl = true
        http.ca_file = ca_cert_path if ca_cert_path
      end
      http
    end
  end
end
