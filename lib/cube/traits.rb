require_relative 'interfaces'

module Cube
  module Trait
    class MethodConflict < RuntimeError; end
    class IncludeError < RuntimeError; end

    def requires_interface(intf)
      unless intf.is_a? Cube::Interface
        raise ArgumentError, "#{intf} is not a Cube::Interface"
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

class Module
  def with_trait(trait, aliases: {}, suppresses: [])
    unless trait.is_a? Cube::Trait
      raise ArgumentError, "#{trait} is not an Cube::Trait"
    end
    cls = clone
    cls.instance_variable_set(:@__trait_allow_include, true)
    cls.instance_variable_set(:@__trait_cloned_from, self)
    raise ArgumentError, "aliases must be a Hash" unless aliases.is_a?(Hash)
    raise ArgumentError, "supresses must be a Array" unless suppresses.is_a?(Array)

    al_trait = trait_with_resolutions(trait, aliases, suppresses)
    al_trait.instance_variable_set(:@__interface_runtime_check, false)
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
end
