# rubocop:disable Style/CaseEquality
# rubocop:disable Style/MultilineTernaryOperator
# rubocop:disable Style/NestedTernaryOperator
module Fastlane
  module Actions
    class SlackAction < Action
      def self.is_supported?(platform)
        true
      end

      def self.run(options)
        require 'slack-notifier'

        options[:message] = Helper::SlackHelper.trim_message(options[:message].to_s || '')
        options[:message] = Slack::Notifier::Util::LinkFormatter.format(options[:message])

        options[:pretext] = options[:pretext].gsub('\n', "\n") unless options[:pretext].nil?

        if options[:channel].to_s.length > 0
          channel = options[:channel]
          channel = ('#' + options[:channel]) unless ['#', '@'].include?(channel[0]) # send message to channel by default
        end

        username = options[:use_webhook_configured_username_and_icon] ? nil : options[:username]

        notifier = Slack::Notifier.new(options[:slack_url], channel: channel, username: username)

        link_names = options[:link_names]

        icon_url = options[:use_webhook_configured_username_and_icon] ? nil : options[:icon_url]

        slack_attachment = Helper::SlackHelper.generate_slack_attachments(options)

        return [notifier, slack_attachment] if Helper.test? # tests will verify the slack attachments and other properties

        begin
          results = notifier.ping('', link_names: link_names, icon_url: icon_url, attachments: [slack_attachment])
        rescue => exception
          UI.error("Exception: #{exception}")
        ensure
          result = results.first if results
          if !result.nil? && result.code.to_i == 200
            UI.success('Successfully sent Slack notification')
          else
            UI.verbose(result) unless result.nil?
            message = "Error pushing Slack message, maybe the integration has no permission to post on this channel? Try removing the channel parameter in your Fastfile, this is usually caused by a misspelled or changed group/channel name or an expired SLACK_URL"
            if options[:fail_on_error]
              UI.user_error!(message)
            else
              UI.error(message)
            end
          end
        end
      end

      def self.description
        "Send a success/error message to your [Slack](https://slack.com) group"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "FL_SLACK_MESSAGE",
                                       description: "The message that should be displayed on Slack. This supports the standard Slack markup language",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :pretext,
                                       env_name: "FL_SLACK_PRETEXT",
                                       description: "This is optional text that appears above the message attachment block. This supports the standard Slack markup language",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :channel,
                                       env_name: "FL_SLACK_CHANNEL",
                                       description: "#channel or @username",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :use_webhook_configured_username_and_icon,
                                       env_name: "FL_SLACK_USE_WEBHOOK_CONFIGURED_USERNAME_AND_ICON",
                                       description: "Use webhook's default username and icon settings? (true/false)",
                                       default_value: false,
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :slack_url,
                                       env_name: "SLACK_URL",
                                       sensitive: true,
                                       description: "Create an Incoming WebHook for your Slack group",
                                       verify_block: proc do |value|
                                         UI.user_error!("Invalid URL, must start with https://") unless value.start_with?("https://")
                                       end),
          FastlaneCore::ConfigItem.new(key: :username,
                                       env_name: "FL_SLACK_USERNAME",
                                       description: "Overrides the webhook's username property if use_webhook_configured_username_and_icon is false",
                                       default_value: "fastlane",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :icon_url,
                                       env_name: "FL_SLACK_ICON_URL",
                                       description: "Overrides the webhook's image property if use_webhook_configured_username_and_icon is false",
                                       default_value: "https://s3-eu-west-1.amazonaws.com/fastlane.tools/fastlane.png",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :payload,
                                       env_name: "FL_SLACK_PAYLOAD",
                                       description: "Add additional information to this post. payload must be a hash containing any key with any value",
                                       default_value: {},
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :default_payloads,
                                       env_name: "FL_SLACK_DEFAULT_PAYLOADS",
                                       description: "Remove some of the default payloads. More information about the available payloads on GitHub",
                                       optional: true,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :attachment_properties,
                                       env_name: "FL_SLACK_ATTACHMENT_PROPERTIES",
                                       description: "Merge additional properties in the slack attachment, see https://api.slack.com/docs/attachments",
                                       default_value: {},
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :success,
                                       env_name: "FL_SLACK_SUCCESS",
                                       description: "Was this build successful? (true/false)",
                                       optional: true,
                                       default_value: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :fail_on_error,
                                       env_name: "FL_SLACK_FAIL_ON_ERROR",
                                       description: "Should an error sending the slack notification cause a failure? (true/false)",
                                       optional: true,
                                       default_value: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :link_names,
                                       env_name: "FL_SLACK_LINK_NAMES",
                                       description: "Find and link channel names and usernames (true/false)",
                                       optional: true,
                                       default_value: false,
                                       is_string: false)
        ]
      end

      def self.author
        "KrauseFx"
      end

      def self.example_code
        [
          'slack(message: "App successfully released!")',
          'slack(
            message: "App successfully released!",
            channel: "#channel",  # Optional, by default will post to the default channel configured for the POST URL.
            success: true,        # Optional, defaults to true.
            payload: {            # Optional, lets you specify any number of your own Slack attachments.
              "Build Date" => Time.new.to_s,
              "Built by" => "Jenkins",
            },
            default_payloads: [:git_branch, :git_author], # Optional, lets you specify a whitelist of default payloads to include. Pass an empty array to suppress all the default payloads.
                                                          # Don\'t add this key, or pass nil, if you want all the default payloads. The available default payloads are: `lane`, `test_result`, `git_branch`, `git_author`, `last_git_commit`, `last_git_commit_hash`.
            attachment_properties: { # Optional, lets you specify any other properties available for attachments in the slack API (see https://api.slack.com/docs/attachments).
                                     # This hash is deep merged with the existing properties set using the other properties above. This allows your own fields properties to be appended to the existing fields that were created using the `payload` property for instance.
              thumb_url: "http://example.com/path/to/thumb.png",
              fields: [{
                title: "My Field",
                value: "My Value",
                short: true
              }]
            }
          )'
        ]
      end

      def self.category
        :notifications
      end

      def self.details
        "Create an Incoming WebHook and export this as `SLACK_URL`. Can send a message to **#channel** (by default), a direct message to **@username** or a message to a private group **group** with success (green) or failure (red) status."
      end
    end
  end
end
# rubocop:enable Style/CaseEquality
# rubocop:enable Style/MultilineTernaryOperator
# rubocop:enable Style/NestedTernaryOperator
