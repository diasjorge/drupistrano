Capistrano::Configuration.instance.load do
  _cset(:previous_normalized) { previous_release.gsub(deploy_to, '').gsub(/^\//,'') }
  _cset(:latest_normalized) { latest_release.gsub(deploy_to, '').gsub(/^\//,'') }

  def symlink_configuration_cmd
    if ispconfig
      config_cmd = <<-CMD
          cd #{current_release}/sites/#{site_uri} && \
          ln -nsf ../../../../shared/sites/#{site_uri}/settings.php .
        CMD
    else
      config_cmd = "ln -nsf #{site_config_path}/settings.php #{current_release}/sites/#{site_uri}/"
    end
  end

  def symlink_execute_cmd
    if ispconfig
      "rm -f #{current_path}; cd #{deploy_to} && ln -s #{latest_normalized} current"
    else
      "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
    end
  end

  def symlink_rollback_cmd
    if ispconfig
      "rm -f #{current_path}; cd #{deploy_to} && ln -s #{previous_normalized} current; true"
    else
      "rm -f #{current_path}; ln -s #{previous_release} #{current_path}; true"
    end
  end

end
