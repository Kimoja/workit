module Domain
  module Workflows
    class SetupNoteFromGitBranchAction
      include Action

      attr_reader(
        :issue_client
      )

      def call
        summary

        note_path = find_existing_note || create_note

        Open.file_code(note_path)
        report(note_path)
      end

      private

      def summary
        Log.start 'Setup Note from Git Branch'
        Log.pad "Branch: #{branch}"
        if issue
          Log.pad "Related Issue: #{issue.key}"
        else
          Log.pad "No related issue found"
        end
        Log.log ''
      end

      memo def branch
        Git.current_branch
      end

      memo def normalized_branch
        branch.gsub('/', '_')
      end

      memo def issue
        Workflows.find_issue_for_branch(branch, issue_client)
      end

      memo def notes_dir
        File.join(Dir.pwd, '.workspace', 'branch_notes')
      end

      def find_existing_note
        Log.info "Searching for existing note..."
        
        pattern = File.join(notes_dir, "*-#{normalized_branch}")

        Dir.glob(pattern)
           .select { |path| File.directory?(path) }
           .each do |dir|
             index_file = File.join(dir, 'index.md')
             if File.exist?(index_file)
               Log.success "✓ Found existing note"
               Log.pad "Location: #{File.relative_path(index_file)}"
               return index_file.to_s
             end
           end

        Log.info "No existing note found - creating new one"
        nil
      end

      def create_note
        Log.info "Creating new branch note..."

        date = Time.now.strftime('%Y-%m-%d')
        folder_name = "#{date}-#{normalized_branch}"
        note_dir = File.join(notes_dir, folder_name)
        index_file = File.join(note_dir, 'index.md')

        Log.info "Creating directory: #{File.relative_path(note_dir)}"
        FileUtils.mkdir_p(note_dir)

        # Créer le contenu du fichier
        Log.info "Generating note content..."
        content = generate_note_content

        File.write(index_file, content)
        Log.success "✓ Note created successfully"

        index_file
      end

      def generate_note_content
        Log.info "Including branch and commit information"
        
        content = <<~MARKDOWN
          # Work Notes - #{branch}
        MARKDOWN

        # Ajouter les informations de l'issue si trouvée
        if issue
          Log.info "Including issue details: #{issue.key}"
          content += <<~MARKDOWN
            ## Related Issue

            **Issue:** [#{issue.key}](#{issue.url})
            **Title:** #{issue.title}
            **Type:** #{issue.issue_type}

            ### Issue Description
            #{issue.description || 'No description available'}

          MARKDOWN
        end

        content
      end

      def report(note_path)
        Log.success "Branch note ready!"
        Log.pad "File: #{File.relative_path(note_path)}"
        Log.pad "Opening in code editor..."
      end
    end
  end
end