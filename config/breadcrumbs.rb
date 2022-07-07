crumb :root do
  link 'Home', root_path
end

# Issue list
crumb :apps do
  link 'All apps', apps_path
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
  link 'App config', edit_app_app_config_path(config.app, config)
  parent :app, config.app
end

crumb :integrations do |app|
  link 'integrations', app_integrations_path(app)
  parent :app, app
end

crumb :sign_off_groups do |app|
  link 'Sign Off Config', app_sign_off_groups_path(app)
  parent :app, app
end

# crumb :projects do
#   link "Projects", projects_path
# end

# crumb :project do |project|
#   link project.name, project_path(project)
#   parent :projects
# end

# crumb :project_issues do |project|
#   link "Issues", project_issues_path(project)
#   parent :project, project
# end

# crumb :issue do |issue|
#   link issue.title, issue_path(issue)
#   parent :project_issues, issue.project
# end

# If you want to split your breadcrumbs configuration over multiple files, you
# can create a folder named `config/breadcrumbs` and put your configuration
# files there. All *.rb files (e.g. `frontend.rb` or `products.rb`) in that
# folder are loaded and reloaded automatically when you change them, just like
# this file (`config/breadcrumbs.rb`).
