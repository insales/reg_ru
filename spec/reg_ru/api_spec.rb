require 'reg_ru/api'

describe RegRu::Api do
  subject { described_class.new('test','test') }

  describe "#required_fields_for_renew" do
    it "returns required fields" do
      expect(RegRu::Api::REQUIRED_FIELDS_FOR_RENEW).to eq(["period", "service_id"])
    end
  end

  describe "#domain_renew" do
    let(:response_status) { "renew_success" }
    let(:response) do
      {
        "answer" => {"service_id" => 12345, "period" => 1, "status" => response_status },
        "result" => "success"
      }
    end
    let!(:request) do
      stub_request(:post, "https://api.reg.ru/api/regru2/service/renew").
        with(body: "service_id=12345&period=1&output_format=json&username=test&password=test&lang=ru&input_format=plain").
        to_return(status: 200, body: response.to_json, headers: {})
    end

    it "checks argument" do
      expect { subject.domain_renew("period" => 1) }.to raise_error(ArgumentError)
      expect { subject.domain_renew("service_id" => 1) }.to raise_error(ArgumentError)
    end

    it "return true if success" do
      expect(subject.domain_renew("service_id" => 12345, "period" => 1)).to be_truthy
      expect(subject.is_renew_success?).to eq true
      expect(request).to have_been_requested
    end

    describe "#is_renew_success?" do
      before do
        subject.domain_renew("service_id" => 12345, "period" => 1)
      end

      context "when status only_bill_created" do
        let(:response_status) { "only_bill_created" }

        it "is success" do
          expect(subject.is_renew_success?).to eq true
        end
      end

      context "when status unknown" do
        let(:response_status) { "unknown" }

        it "is non-success" do
          expect(subject.is_renew_success?).to eq false
        end
      end
    end
  end

  describe "#domain_create" do
    let(:response) do
      {
        "answer" => {
          # ??
          "service_id" => 12345, "period" => 1
        },
        "result" => 'success'
      }
    end
    let!(:request) do
      stub_request(:post, "https://api.reg.ru/api/regru2/domain/create").
        with(
          body: "period=1&domain_name=vschizh.ru&point_of_sale=insales.ru&enduser_ip=127.0.0.1&ns0=ns1.reg.ru&ns1=ns2.reg.ru&private_person_flag=1&person=Vassily+N+Pupkin&person_r=%D0%9F%D1%83%D0%BF%D0%BA%D0%B8%D0%BD+%D0%92%D0%B0%D1%81%D0%B8%D0%BB%D0%B8%D0%B9+%D0%9D%D0%B8%D0%BA%D0%BE%D0%BB%D0%B0%D0%B5%D0%B2%D0%B8%D1%87&passport=4+02+651241+%D0%B2%D1%8B%D0%B4%D0%B0%D0%BD+48+%D0%BE%2F%D0%BC+%D0%B3.%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D1%8B+26.12.1990&birth_date=07.11.1917&country=RU&p_addr=101000%2C+%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D0%B0%2C+%D1%83%D0%BB.%D0%92%D0%BE%D1%80%D0%BE%D0%B1%D1%8C%D1%8F%D0%BD%D0%B8%D0%BD%D0%BE%D0%B2%D0%B0%2C+15%2C%5C%5Cn+%D0%BA%D0%B2.22%2C+%D0%92.+%D0%9B%D0%BE%D1%85%D0%B0%D0%BD%D0%BA%D0%B8%D0%BD%D1%83.&phone=%2B7+495+8102233&fax=%2B7+3432+811221%5C%5Cn%2B7+495+8102233&e_mail=ncc%40test.ru&code=789012345678&output_format=json&username=test&password=test&lang=ru&input_format=plain"
        ).to_return(status: 200, body: response.to_json, headers: {})
    end

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

      expect(subject.is_success?).to eq true
      expect(result).not_to be_nil
      expect(request).to have_been_requested
    end
  end

  describe "#domain_check" do
    let(:response) do
      {
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
    end
    let!(:request) do
      stub_request(:post, "https://api.reg.ru/api/regru2/domain/check").
        with(
          body: "domains=%7B%22dname%22+%3D%3E+%22megashop.ru%22%7D&output_format=json&username=test&password=test&lang=ru&input_format=plain"
        ).
        to_return(status: 200, body: response.to_json, headers: {})
    end

    it "works" do
      result = subject.domain_check("megashop.ru")
      expect(subject.is_success?).to eq true
      expect(result).to eq true
      expect(request).to have_been_requested
    end
  end
end
