require 'drupistrano/commands'

Capistrano::Configuration.instance.load do
  # User configurable
  _cset(:site_uri)   { "default" }
  _cset(:drush_path) { "drush" }
  _cset(:ispconfig)  { false }

  # Change at your own risk
  _cset(:normalize_asset_timestamps) { false }
  _cset(:drush_cmd)  { "#{drush_path} --uri=#{site_uri}" }
  _cset(:site_config_path) { "#{shared_path}/sites/#{site_uri}" }

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

    desc "Symlink site configuration into place"
    task :symlink_configuration, :roles => :app do
      run <<-CMD
        if [ -f #{site_config_path}/settings.php ]; then \
          mkdir -p #{release_path}/sites/#{site_uri} && \
          #{symlink_configuration_cmd}; \
        fi
      CMD
    end

    desc "Execute database updates"
    task :migrate, :roles => :db do
      run "cd #{current_release} && #{drush_cmd} -y updatedb"
    end

    desc "Setup configuration"
    task :setup_configuration, :roles => :app do
      run "mkdir -p #{site_config_path} && mkdir -p #{shared_path}/files"
      top.upload File.join('sites', 'default', 'default.settings.php'),
                 File.join(site_config_path, 'settings.php')
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
      on_rollback do
        if previous_release
          run symlink_rollback_cmd
        else
          logger.important "no previous release to rollback to, rollback of symlink skipped"
        end
      end

      run symlink_execute_cmd
    end
  end

  namespace :drupal do
    desc "Execute a drush command remotely"
    task :drush, :roles => :app, :once => true do
      cmd = ENV["CMD"] || ""
      abort "Please specify a command (via the FILES environment variable)" if cmd.empty?
      run "cd #{current_release} && #{drush_cmd} -y #{cmd}"
    end

    desc "Revert all features"
    task :revert_features, :roles => :app do
      if previous_release
        run "cd #{current_release} && #{drush_cmd} -y features-revert-all"
      end
    end

    desc "Clear all cache"
    task :clear_cache, :roles => :app do
      if previous_release
        run "cd #{current_release} && #{drush_cmd} cache-clear all"
      end
    end

    namespace :files do
      desc "Synchronize local files with remote server"
      task :pull, :roles => :app, :once => true do
        server = find_servers_for_task(current_task).first
        server_user = server.user || user
        system "rsync -avz #{server_user}@#{server.host}:#{shared_path}/files/ sites/default/files"
      end
    end

    namespace :db do
      desc "Download DB dump from server to local machine"
      task :pull, :roles => :db, :once => true do
        Capistrano::CLI.ui.say("You are about to import the DB from the #{stage} server")

        agree = Capistrano::CLI.ui.agree("Continue (Yes, [No]) ") do |q|
          q.default = 'n'
        end

        exit unless agree

        deploy.clear_cache

        run "cd #{current_release}; #{drush_cmd} sql-dump > /tmp/dump.sql"

        download("/tmp/dump.sql", "/tmp/dump.sql")

        system "drush -y sql-drop"
        system "drush sql-cli < /tmp/dump.sql"
      end

      desc "Copy local Database to remote server"
      task :push, :roles => :db, :once => true do
        Capistrano::CLI.ui.say <<-MSG
**************************** DANGER *****************************
*** You are about to EXPORT your DB to the #{stage} server ***
*****************************************************************
MSG

        agree = Capistrano::CLI.ui.agree("Continue (Yes, [No]) ") do |q|
          q.validate = /\Ayes?|no?\Z/i
          q.default  = 'n'
        end

        exit unless agree

        system "drush cc all; drush sql-dump > /tmp/dump.sql"
        top.upload("/tmp/dump.sql", "/tmp/dump.sql")
        run "cd #{current_release} && #{drush_cmd} sql-cli < /tmp/dump.sql"
      end
    end
  end
end
