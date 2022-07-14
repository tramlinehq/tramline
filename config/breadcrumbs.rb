crumb :root do
  link "Home", root_path
end

# Issue list
crumb :apps do
  link "All apps", apps_path
end

crumb :app do |app|
  link app.name, app_path(app)
  parent :apps
end

crumb :train do |train|
  link train.name, app_train_path(train.app, train)
  parent :app, train.app
end

crumb :step do |step|
  link step.name, app_train_steps_path(step.train.app, step.train)
  parent :train, step.train
end

crumb :release do |release|
  link release.release_version, app_train_releases_path(release.train.app, release.train)
  parent :train, release.train
end

crumb :app_config do |config|
  link "App config", edit_app_app_config_path(config.app, config)
  parent :app, config.app
end

crumb :integrations do |app|
  link "integrations", app_integrations_path(app)
  parent :app, app
end

crumb :sign_off_groups do |app|
  link "Sign Off Config", app_sign_off_groups_path(app)
  parent :app, app
end

crumb :new_train do |app|
  link "New Train"
  parent :app, app
end

crumb :edit_train do |train|
  link "Edit"
  parent :train, train
end
