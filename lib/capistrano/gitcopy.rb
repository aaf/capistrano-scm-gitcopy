load File.expand_path('../tasks/gitcopy.rake', __FILE__)

require 'capistrano/scm'

set_if_empty :local_path, -> { "/tmp/#{fetch(:application)}-repository/#{Time.now.to_i}" }

class Capistrano::GitCopy < Capistrano::SCM

  # execute git with argument in the context
  #
  def git(*args)
    args.unshift :git
    context.execute(*args)
  end

  module DefaultStrategy

    def check
      git :'ls-remote --heads', repo_url
    end

    def clone
      local_path = fetch(:local_path)
      options    = ['--verbose', '--mirror']

      if (depth = fetch(:git_shallow_clone))
       options.concat(['--depth', depth, '--no-single-branch'])
      end

      if File.exist?('~/.git-templates/hooks/post-checkout')
        options.concat(['--template', '~/.git-templates'])
      end

      options.concat([repo_url, local_path])

      git *options.unshift(:clone)
  end

  def update
    # Note: Requires git version 1.9 or greater
    if (depth = fetch(:git_shallow_clone))
      git :fetch, '--depth', depth, 'origin', fetch(:branch)
    else
      git :remote, :update
    end
  end

  def fetch_revision
    context.capture(:git, "rev-list --max-count=1 --abbrev-commit --abbrev=12 #{fetch(:branch)}")
  end

  def local_tarfile
    "#{fetch(:tmp_dir)}/#{fetch(:application)}-#{fetch(:current_revision).strip}.tar.gz"
  end

  def remote_tarfile
    "#{fetch(:tmp_dir)}/#{fetch(:application)}-#{fetch(:current_revision).strip}.tar.gz"
  end

  def release
    if (tree = fetch(:repo_tree))
      tree       = tree.slice %r#^/?(.*?)/?$#, 1
      components = tree.split('/').size
      git :archive, fetch(:branch), tree, '--format', 'tar', "|gzip > #{local_tarfile}"
    else
      git :archive, fetch(:branch), '--format', 'tar', "|gzip > #{local_tarfile}"
    end
  end
end

end
