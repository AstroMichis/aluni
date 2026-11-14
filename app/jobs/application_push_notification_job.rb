# Delivers one ApplicationPushNotification to one device (Action Push Native).
# On the `push` queue so pausing the push service (Platform::Switchboard) holds it.
class ApplicationPushNotificationJob < ActionPushNative::NotificationJob
  queue_as :push
end
