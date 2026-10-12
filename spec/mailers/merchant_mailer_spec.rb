require "rails_helper"

RSpec.describe MerchantMailer do
  let(:merchant) { build(:merchant, name: "Asha Rao", business_name: "Rao Handloom", contact_email: "asha@example.com") }

  def html(mail) = mail.html_part.body.decoded
  def text(mail) = mail.text_part.body.decoded

  shared_examples "a branded email" do
    it "sends both an HTML and a plain-text version" do
      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it "carries the logo, the footer and the sponsor credit" do
      expect(html(mail)).to include("/email/opentrust-logo.png", "Built proudly in India", "ParityCube", OpenTrust::FEEDBACK_EMAIL)
      expect(text(mail)).to include(OpenTrust::FEEDBACK_EMAIL, "ParityCube")
    end

    it "has no unrendered ERB in either version" do
      expect(html(mail) + text(mail)).not_to match(/<%|%>/)
    end
  end

  describe "#verification_code" do
    let(:mail) { described_class.verification_code(MerchantUser.new(email: "asha@example.com"), "482913") }
    include_examples "a branded email"

    it "puts the code in the subject, the preview line and both bodies" do
      expect(mail.subject).to eq("Your OpenTrust verification code: 482913")
      expect(mail.to).to eq(["asha@example.com"])
      expect(html(mail)).to include("482913", "expires in <strong>10 minutes</strong>")
      expect(text(mail)).to include("482913", "10 minutes")
    end
  end

  describe "#received" do
    let(:mail) { described_class.received(merchant) }
    include_examples "a branded email"

    it "names the business and explains what happens next" do
      expect(mail.subject).to eq("OpenTrust: we received your registration")
      expect(html(mail)).to include("Rao Handloom", "What happens next")
      expect(text(mail)).to include("Rao Handloom", "What happens next")
    end
  end

  describe "#approved" do
    let(:mail) { described_class.approved(merchant) }
    include_examples "a branded email"

    it "shows the allowance and links to log in" do
      expect(mail.subject).to eq("OpenTrust: you're approved")
      expect(html(mail)).to include("#{ActiveSupport::NumberHelper.number_to_delimited(OpenTrust::FREE_CHECKS)} free checks", "https://opentrust.test/login")
      expect(text(mail)).to include("https://opentrust.test/login")
    end
  end

  describe "#rejected" do
    let(:mail) { described_class.rejected(merchant) }
    include_examples "a branded email"

    it "gives the reason when there is one" do
      merchant.rejection_reason = "Please share a link to your store."
      expect(html(mail)).to include("Reason", "Please share a link to your store.")
      expect(text(mail)).to include("Reason: Please share a link to your store.")
    end

    it "still reads well without a reason" do
      expect(html(mail)).not_to include("Reason")
      expect(text(mail)).not_to include("Reason:")
    end
  end

  it "escapes what merchants type, so a business name cannot inject markup" do
    merchant.business_name = "<script>alert(1)</script>"
    expect(html(described_class.received(merchant))).not_to include("<script>alert(1)</script>")
    expect(html(described_class.received(merchant))).to include("&lt;script&gt;")
  end
end
