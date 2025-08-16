module Domain
  module Open
    extend self
    include Domain

    ### ACTIONS ###

    def browser_aliases(alias_names)
      Workflows::Open::BrowserAliasesAction.call(alias_names:)
    end

    def folder_aliases(alias_names)
      Workflows::Open::FolderAliasesAction.call(alias_names:)
    end
  end
end
