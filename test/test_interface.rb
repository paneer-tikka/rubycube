#####################################################
# test_interface.rb
#
# Test suite for the Interface module.
#####################################################
ENV['RUBY_INTERFACE_TYPECHECK'] = "1"
require 'test-unit'
require 'interface'


class TC_Interface < Test::Unit::TestCase
  def self.startup
    alpha_interface = interface{
      public_visible({:alpha => 0}, :beta)
    }

    gamma_interface = interface{
      extends alpha_interface
      public_visible :gamma
      unrequired_methods :alpha
    }

    # Workaround for 1.9.x
    @@alpha_interface = alpha_interface
    @@gamma_interface = gamma_interface

    eval("class A; end")

    eval("
      class B
        def alpha; end
        def beta; end
      end
    ")

    eval("
      class C
        def beta; end
        def gamma; end
      end
    ")
  end


  def checker_method(arg)
    check_interface { { @@gamma_interface => arg }}
  end

  def test_version
    assert_equal('0.1.0', Interface::VERSION)
  end

  def test_interface_requirements_not_met
    assert_raise(Interface::PublicVisibleMethodMissing){ A.extend(@@alpha_interface) }
    assert_raise(Interface::PublicVisibleMethodMissing){ A.new.extend(@@alpha_interface) }
  end

  def test_sub_interface_requirements_not_met
    assert_raise(Interface::PublicVisibleMethodMissing){ B.extend(@@gamma_interface) }
    assert_raise(Interface::PublicVisibleMethodMissing){ B.new.extend(@@gamma_interface) }
  end

  def test_alpha_interface_requirements_met
    assert_nothing_raised{ B.new.extend(@@alpha_interface) }
  end

  def test_gamma_interface_requirements_met
    assert_nothing_raised{ C.new.extend(@@gamma_interface) }
  end

  def test_method_check
    assert_nothing_raised { checker_method(C.implements(@@gamma_interface).new) }
    B.implements(@@alpha_interface)
    assert_raise(ArgumentError) { checker_method(B.implements(@@alpha_interface).new) }
  end
end
