# Be sure to restart your server when you modify this file.

# Application-wide HTTP permissions policy. Nothing in the shell needs camera,
# microphone, sensors, USB or payment APIs; enable one here when a feature does.
Rails.application.config.permissions_policy do |policy|
  policy.camera      :none
  policy.gyroscope   :none
  policy.microphone  :none
  policy.usb         :none
  policy.fullscreen  :self
  policy.payment     :none
end
