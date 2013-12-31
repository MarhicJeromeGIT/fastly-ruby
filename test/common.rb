module CommonTests
  def test_creating_service_and_backend
    name        = "fastly-test-service-#{get_rand}"
    service     = @fastly.create_service(:name => name)
    assert service
    assert_equal name, service.name
    tmp         = @fastly.get_service(service.id)
    assert tmp
    assert_equal name, tmp.name

    version     = service.version
    assert version

    settings    = @fastly.get_settings(service.id, version.number)
    assert settings
    assert_equal settings.service_id, service.id
    assert_equal settings.version.to_s, version.number.to_s

    default_ttl = settings.settings['general.default_ttl']
    settings    = version.settings
    assert settings
    assert_equal settings.service_id, service.id
    assert_equal settings.version.to_s, version.number.to_s
    assert_equal settings.settings['general.default_ttl'], default_ttl

    settings.settings['general.default_ttl'] = default_ttl = "888888888"
    settings.save!;

    settings = version.settings
    assert_equal settings.settings['general.default_ttl'].to_s, default_ttl;

    services = @fastly.list_services
    assert !services.empty?
    assert !services.select { |s| s.name == name }.empty?

    service = @fastly.search_services( :name => name )
    assert service
    assert name, service.name


    service = @fastly.search_services( :name => name, :version => version.number )
    assert services
    assert name, service.name

    version2    = @fastly.create_version(:service_id => service.id)
    assert version2
    assert_equal = version.number.to_i+1, version2.number.to_i

    version3 = version2.clone
    assert version3
    assert_equal = version2.number.to_i+1, version3.number.to_i

    number = version3.number.to_i

    backend_name = "fastly-test-backend-#{get_rand}"
    backend = begin
      @fastly.create_backend(:service_id => service.id, :version => number, :hostname => 'localhost', :name => backend_name)
    rescue Fastly::Error
    end
    assert_nil backend

    backend = @fastly.create_backend(:service_id => service.id, :version => number, :address => '74.125.224.146', :name => backend_name)
    assert backend
    assert_equal backend.service_id, service.id
    #assert_equal backend.ipv4, '74.125.224.146'
    assert_equal backend.address, '74.125.224.146'
    assert_equal backend.port.to_s, '80'

    backend.address  = 'thegestalt.org'
    backend.port     = '9092'
    @fastly.update_backend(backend)
    backend          = @fastly.get_backend(service.id, number, backend_name)

    assert backend
    assert_equal backend.address, 'thegestalt.org'
    #assert_equal backend.hostname, 'thegestalt.org'
    assert_equal backend.port.to_s, '9092'


    domain_name = "fastly-test-domain-#{get_rand}-example.com"
    domain  = @fastly.create_domain(:service_id => service.id, :version => number, :name => domain_name)
    assert domain
    assert_equal domain_name, domain.name
    assert_equal domain.service.id, service.id
    assert_equal domain.version_number.to_s, number.to_s
    assert_equal domain.version.number.to_s, number.to_s

    domain.comment = "Flibbety gibbet"
    domain.save!
    domain         = @fastly.get_domain(service.id, number, domain_name)
    assert_equal domain.name, domain_name
    assert_equal domain.comment, "Flibbety gibbet"

    director_name = "fastly-test-director-#{get_rand}"
    director      = @fastly.create_director(:service_id => service.id, :version => number, :name => director_name)
    assert director
    assert_equal director_name, director.name
    assert_equal director.service.id, service.id
    assert_equal director.version_number.to_s, number.to_s
    assert_equal director.version.number.to_s, number.to_s

    assert director.add_backend(backend)
    generated2  = version3.generated_vcl

    origin_name = "fastly-test-origin-#{get_rand}"
    origin      = @fastly.create_origin(:service_id => service.id, :version => number, :name => origin_name)
    assert origin
    assert_equal origin_name, origin.name
    assert_equal origin.service.id, service.id
    assert_equal origin.version_number.to_s, number.to_s
    # assert_equal origin.version.number.to_s, number.to_s

    assert version3.activate!
    assert version3.deactivate!
    assert !@fastly.get_service(version3.service_id).version.active
    assert !@fastly.get_service(version3.service_id).version.active?
    assert version3.activate!
    assert @fastly.get_service(version3.service_id).version.active
    assert @fastly.get_service(version3.service_id).version.active?

    generated = version3.generated_vcl(:no_content => true)
    assert generated
    assert generated.content.nil?
    generated = version3.generated_vcl
    assert !generated.content.nil?
    assert generated.content.match(/\.port = "9092"/ms)

    assert version3.validate

    version3.deactivate!
    @fastly.delete_service(service)
  end

  def test_stats
    name        = "fastly-test-service-#{get_rand}"
    service     = @fastly.create_service(:name => name)
    assert service
    assert_equal name, service.name
    tmp         = @fastly.get_service(service.id)
    assert tmp
    assert_equal name, tmp.name

    begin
      stats       = service.stats
    rescue Fastly::Error => e
    end
    assert stats.nil?

    stats       = service.stats(:all, :year => 2011, :month => 10)
    assert stats
    @fastly.delete_service(service)
  end

  def test_invoices
    name        = "fastly-test-service-#{get_rand}"
    service     = @fastly.create_service(:name => name)
    assert service
    assert_equal name, service.name

    invoice     = service.invoice
    assert invoice
    assert invoice.regions
    assert_equal invoice.service_id, service.id

    invoice     = @fastly.get_invoice
    assert_equal Fastly::Invoice,  invoice.class

    year        = Time.now.year
    month       = Time.now.month

    invoice     = @fastly.get_invoice(year, month)
    assert_equal Fastly::Invoice,  invoice.class
    assert_equal year,  invoice.start.year
    assert_equal month, invoice.start.month
    assert_equal 1,     invoice.start.day
    assert_equal year,  invoice.end.year
    assert_equal month, invoice.end.month
    @fastly.delete_service(service)
  end

end
