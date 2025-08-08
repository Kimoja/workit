module Clients
  module Issues
    extend self

    def build_from_config!
      issue_provider = Utils::Config.get('issue_provider')

      raise "Configuration parameter 'issue_provider' is required" if issue_provider.nil?

      case issue_provider
      when 'jira'
        Clients::Issues::JiraClient.build_from_config!
      else
        raise "Unsupported issue provider type: #{issue_provider}"
      end
    end
  end
end
