RegRu
=====

Ruby wrapper for [reg.ru API](http://www.reg.ru/reseller/API2-tech "reg.ru API").

Usage
=======

Specify your login and password:

`@api = RegRu::Api.new('login', 'password')`
  or 
    RegRu::Api.login = 'login'
    RegRu::Api.password = 'password'
    @api = RegRu::Api.new

Then you must set path to ca_cert.pem:

`RegRu::Api.ca_cert_path = '/path/to/cacert.pem'`

To register a domain, pass contacts info and other required data:

     @api.domain_create(
     'period'              => 1,
     'domain_name'         => 'domain.ru',
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
     'p_addr'              => '101000, Москва, ул.Воробьянинова, 15,\\n кв.22, В. Лоханкину.',
     'phone'               => '+7 495 8102233',
     'fax'                 => '+7 3432 811221\\n+7 495 8102233',
     'e_mail'              => 'ncc@test.ru',
     'code'                => '789012345678' # ИНН
    )


To renew a domain, specify period and service_id (you received service_id after domain registration):

    @api.domain_renew(
     'period'     => 1,
     'service_id' => 123456
    )

---

2010 InSales LLC, released under the MIT license
