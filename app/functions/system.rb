module Functions
  module System
    extend self
    include Functions

    ### ACTIONS ###

    def open_browser_aliases(alias_names)
      OpenBrowserAliasesAction.call(alias_names:)
    end

    def open_folder_aliases(alias_names)
      OpenFolderAliasesAction.call(alias_names:)
    end
  end
end
