# The one list of reason codes: what the API accepts, what the forms and the docs show, and what GET /reason_codes returns.
#
# Rules for this list (it is part of the public API, so treat it like one):
#   - A code is permanent. Never rename or reuse one; retire it by marking it `retired: true` (still accepted, no longer offered).
#   - Labels and descriptions say what the merchant OBSERVED, never what the person is ("Disputed a payment", not "is a fraudster").
#   - Add a code only when a merchant would act differently on it. Otherwise it belongs in `notes`.
#   - Report the number of the party who DID the thing (the number they used to order, pay, call or message you), never the
#     number of someone who may be a victim. That is why there is no "account takeover" code: the number on a hijacked
#     account usually belongs to the person it happened to.
#   - Group names are only for display and may be reorganised. Codes are the contract.
class ReasonCatalog
  Entry = Struct.new(:code, :group, :label, :description, :use_when, :not_when, :retired, keyword_init: true)

  ENTRIES = [
    Entry.new(code: "cod_refusal", group: "Orders and returns", label: "Refused a cash-on-delivery order",
              description: "The customer refused or did not accept a cash-on-delivery order at the door.",
              use_when: "The customer placed a cash-on-delivery order and refused or didn't accept it at delivery, especially more than once.",
              not_when: "The item was wrong or damaged, or the delivery was badly late. That is an ordinary refusal, not a pattern of the customer."),
    Entry.new(code: "fake_order", group: "Orders and returns", label: "Placed an order that appeared fake",
              description: "An order that looked like it was placed with no intention to buy, for example with false details.",
              use_when: "The order details were clearly false (a made-up name, address or contact) or the order was placed with no intention of receiving it.",
              not_when: "The customer only changed their mind. If they refused at the door, use cod_refusal."),
    Entry.new(code: "return_abuse", group: "Orders and returns", label: "Repeated return or refund abuse",
              description: "Repeated returns or refund requests that looked like abuse of the return policy.",
              use_when: "The same customer repeatedly returned items or claimed refunds against your policy, for example saying 'not received' for delivered orders, or returning used or swapped items.",
              not_when: "A single return or dispute, however annoying, or a genuine defect."),
    Entry.new(code: "chargeback", group: "Payments", label: "Disputed a payment (chargeback)",
              description: "The customer disputed or reversed a payment (a card chargeback, or a UPI or bank dispute), or the payment gateway reported it as fraudulent.",
              use_when: "A payment was disputed or reversed after you delivered or credited (a card chargeback, or a UPI or bank dispute), or your payment gateway reported it as fraudulent.",
              not_when: "You agreed to an ordinary refund, or you only suspect fraud and no dispute has been raised."),
    Entry.new(code: "fake_payment_proof", group: "Payments", label: "Shared payment proof that didn't check out",
              description: "A payment screenshot or reference that turned out not to match a real payment.",
              use_when: "A screenshot, UTR or reference the customer gave as proof of payment didn't match any real payment.",
              not_when: "The payment was real but later reversed. Use chargeback."),
    Entry.new(code: "third_party_payment_fraud", group: "Payments", label: "Paid from someone else's card, bank account or wallet",
              description: "A payment or deposit came from a card, bank account or wallet in another person's name, and the account holder did not own or authorise it.",
              use_when: "You confirmed the payment or deposit came from a card, bank account or wallet in another person's name, and the account holder did not own or authorise it.",
              not_when: "Someone paid with a relative's card with the holder's consent, or you only noticed a different name and haven't confirmed anything."),
    Entry.new(code: "identity_fraud", group: "Accounts and identity", label: "Used someone else's identity details",
              description: "Someone used another person's name, documents or other identity details.",
              use_when: "You confirmed someone used another person's name, documents or identity details to sign up, order or verify.",
              not_when: "The documents merely didn't match or couldn't be verified (use document_mismatch), or you don't know whose identity was used."),
    Entry.new(code: "document_mismatch", group: "Accounts and identity", label: "Submitted documents that didn't match",
              description: "Documents submitted for verification (such as KYC) didn't match the account details or couldn't be verified.",
              use_when: "Documents submitted for KYC or verification didn't match the account details, or couldn't be verified, after you checked.",
              not_when: "You confirmed they used someone else's identity (use identity_fraud), or the difference was a spelling variation you resolved."),
    Entry.new(code: "promo_abuse", group: "Offers and programs", label: "Abused offers, cashback or referrals",
              description: "Abuse of offers, cashback, referral rewards, sign-up bonuses or wallet credits, including through multiple accounts.",
              use_when: "A customer abused offers against their terms: several accounts to claim sign-up bonuses, referral rewards or cashback, or misused wallet credits or coupons.",
              not_when: "One legitimate use of an offer, or using several coupons the terms allow."),
    Entry.new(code: "otp_fraud", group: "Impersonation and phone calls", label: "Asked someone for an OTP",
              description: "Someone asked a customer or a member of staff to share an OTP.",
              use_when: "Someone phoned or messaged your customer or staff and asked them to share an OTP.",
              not_when: "An OTP your own system sent to a customer. Report the caller's number, never the customer's."),
    Entry.new(code: "bank_impersonation", group: "Impersonation and phone calls", label: "Posed as a bank or financial institution",
              description: "Someone claimed to be calling from a bank or other financial institution.",
              use_when: "Someone claimed to be a bank or financial institution when contacting you or your customers.",
              not_when: "A genuine bank or payment partner you can verify."),
    Entry.new(code: "merchant_impersonation", group: "Impersonation and phone calls", label: "Posed as our business or support",
              description: "Someone claimed to represent the merchant's business or its customer support.",
              use_when: "Someone claimed to be your business, delivery or support when contacting your customers or staff.",
              not_when: "A real member of your own team or a partner you have authorised."),
    Entry.new(code: "phishing_link", group: "Impersonation and phone calls", label: "Sent a suspicious payment or login link",
              description: "Someone sent a payment or login link that looked designed to collect money or credentials.",
              use_when: "A link sent from this number led to a payment or login page that wasn't yours, or looked designed to collect money or credentials.",
              not_when: "An ordinary promotional or tracking link."),
    Entry.new(code: "kyc_scam", group: "Impersonation and phone calls", label: "Posed as a KYC or verification agent",
              description: "Someone claimed to be completing a KYC or account verification.",
              use_when: "Someone said an account or wallet would be blocked unless a KYC or verification step was completed through them.",
              not_when: "A real KYC request that came from you or your partner."),
    Entry.new(code: "refund_scam", group: "Impersonation and phone calls", label: "Made a suspicious refund request",
              description: "A refund request that looked like a scam, for example asking for the money to go to a different account.",
              use_when: "Someone contacted you about a refund nobody asked for, or asked for money to be sent back or refunded to a different account.",
              not_when: "A refund request you can tie to a real order."),
    Entry.new(code: "other", group: "Other", label: "Other",
              description: "Something not covered above. A short factual note (at least 10 characters) is required.",
              use_when: "Nothing above fits. Say what happened in a sentence of at least 10 characters. If the same thing keeps coming up, tell us and it may become a code.",
              not_when: "Anything that fits a code above, or anything you only suspect.")
  ].freeze

  BY_CODE = ENTRIES.index_by(&:code).freeze

  def self.codes = ENTRIES.map(&:code)
  def self.offered = ENTRIES.reject(&:retired)
  def self.find(code) = BY_CODE[code.to_s]
  def self.label(code) = find(code)&.label || code.to_s.humanize
  def self.groups = offered.group_by(&:group).transform_values { |entries| entries.map(&:code) }

  def self.to_api
    offered.map { |e| { code: e.code, group: e.group, label: e.label, description: e.description, use_when: e.use_when, not_when: e.not_when } }
  end
end
