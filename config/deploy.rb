# config valid only for current version of Capistrano
lock '3.3.5'

set :application, 'platform'
set :repo_url, 'https://github.com/wata-gh/platform.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

set :deploy_to, '/opt/bizevo/platform'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('bin', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

framework_tasks = [:starting, :started, :updating, :updated, :publishing, :published, :finishing, :finished]

framework_tasks.each do |t|
  Rake::Task["deploy:#{t}"].clear
end

Rake::Task[:deploy].clear

namespace :deploy do

  def graceful_unicorn
    pid_path = fetch :pid_path
    deploy_to = fetch :deploy_to
    if test "[ -f #{pid_path} ]"
      info "working directory #{deploy_to}"
      execute "cd #{deploy_to}"
      info "sending signal to `cat #{pid_path}`"
      execute "kill -s USR2 `cat #{pid_path}`"
    end
  end

  def bundle_install(env)
    deploy_to = env + "_deploy_to"
    deploy_from = env + "_deploy_from"
    execute "cp -pr #{fetch deploy_from.to_sym}/* #{fetch deploy_to.to_sym}"
    execute "cd #{fetch deploy_to.to_sym} && \
             rbenv exec bundle install  --path vendor/bundle"
  end

  task :update do
    run_locally do
      app_name = fetch :application
#      execute "git pull" # always update for now.
#      if test "[ -d #{app_name} ]"
#        execute "cd #{app_name}; git pull"
#      else
#        execute "git clone #{fetch :repo_url} #{app_name}"
#      end
    end
  end

  task :archive => :update do
    run_locally do
      app_name = fetch :application
      archive_name = "#{app_name}.tar.gz"
      set :archive_name, archive_name
      archive_absolute_path = File.join(capture("cd ..; pwd").chomp, archive_name)
      set :archive_absolute_path, archive_absolute_path
      info app_name
      info archive_name
      info archive_absolute_path
      execute "cd .. && tar zcvf #{archive_name} #{app_name}"
    end
  end

  task :deploy => :archive do
    archive_path = fetch :archive_absolute_path
    archive_name = fetch :archive_name
    release_path = fetch :deploy_to
    #release_path = File.join(fetch(:deploy_to), fetch(:application))
    on roles :web do
      execute "mkdir -p #{release_path}" unless test "[ -d #{release_path} ]"
      info "uplading.. #{archive_path} -> #{release_path}"
      upload! archive_path, release_path
      info "extracting to #{release_path}"
      info "cd #{release_path}; tar zxvf #{archive_name}"
      execute "cd #{release_path}; tar zxvf #{archive_name}"
      info "graceful unicorn."
      graceful_unicorn
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end