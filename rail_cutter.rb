class RailCutter
  require 'rubygems'
  require 'fileutils'
  attr_accessor :project_name

  def self.new_project name = "test"
    rc = RailCutter.new(name, Dir.getwd)
    rc.make_all
  end

  def initialize name, path 
    @project_name = name
    @projects_dir = path 
    @project_dir = @projects_dir << "/#{@project_name}"
    @files = FileData.new(@project_name)
  end

  def make_all
    make_basic_rails_app
    add_customization
    replace_with_server
  end

  def make_basic_rails_app
    #Basic Rails App
    make_rails_app
    set_up_git_repo
    install_gems(["haml", "json", "fastercsv"]) #authlogic gem added during the authlogic step
    install_haml
  end

  def add_customization
    #Customisation
    setup_welcome_controller
    setup_layout
    install_jrails
    install_scaffolds( {:sexy_scaffold => "git://github.com/Sujimichi/sexy_scaffold.git"})
    install_authlogic
    make_model "llama", {:name => :string, :spitting_distance => :float, :leathal => :boolean, :description => :text}
  
  end

  def make_rails_app
    message "Creating Rails App for project: '#{@project_name}'"
    system "rails #{@project_name} -q"
    in_project!
    FileUtils.remove_dir "#{@project_dir}/test"
  end

  def set_up_git_repo
    message "Initializing Git Repo"
    in_project!
    system "git init"
    git_add_and_commit "Initial Commit"
  end

  def git_add_and_commit message
    message "commiting", 2
    in_project!
    system "git add -u"
    system "git add ./" #both so that additions and deletions are tracked
    system "git commit -m '#{message}' -q"
  end

  def message text, indent = 0
    puts "\n#{Array.new(text.length+10){"#"}.to_s}" if indent.eql?(0)
    indt = Array.new(indent){"."}.to_s
    puts "#{indt}#{text}\n"
  end

  def setup_welcome_controller
    message "Adding Welcome Controller and Views"
    in_project!("config") { alter_line_in "routes.rb", "# map.root :controller", "map.root :controller" } # uncomment line in routes
    in_project!("app/controllers") { write_to "welcome_controller.rb", @files.welcome_controller }        # create welcome controller
    in_project!("app/views/welcome") { write_to "index.haml", @files.welcome_index }                      # create welcome index
    in_project! "public" do 
      FileUtils.touch "index.html"  #touched incase its not there
      FileUtils.remove "index.html" #deleted
    end
    git_add_and_commit "added welcome controller, welcome view and changed routes, removed public/index.htm/"
  end

  def setup_layout
    message "Adding basic layout (main.haml) in 'app/views/layouts'"
    in_project!("app/views/layouts") { write_to "main.haml", @files.main_haml }                                       #create layout file
    in_project!("app/controllers") { insert_line_after_in "application_controller.rb", :line6, "  layout 'main'\n" }  #specify layout in application contoller
    git_add_and_commit "Added basic layouts in views/layouts"
  end

  def install_gems gems
    message "Adding gem dependencys and installing: #{gems.map{|g| g}.join(", ")}", 2
    gem_string = gems.map{|g| "  config.gem '#{g}'"}.join("\n")
    target = "  # Specify gems that this application depends on and have them installed with rake gems:install\n" #line to follow in config.rb
    in_project!("config") { insert_line_after_in "environment.rb", target, "#{gem_string}\n" }                    #add gem dependencies after above line
    git_add_and_commit "Added gems to environment.rb: #{gems.map{|g| g}}"
    system "rake gems:install"
  end

  def install_haml
    message "Installing HAML and SASS"
    in_project! { system "haml --rails ./" }
    in_project! "app/stylesheets" do 
      write_to "layout.sass", @files.layout_sass  #create sass files
      write_to "utils.sass", @files.utils_sass
    end
    in_project!("config/initializers") { write_to "sass.rb", @files.sass_rb }
    #why do I need to do this?  should this not be setup with the install of haml?  this step is not memtioned in haml docs but without it css is not made from sass.
    git_add_and_commit "Added Haml and SASS"
  end

  def install_jrails
    message "Installing jrails with Jquery-ui"
    version = "1.7.2"
    download_and_unpack_jquery_ui "http://jqueryui.com/download/jquery-ui-#{version}.custom.zip"

    in_project! do 
      message "installing jrails" ,2
      plugin "http://ennerchi.googlecode.com/svn/trunk/plugins/jrails"
      message "adding css and javascripts", 2
      system "cp ./temp/jquery/css/smoothness ./public/stylesheets/ -r"             #copy css from downloaded jqueryui to stylesheets
      system "cp ./temp/jquery/js/jquery-ui*.js ./public/javascripts/jquery-ui.js"  #copy javascripts from jquery
      FileUtils.remove_dir "#{@project_dir}/temp"                                   #clean up
    end
    style_sheet_line = "    = stylesheet_link_tag 'smoothness/jquery-ui-#{version}.custom.css', :rel => \"Stylesheet\"\n"
    in_project!("app/views/layouts") { insert_line_after_in "main.haml", "  %head\n", style_sheet_line }    #add stylesheet_link_tag to layout
    git_add_and_commit "Added jrails with Jquery-ui"
  end

  def install_authlogic
    message "Installing Authlogic"
    install_gems(["authlogic"])

    message "scaffolding user_sessions and users", 2
    in_project! do 
      system "ruby script/generate session user_session -q" #generate authlogic user_session
      system "ruby script/generate sexy_scaffold user login:string email:string crypted_password:string password_salt:string -q" # generate user 
    end

    message "modifying migration and routes", 2
    file = 
    in_project!("db/migrate") do 
      file = Dir.entries(Dir.getwd).select{|ent| ent.include?("create_users")}.first                        #get users migration
      insert_line_after_in file, "      t.string :password_salt\n", "      t.string :persistence_token\n"   #add to migration after scaffold so as to exclude from views
    end
    in_project!("config") { insert_line_after_in "routes.rb", :line0, @files.authlogic_patch_for_routes }   #add authlogic routes

    message "modifying user user_model", 2
    in_project!("app/models") { insert_line_after_in "user.rb", :line0, "  acts_as_authentic\n" }           #made user act as authentic

    message "modifying users, user_sessions, welcome and application controllers", 2
    in_project! "app/controllers" do 
      write_to "users_controller.rb", @files.users_controller                                               #create users controller
      write_to "user_sessions_controller.rb", @files.user_sessions_controller                               #create user_sessions controller
      insert_line_after_in "application_controller.rb", "  # filter_parameter_logging :password\n", @files.authlogic_patch_for_application_controller #add authlogic methods to application controller
      insert_line_after_in "welcome_controller.rb", :line0,  "  skip_before_filter :require_login\n"        #skip the before filter on the welcome controller
    end

    message "modifying layouts, users views and welcome page", 2
    in_project!("app/views/layouts") { insert_line_after_in "main.haml", "        .links\n", @files.authlogic_patch_for_layouts_main } #add register/logout links to layout
    in_project! "app/views/users" do 
      alter_line_in "_form.haml", "f.label :crypted_password", "f.label :password"                          #scaffold results in passwords being unsecure
      alter_line_in "_form.haml", "f.text_field :crypted_password", "f.password_field :password"            #authlogic provides the means to secure password entry
      alter_line_in "_form.haml", "f.label :password_salt", "f.label :password_confirmation"                #replacing text_field with password_field
      alter_line_in "_form.haml", "f.text_field :password_salt", "f.password_field :password_confirmation"  #instances of crypted_password and password salt changed
    end
    in_project!("app/views/welcome") { write_to "index.haml", @files.authlogic_welcome_index }              #replace the simple index with one that has login form
    migrate!
    git_add_and_commit "Added Authlogic with User model, setup controllers and views for basic user create and login"
  end

  def install_scaffolds scaffolds
    message "Installing scaffolds"
    in_project! { scaffolds.each{|name, scaffold| plugin scaffold} }
    git_add_and_commit "Added Scaffolds"
  end

  def plugin plugin
    plugin = plugin.frist.last if plugin.is_a? Hash
    name = plugin.frist.first if plugin.is_a? Hash
    name ||= plugin
    message "installing plugin: #{name}", 4
    system "ruby script/plugin install #{plugin} -q"
  end
 
  def download_and_unpack_jquery_ui url
    require 'open-uri'
    require 'fileutils'
    require 'zip/zip'
    require 'zip/zipfilesystem'
    
    in_project! "temp"
    message "Downloading Jquery", 2
    File.open("jquery.zip", "wb"){|f| f.write( open(url).read ) } #open uri opens the uri and result is saved to disk (potential security issue as i think it will just read whatever)

    message "Unpacking Jquery", 2
    Zip::ZipFile.open("jquery.zip") do |zip_file|
      zip_file.each do |f|
        f_path=File.join("jquery", f.name) 
        FileUtils.mkdir_p(File.dirname(f_path))                 #create the path for file (without which next line fails
        zip_file.extract(f, f_path) unless File.exist?(f_path)  # extract the file
      end
    end
  end

  def make_model name, attributes
    message "Making Models"
    system "ruby script/generate sexy_scaffold #{name} #{attributes.map{|k,v| "#{k}:#{v}" }.join(" ")} -q"
    migrate!
  end

  def replace_with_server
    message "Rails App: #{@project_name} setup complete, launching server"
    in_project!
    Kernel.exec("ruby script/server") # Kernel.exec does same as system only current process is replaced with executed one
  end

  def in_project! sub_dir = nil, &block
    dir = @project_dir
    dir = "#{@project_dir}/#{sub_dir}" if sub_dir
    FileUtils.mkpath dir #makes the path exist if it does not already
    FileUtils.chdir dir
    yield if block
  end
  alias in_project in_project!

  def migrate!
    in_project!
    message "migrating", 2
    system "rake db:migrate"
  end

  def alter_line_in file, target, change
    f = File.open(file, 'r')
    new = f.map{|l| l.include?(target) ? l.sub(target, change) : l}
    f.close
    write_to file, new
    message "changed line in #{file}", 2
  end

  def insert_line_after_in file, target_line, m
    f = File.open(file, 'r')
    data = f.map
    f.close
    i = data.index(target_line) if target_line.is_a? String
    i = target_line.to_s.sub("line", "").to_i if target_line.is_a? Symbol
    s = data[0..(i)]
    e = data[(i+1)..(data.size-1)]
    write_to file, ([s,m,e].flatten)
    message "added line to #{file}", 2
  end

  def write_to file, data
    begin
      File.open(file, "w") {|f| f.write(data) }
    rescue
      FileUtils.touch file
      write_to file, data
    end
  end

