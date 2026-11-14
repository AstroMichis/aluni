# Preview at http://localhost:3000/rails/mailers/notification_mailer/generic
class NotificationMailerPreview < ActionMailer::Preview
  def generic
    user = User.new(display_name: "Ada", email_address: "ada@example.com", locale: "en")
    NotificationMailer.generic(user, "Welcome to Aluni", "Glad you are here.")
  end
end
