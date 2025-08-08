module Domain
  module Open
    extend self
    include Domain

    ### ACTIONS ###

    def browser_aliases(...)
      Workflows::Open::BrowserAliasesAction.call(...)
    end
  end
end
