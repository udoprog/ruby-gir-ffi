require 'forwardable'
require 'gir_ffi/ffi_ext/pointer'

module GirFFI
  # Base class for all generated classes. Contains code for dealing with
  # the generated Struct classes.
  class ClassBase
    # TODO: Make separate base for :struct, :union, :object.
    extend Forwardable
    def_delegators :@struct, :to_ptr

    def ffi_structure
      self.class.ffi_structure
    end

    def _builder
      self.class._builder
    end

    def setup_and_call method, *arguments, &block
      result = self.class.ancestors.any? do |klass|
        klass.respond_to?(:_setup_instance_method) &&
          klass._setup_instance_method(method.to_s)
      end

      unless result
        raise RuntimeError, "Unable to set up instance method #{method} in #{self}"
      end

      self.send method, *arguments, &block
    end

    def self.setup_and_call method, *arguments, &block
      result = self.ancestors.any? do |klass|
        klass.respond_to?(:_setup_method) &&
          klass._setup_method(method.to_s)
      end

      unless result
        raise RuntimeError, "Unable to set up method #{method} in #{self}"
      end

      self.send method, *arguments, &block
    end

    class << self
      def ffi_structure
	self.const_get(:Struct)
      end

      def gir_info
	self.const_get :GIR_INFO
      end

      def _builder
	self.const_get :GIR_FFI_BUILDER
      end

      def _find_signal name
        _builder.find_signal name
      end

      def _find_property name
        _builder.find_property name
      end

      def _setup_method name
        _builder.setup_method name
      end

      def _setup_instance_method name
        _builder.setup_instance_method name
      end

      alias_method :_real_new, :new
      undef new

      def wrap ptr
	return nil if ptr.nil? or ptr.null?
	obj = _real_new
        obj.instance_variable_set :@struct, ffi_structure.new(ptr.to_ptr)
        obj
      end

      # TODO: Only makes sense for :objects.
      def constructor_wrap ptr
        wrap ptr
      end

      def allocate
	obj = _real_new
        obj.instance_variable_set :@struct, ffi_structure.new
        obj
      end

      # Pass-through casting method. This may become a type checking
      # method. It is overridden by GValue to implement wrapping of plain
      # Ruby objects.
      def from val
        val
      end
    end
  end
end
