require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'interface'
  spec.version    = '1.1.0'
  spec.author     = 'Aditya Godbole'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'code.aa@gdbl.me'
  spec.homepage   = 'http://github.com/adityagodbole/interface'
  spec.summary    = 'Interfaces for Ruby'
  spec.test_file  = 'test/test_interface.rb'
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']

  spec.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST']

  spec.add_development_dependency('test-unit')
  spec.add_development_dependency('rake')

  spec.description = <<-EOF
    The interface library implements Interfaces for Ruby.
    It lets you define a set a methods that must be defined in the
    including class or module, or an error is raised.

    It also allows you to make runtime checks to check whether an
    object implements an interface
  EOF
end
