describe Fastlane::Actions do
  describe '#slack_helper' do
    describe "trim" do
      it "does not trim short messages" do
        long_text = "a" * 5
        expect(Fastlane::Helper::SlackHelper.trim_message(long_text).length).to eq(5)
      end
      it "trims long messages to show the bottom of the messages" do
        long_text = "a" * 10_000
        expect(Fastlane::Helper::SlackHelper.trim_message(long_text).length).to eq(7000)
      end
    end
  end
end