require 'gir_ffi/builder/type/unintrospectable'

module GirFFI
  module Builder
    module Type

      # Implements the creation of GObject subclasses from Ruby.
      class UserDefined < Object
        def initialize klass, &block
          @block = block
          @klass_before_set_up = klass
        end

        def instantiate_class
          @klass = @klass_before_set_up

          self.instance_eval(&@block) if @block

          parent_type = @klass.get_gtype
          @parent = gir.find_by_gtype(parent_type)

          query_result = GObject.type_query parent_type
          type_info = GObject::TypeInfo.new
          type_info.class_size = query_result.class_size
          type_info.instance_size = query_result.instance_size
          properties.each do
            type_info.instance_size += FFI.type_size(:int32)
          end

          new_type = GObject.type_register_static parent_type, @klass.name, type_info, 0

          # TODO: Check that class ultimately derives from GObject.
          @gtype = new_type
          @info = nil
          @structklass = get_or_define_class @klass, :Struct, layout_superclass
          setup_class unless already_set_up
        end

        def setup_class
          setup_layout
          setup_constants
          #stub_methods
          setup_gtype_getter
          setup_property_accessors
          #setup_vfunc_invokers
          #setup_interfaces
          setup_constructor
        end

        private

        def target_gtype
          @gtype
        end

        def parent
          @parent
        end

        def install_property pspec
          properties << pspec
        end

        def properties
          @properties ||= []
        end

        def layout_specification
          parent_spec = [:parent, superclass::Struct, 0]
          offset = superclass::Struct.size
          fields_spec = properties.map do |pspec|
            spec = [pspec.get_name, :int32, offset]
            offset += FFI.type_size(:int32)
            spec
          end.flatten(1)
          parent_spec + fields_spec
        end

        def setup_property_accessors
          properties.each do |pspec|
            setup_accessors_for_param_spec pspec
          end
        end

        def setup_accessors_for_param_spec pspec
          code = <<-CODE
          def #{pspec.get_name}
            @struct[:#{pspec.get_name}]
          end
          def #{pspec.get_name}= val
            @struct[:#{pspec.get_name}] = val
          end
          CODE

          @klass.class_eval code
        end

        def method_introspection_data method
          nil
        end

        def setup_constructor
          code = <<-CODE
          def self.new
            gptr = GObject::Lib.g_object_newv #{@gtype}, 0, nil
            self.wrap(gptr)
          end
          CODE
          @klass.class_eval code
        end
      end
    end
  end
end

