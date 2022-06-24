crumb :root do
  link 'Home', root_path
end

# Issue list
crumb :apps do
  link 'All apps', accounts_organization_apps_path(current_organization)
end

crumb :app do |app|
  link app.name, accounts_organization_apps_path(app.organization, app)
  parent :apps
end

crumb :train do |train|
  link train.name, accounts_organization_app_releases_train_path(current_organization, train.app)
  parent :app, train.app
end

crumb :step do |step|
  link step.name, accounts_organization_app_releases_train_steps_path(current_organization, step.train.app, step.train)
  parent :train, step.train
end

crumb :release do |release|
  link release.branch_name, accounts_organization_app_releases_train_releases_path(current_organization, release.train.app, release.train)
  parent :train, release.train
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
