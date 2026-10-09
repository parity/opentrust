require "rails_helper"

RSpec.describe PhoneNormalizer do
  it "hashes every common format identically" do
    hashes = ["98765 43210", "+919876543210", "09876543210", "98765-43210", "919876543210"].map { |p| described_class.call(p)[:hash] }
    expect(hashes.uniq.size).to eq(1)
  end

  it "rejects invalid numbers" do
    ["12345", "5876543210", "", nil].each { |p| expect { described_class.call(p) }.to raise_error(PhoneNormalizer::Invalid) }
  end
end
