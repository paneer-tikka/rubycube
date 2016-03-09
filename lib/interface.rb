# A module for implementing Java style interfaces in Ruby. For more information
# about Java interfaces, please see:
#
# http://java.sun.com/docs/books/tutorial/java/concepts/interface.html
#
module Interface
  # The version of the interface library.
  Interface::VERSION = '0.1.0'
   
  # Raised if a class or instance does not meet the interface requirements.
  class MethodMissing < RuntimeError; end
  class PrivateVisibleMethodMissing < MethodMissing; end
  class PublicVisibleMethodMissing < MethodMissing; end
  class MethodArityError < MethodMissing; end

  alias :extends :extend

  private
 
  def extend_object(obj)
    return append_features(obj) if Interface === obj
    append_features(class << obj; self end)
    included(obj)
  end

  def append_features(mod)
    return super if Interface === mod

    # Is this a sub-interface?
    inherited = (self.ancestors-[self]).select{ |x| Interface === x }
    inherited_ids = inherited.map{ |x| x.instance_variable_get('@ids') }

    # Store required method ids
    ids = @ids.keys + map_spec(inherited_ids.flatten).keys
    @unreq ||= []

    # Iterate over the methods, minus the unrequired methods, and raise
    # an error if the method has not been defined.
    mod_public_instance_methods = mod.public_instance_methods(true)
    (ids - @unreq).uniq.each do |id|
      id = id.to_s if RUBY_VERSION.to_f < 1.9
      unless mod_public_instance_methods.include?(id)
        raise Interface::PublicVisibleMethodMissing, "#{mod}: #{self}##{id}"
      end
      verify_arity(mod, id) if @ids[id]
    end

    inherited_private_ids = inherited.map{ |x| x.instance_variable_get('@private_ids') }
    # Store required method ids
    private_ids = @private_ids.keys + map_spec(inherited_private_ids.flatten).keys

    # Iterate over the methods, minus the unrequired methods, and raise
    # an error if the method has not been defined.
    mod_all_methods = mod.instance_methods(true) + mod.private_instance_methods(true)

    (private_ids - @unreq).uniq.each do |id|
      id = id.to_s if RUBY_VERSION.to_f < 1.9
      unless mod_all_methods.include?(id)
        raise Interface::PrivateVisibleMethodMissing, "#{mod}: #{self}##{id}"
      end
      verify_arity(mod, id) if @ids[id]
    end

    super mod
  end

  def verify_arity(mod, meth)
    arity = mod.instance_method(meth).arity
    unless arity == @ids[meth]
      raise Interface::MethodArityError, "#{mod}: #{self}##{meth}=#{arity}. Should be #{@ids[meth]}"
    end
  end

  def map_spec(ids)
    ids.reduce({}) do |res, m|
      if m.is_a?(Hash)
        res.merge(m)
      elsif m.is_a?(Symbol) || m.is_a?(String)
        res.merge({ m.to_sym => nil })
      end
    end
  end

  public
   
  # Accepts an array of method names that define the interface.  When this
  # module is included/implemented, those method names must have already been
  # defined. 
  #
  def required_public_methods
    @ids.keys
  end

  def public_visible(*ids)
    spec = map_spec(ids)
    @ids.merge!(spec)
  end

  def private_visible(*ids)
    spec = map_spec(ids)
    @private_ids.merge!(spec)
  end
  # Accepts an array of method names that are removed as a requirement for
  # implementation. Presumably you would use this in a sub-interface where
  # you only wanted a partial implementation of an existing interface.
  #
  def unrequired_methods(*ids)
    @unreq ||= []
    @unreq += ids
  end
end

class Object
  # The interface method creates an interface module which typically sets
  # a list of methods that must be defined in the including class or module.
  # If the methods are not defined, an Interface::MethodMissing error is raised.
  #	
  # A interface can extend an existing interface as well. These are called
  # sub-interfaces, and they can included the rules for their parent interface
  # by simply extending it.
  #
  # Example:
  #
  #   # Require 'alpha' and 'beta' methods
  #   AlphaInterface = interface{
  #      public_visible :alpha, :beta 
  #   }
  #
  #   # A sub-interface that requires 'beta' and 'gamma' only
  #   GammaInterface = interface{
  #      extends AlphaInterface
  #      public_visible :gamma
  #      unrequired_methods :alpha
  #   }
  #
  #   # Raises an Interface::MethodMissing error because :beta is not defined.
  #   class MyClass
  #      def alpha
  #         # ...
  #      end
  #      implements AlphaInterface
  #   end
  #
  def interface(&block)
    mod = Module.new
    mod.extend(Interface)
    mod.instance_variable_set('@ids', {})
    mod.instance_variable_set('@private_ids', {})
    mod.instance_eval(&block)
    mod
  end

  if ENV['RUBY_INTERFACE_TYPECHECK'].to_i > 0
    def check_class
      spec = yield
      spec.each do |type, k|
        fail NameError, "#{type} is not a class" unless type.is_a? Class
        fail ArgumentError, "#{k} is not type #{type}" unless k.is_a? type
      end
    end

    def check_interface
      spec = yield
      spec.each do |type, k|
        fail NameError, "#{type} is not an interface" unless type.is_a? Module
        unless k.class.include? type
          fail ArgumentError, "#{k} does not implement #{type}"
        end
      end
    end
  else
    def check_class(*_); end
    def check_interface(*_); end
  end

end

class Module
  alias_method :implements, :include
  alias_method :assert_implements, :include
end

module Interface::Trait
  def requires_interface(intf)
    unless intf.is_a? Interface
      raise ArgumentError, "#{intf} is not an Interface"
    end
    define_singleton_method(:included) do |mod|
      mod.assert_implements(intf) 
    end
  end


  def instantiator(meth, sym, intf)
    define_singleton_method(meth) do |val|
      check_interface { { intf => val } }
      Class.new {
        def initialize(val, sym)
          if sym.to_s.start_with? '@'
            raise ArgumentError, "Method cannot start with @: #{sym}"
          end
          instance_variable_set("@#{sym}".to_sym,val)
        end

        private

        attr_reader sym
      }.include(self).new(val, sym)
    end
  end
end

