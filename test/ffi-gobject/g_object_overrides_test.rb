require File.expand_path('../gir_ffi_test_helper.rb', File.dirname(__FILE__))

require 'ffi-gobject'

class GObjectOverridesTest < MiniTest::Spec
  context "In the GObject module with overridden functions" do
    setup do
      GirFFI.setup :Regress
    end

    context "the signal_emit function" do
      should "emit a signal" do
	a = 1
	o = Regress::TestSubObj.new
	::GObject::Lib.g_signal_connect_data o, "test", Proc.new { a = 2 }, nil, nil, 0
	GObject.signal_emit o, "test"
	assert_equal 2, a
      end

      should "handle return values" do
	s = Gio::SocketService.new

	argtypes = [:pointer, :pointer, :pointer, :pointer]
	callback = FFI::Function.new(:bool, argtypes) { |a,b,c,d| true }
	::GObject::Lib.g_signal_connect_data s, "incoming", callback, nil, nil, 0
	rv = GObject.signal_emit s, "incoming"
	assert_equal true, rv.get_boolean
      end

      should "pass in extra arguments" do
	o = Regress::TestSubObj.new
	sb = Regress::TestSimpleBoxedA.new
	sb.some_int8 = 31
	sb.some_double = 2.42
	sb.some_enum = :value2
	b2 = nil

	argtypes = [:pointer, :pointer, :pointer]
	callback = FFI::Function.new(:void, argtypes) do |a,b,c|
	  b2 = b
	end
	::GObject::Lib.g_signal_connect_data o, "test-with-static-scope-arg", callback, nil, nil, 0
	GObject.signal_emit o, "test-with-static-scope-arg", sb

	sb2 = Regress::TestSimpleBoxedA.wrap b2
	assert sb.equals(sb2)
      end
    end

    context "the signal_connect function" do
      should "install a signal handler" do
	a = 1
	o = Regress::TestSubObj.new
	GObject.signal_connect(o, "test") { a = 2 }
	GObject.signal_emit o, "test"
	assert_equal 2, a
      end

      should "pass user data to handler" do
	a = 1
	o = Regress::TestSubObj.new
	GObject.signal_connect(o, "test", 2) { |i, d| a = d }
	GObject.signal_emit o, "test"
	assert_equal 2, a
      end

      should "pass object to handler" do
	o = Regress::TestSubObj.new
	o2 = nil
	GObject.signal_connect(o, "test") { |i, d| o2 = i }
	GObject.signal_emit o, "test"
	assert_instance_of Regress::TestSubObj, o2
	assert_equal o.to_ptr, o2.to_ptr
      end

      should "not allow connecting an invalid signal" do
	o = Regress::TestSubObj.new
	assert_raises RuntimeError do
	  GObject.signal_connect(o, "not-really-a-signal") {}
	end
      end

      should "handle return values" do
	s = Gio::SocketService.new
	GObject.signal_connect(s, "incoming") { true }
	rv = GObject.signal_emit s, "incoming"
	assert_equal true, rv.get_boolean
      end

      should "require a block" do
	o = Regress::TestSubObj.new
	assert_raises ArgumentError do
	  GObject.signal_connect o, "test"
	end
      end

      context "connecting a signal with extra arguments" do
	setup do
	  @a = nil
	  @b = 2

	  o = Regress::TestSubObj.new
	  sb = Regress::TestSimpleBoxedA.new
	  sb.some_int = 23

	  GObject.signal_connect(o, "test-with-static-scope-arg", 2) { |i, object, d|
	    @a = d
	    @b = object
	  }
	  GObject.signal_emit o, "test-with-static-scope-arg", sb
	end

	should "move the user data argument" do
	  assert_equal 2, @a
	end

	should "pass on the extra arguments" do
	  assert_instance_of Regress::TestSimpleBoxedA, @b
	  assert_equal 23, @b.some_int
	end
      end

    end

    context "The GObject overrides Helper module" do
      context "#signal_arguments_to_gvalue_array" do
	context "the result of wrapping test-with-static-scope-arg" do
	  setup do
	    o = Regress::TestSubObj.new
	    b = Regress::TestSimpleBoxedA.new

	    @gva =
	      GObject::Helper.signal_arguments_to_gvalue_array(
		"test-with-static-scope-arg", o, b)
	  end

	  should "be a GObject::ValueArray" do
	    assert_instance_of GObject::ValueArray, @gva
	  end

	  should "contain two values" do
	    assert_equal 2, @gva.n_values
	  end

	  should "have a first value with GType for TestSubObj" do
	    assert_equal Regress::TestSubObj.get_gtype, (@gva.get_nth 0).current_gtype
	  end

	  should "have a second value with GType for TestSimpleBoxedA" do
	    assert_equal Regress::TestSimpleBoxedA.get_gtype, (@gva.get_nth 1).current_gtype
	  end
	end
      end

      describe "#signal_argument_to_gvalue" do
        it "maps a :utf8 argument to a string-valued GValue" do
          stub(arg_t = Object.new).tag { :utf8 }
          stub(info = Object.new).argument_type { arg_t }
          val =
            GObject::Helper.signal_argument_to_gvalue(
              info, "foo")
          assert_instance_of GObject::Value, val
          assert_equal "foo", val.get_string
        end
      end

      describe "#cast_back_signal_arguments" do
        it "correctly casts back pointers for the test-with-static-scope-arg signal" do
          o = Regress::TestSubObj.new
          b = Regress::TestSimpleBoxedA.new
          ud = GirFFI::ArgHelper.object_to_inptr "Hello!"

          assert_equal "Hello!", GirFFI::ArgHelper::OBJECT_STORE[ud.address]

          sig = o.class._find_signal "test-with-static-scope-arg"

          gva =
            GObject::Helper.cast_back_signal_arguments(
              sig, o.class, o.to_ptr, b.to_ptr, ud)

          klasses = gva.map {|it| it.class}
          klasses.must_equal [ Regress::TestSubObj,
                               Regress::TestSimpleBoxedA,
                               String ]
          gva[2].must_equal "Hello!"
        end
      end

      describe "#cast_signal_argument" do
        describe "with info for an enum" do
          before do
            enuminfo = get_introspection_data 'GLib', 'DateMonth'
            stub(arg_t = Object.new).interface { enuminfo }
            stub(arg_t).tag { :interface }
            stub(@info = Object.new).argument_type { arg_t }
          end

          it "casts an integer to its enum symbol" do
            res = GObject::Helper.cast_signal_argument @info, 7
            assert_equal :july, res
          end
        end

        describe "with info for an interface" do
          before do
            ifaceinfo = get_introspection_data 'Regress', 'TestInterface'
            stub(arg_t = Object.new).interface { ifaceinfo }
            stub(arg_t).tag { :interface }
            stub(@info = Object.new).argument_type { arg_t }
          end

          it "casts the argument by calling #to_object on it" do
            mock(ptr = Object.new).to_object { "good-result" }
            res = GObject::Helper.cast_signal_argument @info, ptr
            res.must_equal "good-result"
          end
        end
      end
    end

    context "The RubyClosure class" do
      should "have a constructor with a block argument" do
        assert_raises ArgumentError do
          GObject::RubyClosure.new
        end
      end

      should "be a kind of Closure" do
        c = GObject::RubyClosure.new {}
        assert_kind_of GObject::Closure, c
      end

      should "be able to retrieve its block from its struct" do
        a = 0
        c = GObject::RubyClosure.new { a = 2 }
        c2 = GObject::RubyClosure.wrap(c.to_ptr)
        c2.block.call
        assert_equal 2, a
      end

      context "its #marshaller singleton method" do
        should "invoke its closure argument's block" do
          a = 0
          c = GObject::RubyClosure.new { a = 2 }
          GObject::RubyClosure.marshaller(c, nil, 0, nil, nil, nil)
          assert_equal 2, a
        end

        should "work when its closure argument is a GObject::Closure" do
          a = 0
          c = GObject::RubyClosure.new { a = 2 }
          c2 = GObject::Closure.wrap(c.to_ptr)
          GObject::RubyClosure.marshaller(c2, nil, 0, nil, nil, nil)
          assert_equal 2, a
        end

        should "store the closure's return value in the proper gvalue" do
          c = GObject::RubyClosure.new { 2 }
          gv = GObject::Value.new
          GObject::RubyClosure.marshaller(c, gv, 0, nil, nil, nil)
          assert_equal 2, gv.ruby_value
        end
      end

      should "have GObject::Closure#invoke call its block" do
        a = 0
        c = GObject::RubyClosure.new { a = 2 }
        c2 = GObject::Closure.wrap(c.to_ptr)
        c2.invoke nil, nil, nil
        assert_equal 2, a
      end
    end
  end
end
