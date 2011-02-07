# Drupal Deployment Recipe
* Requirements
  * You need drush installed on your project
* Current Features:
  * Revert all features
  * Backup database prior to deploy
  * Handle sites/default/files across releases
  * Clear cache
  * Database updates

## Configuration Variables

* site_uri: Uri of the site as in sites/all/. Eg. example.com. Default Value: default
* drush_path: Drush Command to use. Eg. "/opt/bin/drush". Default Value: drush
