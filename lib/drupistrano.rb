unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/multistage requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  # Drupal Customizations
  _cset(:normalize_asset_timestamps) { false }
  _cset(:site_uri)   { "default" }
  _cset(:drush_path) { "drush" }
  _cset(:drush_cmd)  { "#{drush_path} --uri=#{site_uri}" }
  _cset(:ispconfig)  { false }

  namespace :deploy do
    task :start do ; end
    task :stop do ; end
    task :restart do ; end

    desc "Backup the DB before this update"
    task :backup_db, :roles => :db do
      on_rollback { run "rm #{previous_release}/dump.sql" if previous_release }

      if previous_release
        run "cd #{previous_release} && #{drush_cmd} sql-dump > dump.sql"
      end
    end

    desc "Move default drupal files if they exist and symlink to shared path"
    task :move_default_files, :roles => :app do
      run <<-CMD
        if [ -d #{release_path}/sites/default/files ]; then \
          cd #{release_path}/sites/default && \
          rsync -avz files/ #{shared_path}/files && \
          rm -rf files; \
        fi; \
        cd #{release_path}/sites/default && ln -nsf ../../../../shared/files/ .
      CMD
    end

    desc "Copy site configuration into place"
    task :copy_configuration, :roles => :app do
      run <<-CMD
        if [ -f #{shared_path}/sites/#{site_uri}/settings.php ]; then \
          mkdir -p #{release_path}/sites/#{site_uri} && \
          cp #{shared_path}/sites/#{site_uri}/settings.php #{current_release}/sites/#{site_uri}/; \
        fi
      CMD
    end

    desc "Revert all features"
    task :revert_features, :roles => :app do
      run "cd #{current_release} && #{drush_cmd} -y features-revert-all"
    end

    desc "Clear all cache"
    task :clear_cache, :roles => :app do
      run "cd #{current_release} && #{drush_cmd} cache-clear all"
    end

    desc "Execute database updates"
    task :migrate, :roles => :db do
      run "cd #{current_release} && #{drush_cmd} -y updatedb"
    end

    # Rewrite symlink task to add support for ISPConfig
    desc <<-DESC
      Updates the symlink to the most recently deployed version. Capistrano works \
      by putting each new release of your application in its own directory. When \
      you deploy a new version, this task's job is to update the `current' symlink \
      to point at the new version. You will rarely need to call this task \
      directly; instead, use the `deploy' task (which performs a complete \
      deploy, including `restart') or the 'update' task (which does everything \
      except `restart').
    DESC
    task :symlink, :except => { :no_release => true } do
      if ispconfig
        previous_normalized = previous_release.gsub(deploy_to, '').gsub(/^\//,'')
        latest_normalized = latest_release.gsub(deploy_to, '').gsub(/^\//,'')

        rollback_cmd = "rm -f #{current_path}; cd #{deploy_to} && ln -s #{previous_normalized} current; true"
        symlink_cmd = "rm -f #{current_path}; cd #{deploy_to} && ln -s #{latest_normalized} current"
      else
        rollback_cmd = "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true"
        symlink_cmd = "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
      end

      on_rollback do
        if previous_release
          run rollback_cmd
        else
          logger.important "no previous release to rollback to, rollback of symlink skipped"
        end
      end

      run symlink_cmd
    end
  end

  # Hooks
  after "deploy:update_code", "deploy:copy_configuration"

  before "deploy:symlink", "deploy:backup_db"
  before "deploy:symlink", "deploy:move_default_files"
  before "deploy:symlink", "deploy:revert_features"
  before "deploy:symlink", "deploy:clear_cache"
end
