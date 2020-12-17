# frozen_string_literal: true
ENV["RAILS_ENV"] = "test"

require 'bundler/setup'

require 'single_cov'
SingleCov.setup :minitest

require 'minitest/autorun'
require 'minitest/rg'
require 'minitest/around'
require 'mocha/setup'
require 'rails'
require 'action_controller'
require 'rails/generators'

class FakeApplication < Rails::Application; end

Rails.application = FakeApplication
Rails.configuration.action_controller = ActiveSupport::OrderedOptions.new
Rails.configuration.secret_key_base = 'secret_key_base'
Rails.logger = Logger.new("/dev/null")

ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)

require 'action_pack'
require 'strong_parameters' if ActionPack::VERSION::MAJOR == 3
require 'stronger_parameters'
require 'minitest/rails'
require 'minitest/autorun'

# https://github.com/rails/rails/issues/31324
if ActionPack::VERSION::STRING >= "5.2.0"
  Minitest::Rails::TestUnit = Rails::TestUnit
end

class Minitest::Test
  def params(hash)
    ActionController::Parameters.new(hash)
  end

  def assert_rejects(key, &block)
    err = block.must_raise StrongerParameters::InvalidParameter
    err.key.must_equal key.to_s
  end

  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  def self.permits(value, options = {})
    type_casted = options.fetch(:as, value)

    it "permits #{value.inspect} as #{type_casted.inspect}" do
      permitted = params(value: value).permit(value: subject)
      permitted = permitted.to_h if Rails::VERSION::MAJOR >= 5
      if type_casted.nil?
        permitted[:value].must_be_nil
      else
        permitted[:value].must_equal type_casted
      end
    end
  end

  def self.rejects(value, options = {})
    key = options.fetch(:key, :value)

    it "rejects #{value.inspect}" do
      assert_rejects(key) { params(value: value).permit(value: subject) }
    end
  end
end

# https://github.com/seattlerb/minitest/issues/666
if RUBY_VERSION > "2.1.0"
  Object.prepend(Module.new do
    def must_equal(*args)
      if args.first.nil?
        raise "Use must_be_nil"
      else
        super
      end
    end
  end)
end
