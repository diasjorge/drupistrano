Capistrano::Configuration.instance.load do
  # Hooks
  after "deploy:update_code", "deploy:symlink_configuration"

  before "deploy:symlink", "deploy:clear_cache"
  before "deploy:symlink", "deploy:backup_db"
  before "deploy:symlink", "deploy:move_default_files"
  before "deploy:symlink", "deploy:revert_features"
end
