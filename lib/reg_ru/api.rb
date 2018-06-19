require 'digest/sha1'
require 'reg_ru/posts_data'

module RegRu
  class MissingCaCertFile < StandardError; end
  class Api
    include RegRu::PostsData

    POSITIVE_RENEW_ANSWER_STATUSES = ["renew_success", "only_bill_created"].freeze
    REQUIRED_FIELDS_FOR_RENEW = ["period", "service_id"].freeze

    # allows to define login, password for different environments: production, test, etc.
    cattr_accessor :login, :password, :ca_cert_path

    attr_accessor :response, :login, :password, :logger

    def initialize(login=nil, password=nil)
      unless RegRu::Api.ca_cert_path && File.exists?(RegRu::Api.ca_cert_path)
        raise MissingCaCertFile, "You should provide path to ca_cert.pem in RegRu::Api.ca_cert_path"
      end

      self.login = login || RegRu::Api.login || raise(ArgumentError, "Login is required")
      self.password = password || RegRu::Api.password || raise(ArgumentError, "Password is required")
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
      if (options.keys & Api.required_fields_for_renew).size != Api.required_fields_for_renew.size
        raise ArgumentError, \
        "#{Api.required_fields_for_renew.join(', ')} should be provided in arguments hash. You provided only #{options.keys.join(', ')}"
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

    def self.required_fields_for_renew
      REQUIRED_FIELDS_FOR_RENEW
    end

    def test_v1
      request_v1('domain_check','domain_name' => 'domain.ru')
    end

    def request_v1(action,options={})
      data = PostData.new
      data.merge!(options)
      data[:action]        = action
      data[:username]      = login
      data[:extended_message_lang] = 'ru'
      data[:password]      = password
      url = "https://api.reg.ru/api/regru"
      answer = ssl_post(url, data.to_s)
      logger.try {|l| l.call("request_v1: #{url} #{data.inspect} response: #{answer.inspect}") }
      self.response = {"result" => answer.match(/\ASuccess:/) ? "success" : "errors"}
      response["error_code"] = answer unless is_success?
    end

    def test_v2
      request_v2('domain', 'nop', 'domain_name' => 'domain.ru')
    end

    def request_v2(group,command,options={})
      data = PostData.new
      data.merge!(options)
      data[:input_format]  ||= 'plain'
      data[:output_format] = 'json'
      data[:username]      = login
      data[:lang]          = 'ru'
      data[:password]      = password
      url = "https://api.reg.ru/api/regru2/#{group}/#{command}"
      self.response = ::JSON.parse(ssl_post(url, data.to_s))
      if !is_success? && error_code == "ACCESS_DENIED_FROM_IP"
        raise "Добавьте в личном кабинете рег-ру IP: #{response["error_params"]}: Личный кабинет => Насройки безопасности => Ограничения доступа к аккаунту"
      end
      logger.try {|l| l.call("request_v2: #{url} #{data.inspect} response: #{self.response.inspect}") }
      self.response
    end

    # TODO: Needs rework
    def signature(options,command)
      options[:timestamp] = Time.now.to_i
      options[:action] = command
      secretkey_hash = Digest::SHA1.hexdigest(password)
      message_digest = "#{options.keys.sort_by(&:to_s).map{|name| options[name]}.join(':')}:#{secretkey_hash}"
      Digest::SHA1.hexdigest(message_digest)
    end
  end
end
