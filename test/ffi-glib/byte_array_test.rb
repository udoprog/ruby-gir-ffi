require File.expand_path('../gir_ffi_test_helper.rb', File.dirname(__FILE__))

describe GLib::ByteArray do
  it "can succesfully be created with Glib::ByteArray.new" do
    ba = GLib::ByteArray.new
    assert_instance_of GLib::ByteArray, ba
  end

  it "allows strings to be appended to it" do
    ba = GLib::ByteArray.new
    ba.append "abdc"
    pass
  end

  it "has a working #to_string method" do
    ba = GLib::ByteArray.new
    ba = ba.append "abdc"
    assert_equal "abdc", ba.to_string
  end
end