end


#FILE DATA
class FileData
  def initialize name
    @project_name = name
  end

  def make_array_from_file file
    #how to generate arrays from file
    f = File.open file, "r"
    data = f.map
    f.close
    puts data.map {|j|  "#{j.inspect},"}
  end


  def authlogic_welcome_index
    [
      "-if current_user\n",
      "  .centered\n",
      "    .widget\n",
      "      %p= \"Logged in as \#{current_user.login}\"\n",
      "\n",
      "- unless current_user\n",
      "  .centered\n",
      "    .widget{:id => 'login_widget'}\n",
      "      - form_for UserSession.new do |f|\n",
      "        - f.error_messages\n",
      "        %br\n",
      "        .css_table\n",
      "          .label= f.label :login\n",
      "          .value= f.text_field :login\n",
      "        .css_table\n",
      "          .label= f.label :password\n",
      "          .value= f.password_field :password\n",
      "        .clear\n",
      "        .login_bttn=f.submit(\"Login\")\n",
      "        %br"
   ]
  end

  def authlogic_patch_for_layouts_main
    [
      "          - unless current_user\n",
      "            = link_to \"register\", new_user_path\n",
      "          - if current_user\n",
      "            .right.small\n",
      "              = link_to \"logout (\#{current_user.login})\", logout_path, :onmousedown => \"$('#content').fadeOut()\"\n",
      "              = link_to \"edit\", edit_user_path(:current)\n",
      "            .clear\n"
    ]
  end

  def authlogic_patch_for_routes
    [
      "  map.resources :user_sessions\n",
      "  map.login 'login', :controller => 'user_sessions', :action => 'new'\n",
      "  map.logout 'logout', :controller => 'user_sessions', :action => 'destroy'\n"
    ]
  end

  def authlogic_patch_for_application_controller
    [
      "  require 'authlogic'\n",
      "  before_filter :require_login\n",
      "  filter_parameter_logging :password\n",
      "  helper_method :current_user\n",
      "  private\n",
      "\n",
      "  def current_user_session\n",
      "    return @current_user_session if defined?(@current_user_session)\n",
      "    @current_user_session = UserSession.find\n",
      "  end\n",
      "\n",
      "  def current_user\n",
      "    return @current_user if defined?(@current_user)\n",
      "    @current_user = current_user_session && current_user_session.record\n",
      "  end\n",
      "\n",
      "  def logged_in?\n",
      "    return true if current_user\n",
      "    false\n",
      "  end\n",
      "\n",
      "  def authentication_failed!\n",
      "    store_location\n",
      "    flash[:notice] = \"You must be logged in\"\n",
      "    redirect_to root_url\n",
      "  end\n",
      "\n",
      "  def not_allowed! redirect = root_url\n",
      "    flash[:error] = \"You cannot access this\"\n",
      "    redirect_to redirect and return\n",
      "  end\n",
      "\n",
      "  def not_found! redirect = root_url\n",
      "    flash[:notice] = \"The requested item can not be found\"\n",
      "    redirect_to redirect and return\n",
      "  end\n",
      "\n",
      "  def require_login\n",
      "    return authentication_failed! unless current_user\n",
      "  end\n",
      "\n",
      "  def store_location\n",
      "    session[:return_to] = request.request_uri\n",
      "  end\n",
      "\n",
      "  def redirect_back_or_default(default = root_url)\n",
      "    redirect_to(session[:return_to] || default)\n",
      "    session[:return_to] = nil\n",
      "  end\n"
    ]

  end

  def users_controller
    [
      "class UsersController < ApplicationController\n",
      "  skip_before_filter :require_login, :only => [:new, :create]\n",
      "\n",
      "  def new\n",
      "    @user = User.new\n",
      "  end\n",
      "\n",
      "  def create\n",
      "    @user = User.new(params[:user])\n",
      "    if @user.save\n",
      "      flash[:notice] = \"Registration successful.\"\n",
      "      redirect_to root_url\n",
      "    else\n",
      "      render :action => 'new'\n",
      "    end\n",
      "  end\n",
      "\n",
      "  def edit\n",
      "    @user = current_user\n",
      "  end\n",
      "\n",
      "  def update\n",
      "    @user = current_user\n",
      "    if @user.update_attributes(params[:user])\n",
      "      flash[:notice] = \"Successfully updated profile.\"\n",
      "      redirect_to root_url\n",
      "    else\n",
      "      render :action => 'edit'\n",
      "    end\n",
      "  end  \n",
      "\n",
      "end"
    ]

  end

  def user_sessions_controller
    [
      "class UserSessionsController < ApplicationController\n",
      "  skip_before_filter :require_login, :just => [:new]\n",
      "\n",
      "  def new\n",
      "    @user_session = UserSession.new\n",
      "  end\n",
      "\n",
      "  def create\n",
      "    @user_session = UserSession.new(params[:user_session])\n",
      "    if @user_session.save\n",
      "      flash[:notice] = \"Oh, U again is it?\"\n",
      "      redirect_to root_url\n",
      "    else\n",
      "      flash[:error] = \"hmmm, I dont like you\"\n",
      "      redirect_to root_url\n",
      "    end\n",
      "  end\n",
      "\n",
      "  def destroy\n",
      "    @user_session = UserSession.find\n",
      "    @user_session.destroy\n",
      "    flash[:notice] = \"Successfully logged out.\"\n",
      "    redirect_to root_url\n",
      "  end\n",
      "\n",
      "end"
    ]

  end


  def welcome_controller
    [
      "class WelcomeController < ApplicationController\n",
      "  def index\n",
      "  end\n",
      "end\n"
    ]
  end

  def welcome_index
    [
      ".centered\n",
      "  .widget\n",
      "    %p This is the welcome page"
    ]
  end

  def main_haml
    [
      "!!!\n",
      "%html\n",
      "  %head\n",
      "    = stylesheet_link_tag 'utils.css', :media => 'screen, projection'\n",
      "    = stylesheet_link_tag 'layout.css', :media => 'screen, projection'\n",
      "    = javascript_include_tag \"application\", :defaults\n",
      "    <!--[if IE]><script language=\"javascript\" type=\"text/javascript\" src=\"excanvas.pack.js\"></script><![endif]-->\n",
      "\n",
      "    %title\n",
      "      #{@project_name.gsub("_", " ")}\n",
      "\n",
      "  %body\n",
      "    #body\n",
      "      #header\n",
      "        .title{:onmouseup => \"window.open('\#{root_url}', '_parent')\"}\n",
      "          #{@project_name.gsub("_", " ")}\n",
      "        .tag new rails site\n",
      "\n",
      "        .links\n",
      "\n",
      "      #content\n",
      "        - if flash[:error]\n",
      "          .flash_error= flash[:error]\n",
      "        - if flash[:notice]\n",
      "          .flash_notice= flash[:notice]\n",
      "\n",
      "        =yield\n",
      "\n",
      "      .clear\n",
      "      #footer\n",
      "        %h6 #{@project_name.gsub("_", " ")}.on_rails[:alpha]\n",
      "\n",
      ":javascript\n",
      "  function toggeler(link_div, state_1_div, state_2_div, state_1_text, state_2_text){\n",
      "    var opt = $('#' + link_div).html();\n",
      "    if (opt == state_1_text){\n",
      "      $('#' + state_1_div).hide('slow');\n",
      "      $('#' + state_2_div).show('slow');\n",
      "      $('#' + link_div).html(state_2_text);\n",
      "    }else{\n",
      "      $('#' + state_2_div).hide('slow');\n",
      "      $('#' + state_1_div).show('slow');\n",
      "      $('#' + link_div).html(state_1_text);\n",
      "    };\n",
      "  };\n"
    ]
  end

  def sass_rb
    [
      "unless %w[development test].include? RAILS_ENV\n",
      "  Sass::Plugin.options[:style] = :compressed\n",
      "end\n",
      "Sass::Plugin.options[:template_location] = \"\#{RAILS_ROOT}/app/stylesheets\"\n",
      "Sass::Plugin.options[:css_location] = \"\#{RAILS_ROOT}/public/stylesheets\""
    ]
  end

  def layout_sass
    [
      "=clearfix\n",
      "  :overflow auto\n",
      "  :overflow -moz-scrollbars-none\n",
      "  // This makes ie6 get layout\n",
      "  :display inline-block\n",
      "  // and this puts it back to block\n",
      "  &\n",
      "    :display block\n",
      "\n",
      "html\n",
      "  :background-color #363232\n",
      "  :min-width 1024px\n",
      "  :margin 0\n",
      "  :padding 0\n",
      "  :height 100%\n",
      "\n",
      "body\n",
      "  :margin 0\n",
      "  :padding 0\n",
      "  :height 100%\n",
      "  :font 1em sans-serif\n",
      "\n",
      "#body\n",
      "  :min-height 100%\n",
      "  :position relative\n",
      "  :font-size 100%\n",
      "\n",
      "=heading\n",
      "  :color #706a6a\n",
      "  :font\n",
      "    :weight bold\n",
      "\n",
      "\n",
      "a\n",
      "  :color #3d42a8\n",
      "  &:hover\n",
      "    :color blue\n",
      "\n",
      "\n",
      "h1\n",
      "  +heading\n",
      "  :font-size 200%\n",
      "\n",
      "h2\n",
      "  +heading\n",
      "  :font-size 150%\n",
      "\n",
      "h3\n",
      "  +heading\n",
      "  :font-size 120%\n",
      "\n",
      "h4\n",
      "  +heading\n",
      "  :font-size 100%\n",
      "\n",
      "h5\n",
      "  +heading\n",
      "  :font-size 80%\n",
      "\n",
      "h6\n",
      "  +heading\n",
      "  :font-size 60%\n",
      "\n",
      "#header\n",
      "  :width 100%\n",
      "  :background-color #302559\n",
      "  :min-width 1024px\n",
      "  :min-height 3.5em\n",
      "  :border-bottom 5px solid #4f2fcc\n",
      "\n",
      "  .title\n",
      "    :width 10em\n",
      "    :float left\n",
      "    :font-size 200%\n",
      "    :color #4d4a4f\n",
      "    :vertical-align middle\n",
      "    :padding\n",
      "      :top 10px\n",
      "      :left 10px\n",
      "\n",
      "\n",
      "  .tag\n",
      "    :padding\n",
      "      :top 28px\n",
      "    :color #4d4a4f\n",
      "    :float left\n",
      "    :font\n",
      "      :size 80%\n",
      "      :weight bold\n",
      "\n",
      "  .flash_holder\n",
      "    :margin\n",
      "      :top 0.5em\n",
      "      :left 1em\n",
      "    :float left\n",
      "    :width 50%\n",
      "\n",
      "  a\n",
      "    :color grey\n",
      "    &:hover\n",
      "      :color #4f2fcc\n",
      "\n",
      "  .links\n",
      "    :float right\n",
      "    :padding\n",
      "      :top 15px\n",
      "      :right 40px\n",
      "\n",
      "#content\n",
      "  :min-height 30em\n",
      "\n",
      "#footer\n",
      "  :border-top 2px solid black\n",
      "\n",
      "#sub_heading\n",
      "  :margin\n",
      "    :top 4px\n",
      "    :left 10px\n",
      "  .title\n",
      "    +heading\n",
      "    :font-size 150%\n",
      "    :margin-top 15px\n",
      "    :display inline\n",
      "\n",
      ".title\n",
      "  +heading\n",
      "  :font-size 150%\n",
      "\n",
      ".sub_title\n",
      "  +heading\n",
      "  :font-size 120%\n",
      "\n",
      "\n",
      "=info_text\n",
      "  +heading\n",
      "\n",
      ".info_text\n",
      "  +info_text\n"
    ]
  end

  def utils_sass
    [
      "=clearfix\n",
      "  :overflow auto\n",
      "  :overflow -moz-scrollbars-none\n",
      "  // This makes ie6 get layout\n",
      "  :display inline-block\n",
      "  // and this puts it back to block\n",
      "  &\n",
      "    :display block\n",
      "\n",
      "=rounded\n",
      "  -moz-border-radius: 8px; -webkit-border-radius: 8px; }\n",
      "  +clearfix\n",
      "\n",
      "=widget\n",
      "  :padding 0.5em\n",
      "  :width 96%\n",
      "  :float left\n",
      "  +clearfix\n",
      "\n",
      ".outer_widget\n",
      "  +widget\n",
      "  :margin\n",
      "    :top 5px\n",
      "    :left 10px\n",
      "\n",
      ".widget\n",
      "  +widget\n",
      "  :border 0.3em solid #4f2fcc\n",
      "  :background-color transparent\n",
      "\n",
      "  :margin-bottom 10px\n",
      "  +rounded\n",
      "\n",
      ".soft_widget\n",
      "  +widget\n",
      "  :margin-bottom 10px\n",
      "\n",
      ".edged_widget\n",
      "  +widget\n",
      "  :border 0.3em solid #4f2fcc\n",
      "  :padding 1em\n",
      "  +rounded\n",
      "\n",
      ".hanging_widget\n",
      "  +widget\n",
      "  :margin-left 1em\n",
      "  :border-bottom 0.2em solid #4f2fcc\n",
      "  :border-left 0.2em solid #4f2fcc\n",
      "  :border-right 0.2em solid #4f2fcc\n",
      "  :background-color #abb4ed\n",
      "  :width auto\n",
      "  -moz-border-radius:  0px 0px 8px 8px; -webkit-border-radius-bottom: 8px; }\n",
      "\n",
      "\n",
      "\n",
      "=flash\n",
      "  :color #666666\n",
      "  :border 2px solid #4f2fcc\n",
      "  :background-color #BCED91\n",
      "  :padding 10px\n",
      "  :text-align center\n",
      "  +clearfix\n",
      "\n",
      ".flash_error\n",
      "  +flash\n",
      "  :color #cc1111\n",
      "  :border 1px solid #ff8585\n",
      "  :background\n",
      "    :color #ffebeb\n",
      "  +rounded\n",
      "\n",
      ".flash_notice\n",
      "  +flash\n",
      "  +rounded\n",
      "\n",
      "\n",
      "\n",
      ".form_errors\n",
      "  :color #cc1111\n",
      "  :border 1px solid #ff8585\n",
      "  :background\n",
      "    :color #ffebeb\n",
      "  :padding 10px\n",
      "  :text-align left\n",
      "  :font-size 80%\n",
      "  :margin-bottom 1em\n",
      "  +rounded\n",
      "\n",
      ".inline_errors\n",
      "  :color #cc1111\n",
      "  :border 1px solid #ff8585\n",
      "  :background\n",
      "    :color #ffebeb\n",
      "  :padding 10px\n",
      "  :text-align center\n",
      "  :font-size 80%\n",
      "  :margin\n",
      "    :top 1em\n",
      "    :bottom 1em\n",
      "  +rounded\n",
      "\n",
      ".inline_notice\n",
      "  :color #666666\n",
      "  :border 1px solid #397D02\n",
      "  :background\n",
      "    :color #BCED91\n",
      "  :padding 10px\n",
      "  :text-align center\n",
      "  :font-size 80%\n",
      "  :margin\n",
      "    :top 1em\n",
      "    :bottom 1em\n",
      "  +rounded\n",
      "\n",
      "\n",
      ".two_col\n",
      "  :width 45%\n",
      "  :float left\n",
      "  :margin\n",
      "    :left 1.25%\n",
      "    :right 1.25%\n",
      "\n",
      ".split\n",
      "  :width 45%\n",
      "  :float left\n",
      "  :margin\n",
      "    :left 5px\n",
      "    :right 5px\n",
      "\n",
      ".centered\n",
      "  :width 45%\n",
      "  :margin 0 auto\n",
      "\n",
      ".clear\n",
      "  :display block\n",
      "  :clear both\n",
      "  :height 0\n",
      "  :width 0\n",
      "\n",
      "=label\n",
      "  :color #706a6a\n",
      "  :font\n",
      "    :weight bold\n",
      "\n",
      ".label\n",
      "  +label\n",
      "\n",
      ".css_table\n",
      "  :display table-row\n",
      "  .label\n",
      "    :display table-cell\n",
      "    :padding-left 1em\n",
      "    +label\n",
      "  .value\n",
      "    :display table-cell\n",
      "    :padding-left 1em\n",
      "\n",
      ".left\n",
      "  :float left\n",
      "\n",
      ".right\n",
      "  :float right\n",
      "\n",
      ".with_margin\n",
      "  :margin-left 1em\n",
      "\n",
      ".small\n",
      "  :font-size 80%\n",
      "\n",
      ".vsmall\n",
      "  :font-size 70%\n",
      "\n",
      ".big\n",
      "  :font-size 100%\n",
      "\n",
      ".inline\n",
      "  :display inline\n",
      "\n",
      ".hidden\n",
      "  :display none\n"

    ]
  end

end
RailCutter.new_project "test"

