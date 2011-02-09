unless Capistrano::Configuration.respond_to?(:instance)
  abort "capistrano/ext/multistage requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  # Drupal Customizations
  _cset(:normalize_asset_timestamps) { false }
  _cset(:site_uri)   { "default" }
  _cset(:drush_path) { "drush" }
  _cset(:drush_cmd)  { "#{drush_path} --uri=#{site_uri}" }

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
        ln -nsf #{shared_path}/files .
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
    task :revert_features, :roles => :db do
      run "cd #{current_path} && #{drush_cmd} -y features-revert-all"
    end

    desc "Clear all cache"
    task :clear_cache, :roles => :app do
      run "cd #{current_path} && #{drush_cmd} cache-clear all"
    end

    desc "Execute database updates"
    task :migrate, :roles => :db do
      run "cd #{current_path} && #{drush_cmd} -y updatedb"
    end
  end

  # Hooks
  after "deploy:update_code", "deploy:copy_configuration"

  before "deploy:symlink", "deploy:backup_db"
  before "deploy:symlink", "deploy:move_default_files"
  before "deploy:symlink", "deploy:revert_features"
  before "deploy:symlink", "deploy:clear_cache"
end
