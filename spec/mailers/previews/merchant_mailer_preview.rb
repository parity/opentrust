# Open http://localhost:3000/rails/mailers in development to see every email, HTML and plain text.
class MerchantMailerPreview < ActionMailer::Preview
  def received = MerchantMailer.received(sample_merchant)
  def verification_code = MerchantMailer.verification_code(MerchantUser.new(email: "asha@raohandloom.example"), "482913")
  def approved = MerchantMailer.approved(sample_merchant)
  def rejected = MerchantMailer.rejected(sample_merchant(rejection_reason: "We couldn't find a website or marketplace page for the business. Please share a link to your store."))
  def rejected_without_reason = MerchantMailer.rejected(sample_merchant)

  private

  def sample_merchant(attrs = {})
    Merchant.new({ name: "Asha Rao", business_name: "Rao Handloom", contact_email: "asha@raohandloom.example" }.merge(attrs))
  end
end
