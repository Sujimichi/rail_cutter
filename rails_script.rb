module FileActions

  def in_project! sub_dir = nil
    dir = @project_dir
    dir = "#{@project_dir}/#{sub_dir}" if sub_dir
    FileUtils.mkpath dir #makes the path exist if it does not already
    FileUtils.chdir dir
  end

  def modify_line_in file, target_line, new_line
    f = File.open(file, 'r')
    new = f.map{|l| l.eql?(target_line) ? new_line : l}
    f.close
    write_to file, new
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


class RScript
  require 'fileutils'
  include FileActions
  attr_accessor :project_name


  def initialize
    @project_name = "test"
    @projects_dir = "/home/katateochi/coding/rails"  # Dir.getwd
    @lib_dir = "/home/katateochi/coding/rails/rails_maker/files"
    @project_dir = @projects_dir << "/#{@project_name}"
    @gems = ["haml"]
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
    install_gems(["haml", "json", "fastercsv"])
    install_haml
  end

  def add_customization
    #Customisation
    setup_welcome_controller
    setup_layout
    install_jrails
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

  def setup_welcome_controller
    in_project! "config"
    modify_line_in "routes.rb", "  # map.root :controller => \"welcome\"\n", "  map.root :controller => \"welcome\"\n"
    in_project! "app/controllers"
    write_to "welcome_controller.rb", @files.welcome_controller
    in_project! "app/views/welcome"
    write_to "index.haml", @files.welcome_index
    in_project! "public"
    FileUtils.touch "index.html"
    FileUtils.remove "index.html"
    in_project!
    git_add_and_commit "added welcome controller, welcome view and changed routes, removed public/index.htm/"
  end

  def setup_layout
    in_project! "app/controllers"
    insert_line_after_in "application_controller.rb", :line6, "  layout 'main'\n"
    in_project! "app/views/layouts"
    write_to "main.haml", @files.main_haml
  end



  def git_add_and_commit message
    system "git add ./"
    system "git commit -m '#{message}'"
  end


  def install_gems gems
    gem_string = gems.map{|g| "  config.gem '#{g}'"}.join("\n")
    in_project! "config"
    target = "  # Specify gems that this application depends on and have them installed with rake gems:install\n"
    insert_line_after_in "environment.rb", target, "#{gem_string}\n"
    in_project! "rake gems:install"
  end

  def install_haml
    in_project!
    system "haml --rails ./"
    in_project! "app/stylesheets"
    write_to "layout.sass", @files.layout_sass
    write_to "utils.sass", @files.utils_sass
    in_project! "config/initializers"
    write_to "sass.rb", @files.sass_rb #why do I need to do this.  should this not be setup with the install of haml?  this step is not memtioned in haml docs but without it css is not made from sass.
  end

  def install_jrails
    in_project! 
    system "ruby script/plugin install http://ennerchi.googlecode.com/svn/trunk/plugins/jrails"
    system "cp #{@lib_dir}/jquery/css/smoothness ./public/stylesheets/ -r"
    system "cp #{@lib_dir}/jquery/js/jquery-ui*.js ./public/javascripts/jquery-ui.js"

    in_project! "app/views/layouts"
    insert_line_after_in "main.haml", "  %head\n", "    = stylesheet_link_tag 'smoothness/jquery-ui-1.7.2.custom.css', :rel => \"Stylesheet\"\n"
  end

  def replace_with_server
    in_project!
    Kernel.exec("ruby script/server")
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

  def welcome_controller
    [
      "class WelcomeController < ApplicationController\n",
      "  skip_before_filter :require_login\n",
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
#      "    = stylesheet_link_tag 'custom-theme/jquery-ui-1.7.1.custom.css', :rel => \"Stylesheet\"\n",
      "    = javascript_include_tag \"application\", :defaults\n",
      "    <!--[if IE]><script language=\"javascript\" type=\"text/javascript\" src=\"excanvas.pack.js\"></script><![endif]-->\n",
      "\n",
      "    %title\n",
      "      #{@project_name}\n",
      "\n",
      "  %body\n",
      "    #body\n",
      "      #header\n",
      "        .title{:onmouseup => \"window.open('\#{root_url}', '_parent')\"}\n",
      "          #{@project_name}\n",
      "        .tag new rails site\n",
      "\n",
      "        .links\n",
      "\n",
      "      #content\n",
      "        #flash.hidden\n",
      "          -if flash[:error] || flash[:notice]\n",
      "            :javascript\n",
      "              $(function (){$('#flash').fadeIn('slow')});\n",
      "          - if flash[:error]\n",
      "            .flash_error= flash[:error]\n",
      "          - if flash[:notice]\n",
      "            .flash_notice= flash[:notice]\n",
      "          - if (flash[:error] || flash[:notice]) && !flash[:fade]\n",
      "            :javascript\n",
      "              $(function (){\n",
      "                var flash_fade = function (){$('#flash').fadeOut('slow')};\n",
      "                setTimeout ( flash_fade, 2000 );\n",
      "              });\n",
      "\n",
      "        =yield\n",
      "\n",
      "      .clear\n",
      "      #footer\n",
      "        %h6 #{@project_name}.on_rails[:alpha]\n",
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

r = RScript.new
r.make_all

#TODO
#authlogic, users and user_sessions
#hanl and sass
#remove unneeded specs.

