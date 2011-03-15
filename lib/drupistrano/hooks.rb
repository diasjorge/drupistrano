Capistrano::Configuration.instance.load do
  # Hooks
  after "deploy:update_code", "deploy:symlink_configuration"

  before "deploy:symlink", "drupal:clear_cache"
  before "deploy:symlink", "deploy:backup_db"
  before "deploy:symlink", "deploy:move_default_files"
  before "deploy:symlink", "drupal:revert_features"
end
