class RScript
  require 'fileutils'
  attr_accessor :project_name
  
  def initialize
    @project_name = "test"
    @projects_dir = "/home/katateochi/coding/rails"  # Dir.getwd
    @project_dir = @projects_dir << "/#{@project_name}"
  end

  def make
    make_rails_app
    set_up_git_repo
    basic_welcome_controller
  end

  def make_rails_app
    system "rails #{@project_name}"
    in_project!
    FileUtils.remove_dir "#{@project_dir}/test"
  end

  def set_up_git_repo
    in_project!
    system "git init"
    git_add_and_commit "Initial Commit"
  end


  def basic_welcome_controller
    in_project! "config"
    modify_line_in "routes.rb", "  # map.root :controller => \"welcome\"\n", "  map.root :controller => \"welcome\"\n"
    in_project! "app/controllers"
    write_to "welcome_controller.rb", FileData.welcome_controller
    in_project! "app/views/welcome"
    write_to "index.haml", FileData.welcome_index
    in_project! "public"
    FileUtils.remove "index.html"
    in_project!
    git_add_and_commit "added welcome controller, welcome view and changed routes, removed public/index.htm/"
  end

  def in_project! sub_dir = nil
    dir = @project_dir
    dir = "#{@project_dir}/#{sub_dir}" if sub_dir
    FileUtils.mkpath dir #makes the path exist if it does not already
    FileUtils.chdir dir
  end

  def git_add_and_commit message
    system "git add ./"
    system "git commit -m '#{message}'"
  end

  def modify_line_in file, target_line, new_line
    f = File.open(file, 'r')
    new = f.map{|l| l.eql?(target_line) ? new_line : l}
    f.close
    f = File.open(file, 'w')
    f.write(new)
    f.close
  end

  def write_to file, data
    begin 
      f = File.open(file, "w")
    rescue
      FileUtils.touch file
      f = File.open(file, "w")
    end
    f.write(data)
    f.close
  end

end

class FileData
  def self.welcome_controller
     [
       "class WelcomeController < ApplicationController\n",
       "  skip_before_filter :require_login\n",
       "  def index\n",
       "  end\n",
       "end\n"
     ]
  end

  def self.welcome_index
    ["This is the welcome page" ]
  end

end

r = RScript.new
r.make

#TODO
#must add welcome controller and views
#authlogic, users and user_sessions
#hanl and sass
#remove unneeded specs.

