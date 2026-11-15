# http://localhost:3000/rails/mailers/sign_in_mailer/code
class SignInMailerPreview < ActionMailer::Preview
  def code
    record = SignInCode.new(destination: "ana@example.com", locale: "es", code_digest: "x", expires_at: 10.minutes.from_now)
    SignInMailer.code(sign_in_code: record, code: "123456", link: "preview-token")
  end
end
