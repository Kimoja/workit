module Clients
  module GitRepositories
    extend self

    def build_from_config!
      git_repository_provider = Config.get('git_repository_provider')

      raise "Configuration parameter 'git_repository_provider' is required" if git_repository_provider.nil?

      case git_repository_provider
      when 'github'
        Clients::GitRepositories::Github.build_from_config!
      else
        raise "Unsupported git repository provider type: #{git_repository_provider}"
      end
    end
  end
end
