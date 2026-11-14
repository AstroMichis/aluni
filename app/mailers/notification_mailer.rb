# The one mailer action the notification router can target until the product
# defines its own purposes: a subject and a body, in the recipient's locale.
class NotificationMailer < ApplicationMailer
  def generic(user, subject, body)
    @body = body
    I18n.with_locale(user.locale) do
      mail(to: user.email_address, subject: subject)
    end
  end
end
