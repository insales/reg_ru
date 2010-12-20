require File.dirname(__FILE__) + '/../../lib/reg_ru/api'
require File.dirname(__FILE__) + '/../../lib/reg_ru/post_data'
require File.dirname(__FILE__) + '/../../lib/reg_ru/posts_data'

describe RegRu::Api do
  subject do
    RegRu::Api.ca_cert_path = File.dirname(__FILE__) + '/cacert.pem'
    @api = RegRu::Api.new('test','test')
  end

  before do
    subject.stub!(:request_v2)
    subject.stub!(:request_v1)
    subject.stub!(:response).and_return(
      {
        "answer" => {"service_id" => 12345, "period" => 1}, 
        "result" => "success"
      }
    )
  end

  describe "#required_fields_for_renew" do
    it "returns required fields" do
      RegRu::Api.required_fields_for_renew.should == ["period", "service_id"]
    end
  end

  describe "#domain_renew" do
    before do
      @response = { "answer" => {"service_id" => 12345, "period" => 1, "status" => "renew_success"}, "result" => "success" }
      subject.stub!(:response).and_return @response
    end

    it "checks argument" do
      lambda { subject.domain_renew("period" => 1) }.should raise_error(ArgumentError)
      lambda { subject.domain_renew("service_id" => 1) }.should raise_error(ArgumentError)
      lambda { subject.domain_renew("period" => 1, "service_id" => 1) }.should_not raise_error
    end

    it "return true if success" do
      subject.domain_renew("service_id" => 12345, "period" => 1)
      subject.is_renew_success?.should be_true
    end

    describe "#is_renew_success?" do
      it "verifies response status and renew status" do
        answer_ok_only_bill_created = @response.dup; answer_ok_only_bill_created["answer"]["status"] = "only_bill_created"
        subject.stub!(:response).and_return answer_ok_only_bill_created
        subject.is_renew_success?.should be_true

        answer_bad = @response.dup; answer_bad["answer"]["status"] = "unknown"
        subject.stub!(:response).and_return answer_bad
        subject.is_renew_success?.should be_false
      end
    end
  end

  describe "#domain_create" do
    it "works" do
      result = subject.domain_create(
        'period'              => 1,
        'domain_name'         => 'vschizh.ru',
        'point_of_sale'       => 'insales.ru',
        'enduser_ip'          => '127.0.0.1',
        'ns0'                 => 'ns1.reg.ru',
        'ns1'                 => 'ns2.reg.ru',
        'private_person_flag' => 1,
        'person'              => 'Vassily N Pupkin',
        'person_r'            => 'Пупкин Василий Николаевич',
        'passport'            => '4 02 651241 выдан 48 о/м г.Москвы 26.12.1990',
        'birth_date'          => '07.11.1917',
        'country'             => 'RU',
        'p_addr'              => '101000, Москва, ул.Воробьянинова, 15,\\\\n кв.22, В. Лоханкину.',
        'phone'               => '+7 495 8102233',
        'fax'                 => '+7 3432 811221\\\\n+7 495 8102233',
        'e_mail'              => 'ncc@test.ru',
        'code'                => '789012345678'
      )

      subject.is_success?.should be_true
      result.should_not be_nil
    end
  end

  describe "#domain_check" do
    before do
      response = {
          "answer" => {
              "domains" => [
                  {
                      "dname"      => 'megashop.ru',
                      "result"     => 'Available',
                  },
              ]
          },
          "result" => 'success'
      }
      subject.stub!(:response).and_return response
    end
    it "works" do
      result = subject.domain_check("megashop.ru")
      subject.is_success?.should be_true
      result.should be_true
    end
  end
end
