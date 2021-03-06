$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'test/unit'
require 'lxc'

class TestLXCCreated < Test::Unit::TestCase
  def setup
    if Process::Sys::geteuid != 0
      raise 'This test must be run as root'
    end
    @name = 'test'
    @container = LXC::Container.new(@name)
    @container.create('ubuntu') unless @container.defined?
    # Make sure the renamed_test container does not exist, for the rename test
    @new_name = "renamed_#{@name}"
    new_container = LXC::Container.new(@new_name)
    new_container.destroy if new_container.defined?
  end

  def test_container_defined
    assert(@container.defined?)
  end

  def test_container_name
    assert_equal(@name, @container.name)
    assert_equal(@name, @container.config_item('lxc.utsname'))
  end

  def test_container_configuration
    capdrop = @container.config_item('lxc.cap.drop')
    assert_instance_of(Array, @container.config_item('lxc.cap.drop'))
    @container.clear_config_item('lxc.cap.drop')
    @container.set_config_item('lxc.cap.drop', capdrop[0...-1])
    @container.set_config_item('lxc.cap.drop', capdrop[-1])
    @container.save_config
    assert_equal(capdrop, @container.config_item('lxc.cap.drop'))
  end

  def test_container_networking
    assert(@container.keys('lxc.network.0').include?('name'))
    assert_match(/^00:16:3e:/, @container.config_item('lxc.network.0.hwaddr'))
  end

  def test_container_fstab
    config_path = @container.config_path + '/' + @name + '/config'
    fstab_path  = @container.config_path + '/' + @name + '/fstab'

    @container.set_config_item('lxc.mount', fstab_path)
    @container.save_config(config_path)

    assert_instance_of(String, @container.config_item('lxc.mount'))
    assert_not_nil(@container.config_item('lxc.mount'))

    f = File.readlines(config_path)
    f.reject! { |l| /^lxc\.mount = (.*)$/ =~ l }
    File.write(config_path, f.join)

    @container.clear_config
    @container.load_config(config_path)

    assert(@container.config_item('lxc.mount').nil?)
  end

  def test_clear_config
      assert_not_nil(@container.config_item('lxc.utsname'))
      assert(@container.clear_config)

      assert_raise(LXC::Error) do 
        @container.config_item('lxc.utsname').nil?
      end
  end

  def test_container_mount_points
    assert_instance_of(Array, @container.config_item('lxc.mount.entry'))
  end

  def test_container_rename
    @container.stop if @container.running?
    renamed = @container.rename(@new_name)
    assert_equal(@new_name, renamed.name)
    rerenamed = renamed.rename(@name)
    assert_equal(@name, rerenamed.name)
  end

  def test_start
    @container.stop if @container.running?
    @container.start
    assert(@container.running?)
  end

  def test_start_with_args
    @container.stop if @container.running?
    @container.start(:close_fds => true)
    assert(@container.running?)
  end
end
