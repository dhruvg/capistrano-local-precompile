require 'capistrano'

module Capistrano
  module LocalPrecompile

    def self.load_into(configuration)
      configuration.load do

        set(:precompile_cmd)   { "#{rake} assets:precompile" }
        set(:cleanexpired_cmd) { "#{rake} assets:clean_expired" }
        set(:assets_dir)       { "public/assets" }

        set(:turbosprockets_enabled)    { false }
        set(:turbosprockets_backup_dir) { "public/.assets" }
        set(:rsync_cmd)                 { "rsync -ave \"ssh -i #{ssh_options[:keys].first}\"" }

        before "deploy", "deploy:assets:prepare"
        before "deploy:create_symlink", "deploy:assets:precompile"
        after "deploy:assets:precompile", "deploy:assets:cleanup"

        namespace :deploy do
          namespace :assets do

            task :cleanup, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_locally "mv #{fetch(:assets_dir)} #{fetch(:turbosprockets_backup_dir)}"
              else
                run_locally "rm -rf #{fetch(:assets_dir)}"
              end
            end

            task :prepare, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_locally "mkdir -p #{fetch(:turbosprockets_backup_dir)}"
                run_locally "mv #{fetch(:turbosprockets_backup_dir)} #{fetch(:assets_dir)}"
                run_locally "#{fetch(:cleanexpired_cmd)}"
              end
	      # Cleanup .css and .map files in stylesheets before precompiling. The files we care about are all *.scss now.
              run_locally "find app/assets/stylesheets/ -name '*.css' -type f -delete"
              run_locally "find app/assets/stylesheets/ -name '*.map' -type f -delete"
              run_locally "#{fetch(:precompile_cmd)}"
            end

            desc "Precompile assets locally and then rsync to app servers"
            task :precompile, :only => { :primary => true }, :on_no_matching_servers => :continue do

              local_manifest_path = run_locally "ls #{assets_dir}/manifest*"
              local_manifest_path.strip!

              servers = find_servers :roles => :app, :except => { :no_release => true }
              servers.each do |srvr|
                run_locally "#{fetch(:rsync_cmd)} ./#{fetch(:assets_dir)}/ #{user}@#{srvr}:#{release_path}/#{fetch(:assets_dir)}/"
                run_locally "#{fetch(:rsync_cmd)} ./#{local_manifest_path} #{user}@#{srvr}:#{release_path}/assets_manifest#{File.extname(local_manifest_path)}"
              end
            end
          end
        end
      end
    end

  end
end

if Capistrano::Configuration.instance
  Capistrano::LocalPrecompile.load_into(Capistrano::Configuration.instance)
end
