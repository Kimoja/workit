
def config
  return @config if defined?(@config)

  unless File.exist?('config.json')
    log_error"Fichier 'config.json' de configuration introuvable"
    log ""
    log "Créez un fichier config.json avec la structure suivante:"
    log_json(
      {
        "jira" => {
          "url" => "https://votre-instance.atlassian.net",
          "email" => "votre.email@example.com",
          "token" => "VOTRE_TOKEN_API",
          "default_board" => "NOM_DU_BOARD",
          "assignee_name" => "Votre Nom",
          "issue_type" => "Tâche"
        },
        "github": {
          "token": "XXX"
        }
      }
    )
    exit 1
  end

  @config = json_to_ostruct(JSON.parse(File.read('config.json')))
end

def json_to_ostruct(obj)
  case obj
  when Hash
    OpenStruct.new(obj.transform_values { |v| json_to_ostruct(v) })
  when Array
    obj.map { |item| json_to_ostruct(item) }
  else
    obj
  end
end