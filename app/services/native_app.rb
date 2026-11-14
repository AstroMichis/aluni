# frozen_string_literal: true

# config/native_app.yml, read once: what the native shells are and what the
# server tells them (ConfigurationsController, AppLinksController).
module NativeApp
  PATH = Rails.root.join("config/native_app.yml")

  module_function

  def config
    @config ||= YAML.safe_load(File.read(PATH)).fetch("app").freeze
  end

  def name = config.fetch("name")
  def bundle_id = config.fetch("bundle_id")
  def user_agent_prefix = config.fetch("user_agent_prefix")
  def sign_in_path = config.fetch("sign_in_path")
  def sign_up_path = config.fetch("sign_up_path")
  def home_path = config.fetch("home_path")
  def app_paths = Array(config["app_paths"])
  def colors = config.fetch("colors", {})
  def tabs = Array(config["tabs"])
end
