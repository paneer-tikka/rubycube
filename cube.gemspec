require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'rubycube'
  spec.version    = '0.2.0'
  spec.author     = 'Aditya Godbole'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'code.aa@gdbl.me'
  spec.homepage   = 'http://github.com/adityagodbole/rubycube'
  spec.summary    = 'Interfaces for Ruby'
  spec.test_file  = 'test/test_interface.rb'
  spec.files      = Dir['**/*'].reject { |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']

  spec.extra_rdoc_files = ['README.md', 'CHANGES', 'MANIFEST']

  spec.add_development_dependency('test-unit')
  spec.add_development_dependency('rake')

  spec.description = <<-EOF
    CUBE (Composable Units of Behaviour) implements Interfaces, Traits and typechecks for Ruby.
  EOF
end
