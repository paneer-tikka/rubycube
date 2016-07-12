require 'forwardable'
require 'securerandom'
require 'set'
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
  class MethodArityError < RuntimeError; end
  class TypeMismatchError < RuntimeError; end

  alias :extends :extend

  private
 
  def convert_to_lambda &block
    obj = Object.new
    obj.define_singleton_method(:_, &block)
    return obj.method(:_).to_proc
  end

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
    inherited_specs = map_spec(inherited_ids.flatten)
    specs = @ids.merge(inherited_specs)
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
      spec = specs[id]
      if spec.is_a?(Hash) && spec.key?(:in) && spec[:in].is_a?(Array)
        replace_check_method(mod, id, spec[:in], spec[:out])
      end
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
    end

    super mod
  end

  def replace_check_method(mod, id, inchecks, outcheck)
    orig_method = mod.instance_method(id)

    unless mod.instance_variable_defined?("@__interface_arity_skip") \
      && mod.instance_variable_get("@__interface_arity_skip")
      orig_arity = orig_method.parameters.size
      check_arity = inchecks.size
      if orig_arity != check_arity
        raise Interface::MethodArityError,
              "#{mod}: #{self}##{id} arity mismatch: #{orig_arity} instead of #{check_arity}"
      end
    end

    unless ENV['RUBY_INTERFACE_TYPECHECK'].to_i > 0 \
      && mod.instance_variable_defined?("@__interface_runtime_check") \
      && mod.instance_variable_get("@__interface_runtime_check")
      return
    end
    iface = self
    mod.class_exec do
      ns_meth_name = "#{id}_#{SecureRandom.hex(3)}".to_sym 
      alias_method ns_meth_name, id
      define_method(id) do |*args|
        args.each_index do |i|
          v, t = args[i], inchecks[i]
          begin
            check_type(t, v)
          rescue Interface::TypeMismatchError => e
            raise Interface::TypeMismatchError,
                  "#{mod}: #{iface}##{id} (arg: #{i}): #{e.message}"
          end
        end
        ret = send(ns_meth_name, *args)
        begin
          check_type(outcheck, ret) if outcheck
        rescue Interface::TypeMismatchError => e
          raise Interface::TypeMismatchError,
                "#{mod}: #{iface}##{id} (return): #{e.message}"
        end
        ret
      end
    end
  end

#  def verify_arity(mod, meth)
#    arity = mod.instance_method(meth).arity
#    unless arity == @ids[meth]
#      raise Interface::MethodArityError, "#{mod}: #{self}##{meth}=#{arity}. Should be #{@ids[meth]}"
#    end
#  end

  def map_spec(ids)
    ids.reduce({}) do |res, m|
      if m.is_a?(Hash)
        res.merge(m)
      elsif m.is_a?(Symbol) || m.is_a?(String)
        res.merge({ m.to_sym => nil })
      end
    end
  end

  def validate_spec(spec)
    [*spec].each do |t|
      if t.is_a?(Array)
        unless t.first.is_a?(Module)
          raise ArgumentError, "#{t} does not contain a Module or Interface"
        end
      elsif !t.is_a?(Module)
        raise ArgumentError, "#{t} is not a Module or Interface"
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

  def proto(meth, *args)
    out_spec = yield if block_given?
    validate_spec(args)
    validate_spec(out_spec) if out_spec
    @ids.merge!({ meth.to_sym => { in: args, out: out_spec }})
  end

  def public_visible(*ids)
    unless ids.all? { |id| id.is_a?(Symbol) || id.is_a?(String) }
      raise ArgumentError, "Arguments should be strings or symbols"
    end
    spec = map_spec(ids)
    @ids.merge!(spec)
  end

  def private_visible(*ids)
    unless ids.all? { |id| id.is_a?(Symbol) || id.is_a?(String) }
      raise ArgumentError, "Arguments should be strings or symbols"
    end
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

  def shell
    ids = @ids
    unreq = @unreq
    cls = Class.new(Object) do
      (ids.keys - unreq).each do |m|
        define_method(m) { |*args| }
      end
    end
    cls.send(:shell_implements, self)
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
    def check_type(t, v)
      if t.is_a?(Set)
        unless t.any? { |tp| check_type(tp, v) rescue false }
          raise Interface::TypeMismatchError,
            "#{v.inspect} is not any of #{tp.to_a}" unless v.is_a?(tp)
        end
        return
      end
      if t.is_a? Array
        raise Interface::TypeMismatchError,
              "#{v} is not an Array" unless v.is_a? Array
        check_type(t.first, v.first)
        check_type(t.first, v.last)
        return
      end
      raise Interface::TypeMismatchError, "#{v.inspect} is not type #{t}" unless v.is_a? t
      true
    end
  else
    def check_type(*_); end
  end

end

class Module
  def implements(mod, runtime_checks: true)
    unless is_a? Class
      raise "Non-Class modules should not implement interfaces"
    end
    instance_variable_set(:@__interface_runtime_check, true) if runtime_checks
    include(mod)
  end

  def as_interface(iface, runtime_checks: true)
    clone.implements(iface, runtime_checks: runtime_checks)
  end

  def assert_implements(iface)
    clone.implements(iface, false)
  end

  def with_trait(trait, aliases: {}, suppresses: [])
    unless trait.is_a? Interface::Trait
      raise ArgumentError, "#{trait} is not an Interface::Trait"
    end
    cls = clone
    cls.instance_variable_set(:@__trait_allow_include, true)
    cls.instance_variable_set(:@__trait_cloned_from, self)
    raise ArgumentError, "aliases must be a Hash" unless aliases.is_a?(Hash)
    raise ArgumentError, "supresses must be a Array" unless suppresses.is_a?(Array)

    al_trait = trait_with_resolutions(trait, aliases, suppresses)
    cls.include(al_trait)
    cls
  end

  private

  def trait_with_resolutions(trait, aliases, suppress)
    cl = trait.clone
    cl.module_exec do
      suppress.each do |sup|
        undef_method(sup)
      end
      aliases.each do |before, after|
        begin
          alias_method(after, before)
        rescue => e
          $stderr.puts "with_trait(#{trait}): #{e.message}"
          raise ArgumentError, "with_trait(#{trait}): #{e.message}"
        end
        undef_method(before)
      end
    end
    cl
  end

  def shell_implements(mod)
    instance_variable_set(:@__interface_runtime_check, false)
    instance_variable_set(:@__interface_arity_skip, true)
    include(mod)
  end
end

module Interface
  module Trait
    class MethodConflict < RuntimeError; end
    class IncludeError < RuntimeError; end

    def requires_interface(intf)
      unless intf.is_a? Interface
        raise ArgumentError, "#{intf} is not an Interface"
      end
      @__interface_trait_required_interface = intf
    end

    def append_features(mod)
      unless mod.instance_variable_defined?(:@__trait_allow_include) &&
             mod.instance_variable_get(:@__trait_allow_include)
        raise IncludeError, "Traits can only be mixed in using method `with_trait`"
      end
      conflicts = public_instance_methods & mod.public_instance_methods
      errors = conflicts.map { |c|
        meth = mod.instance_method(c)
        { meth: meth, owner: meth.owner } unless meth.owner.is_a?(Class)
      }.compact
      unless errors.empty?
        message = "\n" + errors.map { |e| e[:meth].to_s }.join("\n")
        raise MethodConflict, message
      end
      if @__interface__trait_required_interface
        intf = @__interface_trait_required_interface
        mod.include?(intf) || mod.assert_implements(intf)
      end
      super(mod)
    end
  end
end
